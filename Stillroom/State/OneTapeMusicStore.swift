import SwiftUI
import Combine

/// Remote catalogs and credentials live beside the local library, while every
/// selection and transport command passes through the same PlayerStore.
@MainActor
final class OneTapeMusicStore: ObservableObject {
    let player: PlayerStore
    @Published private(set) var albums: [MusicCollection] = []
    @Published private(set) var playlists: [MusicCollection] = []
    @Published private(set) var connection: NavidromeConnection?
    @Published private(set) var isLoading = false
    @Published private(set) var isDisconnecting = false
    @Published private(set) var progress: String?
    @Published private(set) var artworks: [String: UIImage] = [:]
    @Published var message: String?

    private let repository: NavidromeCatalogRepository
    private let credentials: NavidromeCredentials
    private let artworkCache: NavidromeArtworkCache
    private let session: URLSession?
    private var catalog: NavidromeCatalog?
    private var client: NavidromeClient?
    private var playerObservation: AnyCancellable?
    private var tracksObservation: AnyCancellable?
    private var albumArtworkObservation: AnyCancellable?
    private var messageObservation: AnyCancellable?
    private var transportObservation: AnyCancellable?
    private let transportSound: OneTapeTransportSoundService
    private let libraryFeedback = OneTapeLibraryFeedbackService()
    private var transportCuePolicy = OneTapeTransportCuePolicy()
    private var transportFeedbackActive = false
    private var transportFailureRevision = 0
    private var loadTask: Task<NavidromeCatalog, Error>?
    private var artworkTasks: [String: Task<Void, Never>] = [:]
    private var generation = 0
    private var restored = false
    private var committing = false

    init(player: PlayerStore? = nil, repository: NavidromeCatalogRepository = NavidromeCatalogRepository(),
         credentials: NavidromeCredentials = NavidromeCredentials(),
         artworkCache: NavidromeArtworkCache = NavidromeArtworkCache(), session: URLSession? = nil,
         transportSound: OneTapeTransportSoundService? = nil) {
        self.player = player ?? PlayerStore(emptyLibrary: true)
        self.repository = repository
        self.credentials = credentials
        self.artworkCache = artworkCache
        self.session = session
        self.transportSound = transportSound ?? OneTapeTransportSoundService()
        self.libraryFeedback.onFailure = { [weak self] error in self?.message = error.localizedDescription }
        self.transportSound.onFailure = { [weak self] error in
            self?.transportCuePolicy.cancel()
            self?.message = error.localizedDescription
        }
        playerObservation = self.player.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        // Rebuild metadata only when tracks change; media snapshots arrive four
        // times a second and must not repeatedly regroup the whole catalog.
        tracksObservation = self.player.$tracks.sink { [weak self] tracks in
            self?.rebuildCollections(localTracks: tracks.filter { $0.remote == nil })
        }
        albumArtworkObservation = self.player.$albumArtworks.sink { [weak self] images in
            // @Published emits before PlayerStore's property is assigned. Use
            // this new snapshot, including an empty snapshot that clears old art.
            self?.updateLocalArtworks(using: images)
        }
        messageObservation = self.player.$message.sink { [weak self] text in
            guard let self, let text else { return }
            self.transportFailureRevision += 1
            self.cancelTransportFeedback()
            self.message = text
        }
        transportObservation = self.player.$snapshot.sink { [weak self] snapshot in
            // Published emits before the stored snapshot is assigned. Reconcile
            // this incoming engine value so a pause cannot acknowledge stale play.
            self?.reconcileTransportFeedback(snapshot)
        }
    }

    deinit {
        loadTask?.cancel()
        artworkTasks.values.forEach { $0.cancel() }
    }

    var collections: [MusicCollection] { albums + playlists }
    var sourceAlbumCount: Int { catalog?.albums.count ?? 0 }
    var sourceTrackCount: Int { catalog?.tracks.count ?? 0 }

    func restore() async {
        guard !restored, !isLoading else { return }
        restored = true
        let request = generation
        await player.restore()
        guard request == generation, !Task.isCancelled else { return }
        do {
            let storedCatalog = try await repository.load()
            await credentials.retryPendingRemovals(keeping: storedCatalog?.connection.credentialID)
            guard let stored = storedCatalog else { return }
            guard request == generation, !Task.isCancelled else { return }
            let storedPassword = try await credentials.read(stored.connection.credentialID)
            guard request == generation, !Task.isCancelled else { return }
            guard let password = storedPassword else {
                // Preserve cached metadata so the account can be repaired without
                // erasing its catalog. Streams fail clearly until reconnected.
                apply(stored, client: nil, restorePlayback: true)
                message = NavidromeError.credentials.localizedDescription
                return
            }
            guard request == generation, !Task.isCancelled else { return }
            apply(stored, client: NavidromeClient(connection: stored.connection, password: password, session: session), restorePlayback: true)
        } catch { message = safeMessage(error) }
    }

    @discardableResult
    func connect(address: String, username: String, password: String) async -> Bool {
        do {
            let baseURL = try NavidromeClient.normalizedAddress(address)
            let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !username.isEmpty else { throw NavidromeError.missingAccount }
            guard !password.isEmpty else { throw NavidromeError.missingPassword }
            let sameAccount = connection?.baseURL == baseURL && connection?.username == username
            let candidate = NavidromeConnection(id: sameAccount ? connection!.id : UUID().uuidString,
                baseURL: baseURL, username: username, credentialID: UUID().uuidString)
            return await load(connection: candidate, password: password, writesCredential: true)
        } catch { message = safeMessage(error); return false }
    }

    @discardableResult
    func refresh() async -> Bool {
        guard let connection else { message = NavidromeError.notConnected.localizedDescription; return false }
        let request = generation
        do {
            guard let password = try await credentials.read(connection.credentialID) else {
                throw NavidromeError.credentials
            }
            guard request == generation, !Task.isCancelled else { return false }
            return await load(connection: connection, password: password, writesCredential: false)
        } catch { message = safeMessage(error); return false }
    }

    @discardableResult
    func disconnect() async -> Bool {
        guard !committing else { return false }
        cancel()
        let previous = connection
        committing = true
        isDisconnecting = true
        isLoading = true
        progress = "正在断开此设备的连接…"
        message = nil
        defer { committing = false; isDisconnecting = false; isLoading = false; progress = nil }
        do {
            try await repository.save(nil)
            catalog = nil; client = nil; connection = nil
            artworks = [:]
            player.setRemoteTracks([], streamURL: nil)
            rebuildCollections(localTracks: player.tracks.filter { $0.remote == nil })
            if let previous {
                do { try await credentials.remove(previous.credentialID) }
                catch { message = "连接已断开，旧登录信息暂未清理，将在下次启动时重试。" }
            }
            return true
        } catch { message = safeMessage(error); return false }
    }

    func cancel() {
        cancelTransportFeedback()
        // The final two-file commit is short and cannot be abandoned halfway
        // through. Network and artwork work always remains cancelable.
        guard !committing else { return }
        generation += 1
        loadTask?.cancel(); loadTask = nil
        artworkTasks.values.forEach { $0.cancel() }; artworkTasks = [:]
        isLoading = false; progress = nil
    }

    func tracks(in collection: MusicCollection) -> [Track] {
        let lookup = Dictionary(uniqueKeysWithValues: player.tracks.map { ($0.id, $0) })
        return collection.trackIDs.compactMap { lookup[$0] }
    }

    func selectTrack(in collection: MusicCollection, startAt: String? = nil, shuffle: Bool = false) {
        let entries = tracks(in: collection)
        guard let first = startAt.flatMap({ id in entries.first { $0.id == id } }) ??
                (shuffle ? entries.randomElement() : entries.first) else { return }
        // choose() owns queue replacement; shuffle is then reconciled through
        // its normal command, rather than maintaining a second playback queue.
        player.choose(first, in: entries, autoplay: false)
        if player.queue.shuffled != shuffle { player.toggleShuffle() }
        transportSound.stop()
        if transportFeedbackActive {
            // Choosing a new recording emits the old engine's stop first. Arm
            // only after selection so that stop cannot cancel the new request.
            transportCuePolicy.userPlayRequested(trackID: first.id, isPlaying: player.isPlaying)
        } else { transportCuePolicy.cancel() }
        player.play()
    }

    func togglePlaybackForTape() {
        if player.isTapeTrackChanging {
            cancelTransportFeedback()
            player.pause()
            return
        }
        transportSound.stop()
        if transportFeedbackActive {
            transportCuePolicy.userToggleRequested(trackID: player.currentTrack?.id,
                isPlaying: player.isPlaying, isPreparing: player.snapshot.isPreparing)
        } else { transportCuePolicy.cancel() }
        player.toggle()
    }

    func stepTrackForTape(_ direction: Int) {
        cancelTransportFeedback()
        guard direction != 0, player.currentTrack != nil else { return }
        let selection = player.selectionRevision
        let failure = transportFailureRevision
        player.stepForTape(direction, withMechanicalDelay: transportFeedbackActive)
        // A previous press may restart the same recording. Selection revision
        // acknowledges that accepted seek as well as a different queue item;
        // identity changes alone would miss it. Command-time failures stay mute.
        guard transportFeedbackActive, player.selectionRevision != selection,
              transportFailureRevision == failure else { return }
        do { try transportSound.play(.trackStep) }
        catch { message = OneTapeTransportSoundError.cannotStart.localizedDescription }
    }

    func cyclePlaybackModeForTape() {
        player.cyclePlaybackMode()
    }

    func beginWindingForTape(direction: Int) {
        cancelTransportFeedback()
        player.beginWinding(direction: direction)
    }

    func setTransportFeedbackActive(_ active: Bool) {
        transportFeedbackActive = active
        if !active { libraryFeedback.stop() }
        if !active {
            cancelTransportFeedback()
            player.trackWindupController.cancel()
        }
    }

    func handleLibraryBrowse(_ event: OneTapeLibraryBrowseEvent) {
        libraryFeedback.handle(event)
    }

    func cancelTransportFeedback() {
        transportCuePolicy.cancel()
        transportSound.stop()
    }

    private func reconcileTransportFeedback(_ snapshot: PlaybackSnapshot) {
        let previous = player.snapshot
        let cue = transportCuePolicy.reconcile(trackID: player.currentTrack?.id,
            isPlaying: snapshot.isPlaying, isPreparing: snapshot.isPreparing,
            isForeground: transportFeedbackActive)
        if let cue {
            do { try transportSound.play(cue) }
            catch { message = OneTapeTransportSoundError.cannotStart.localizedDescription }
        } else if (previous.isPlaying || previous.isPreparing),
                  !snapshot.isPlaying, !snapshot.isPreparing {
            // A route loss, failure or external pause can stop music without a
            // user release command. Cancel the old latch without inventing one.
            transportSound.stop()
        }
    }

    func artwork(for track: Track) -> UIImage? {
        if let image = player.artworks[track.id] { return image }
        guard let album = albums.first(where: { $0.trackIDs.contains(track.id) }) else { return nil }
        return artworks[album.id]
    }

    func loadArtwork(for collection: MusicCollection) async {
        if collection.remoteID.isEmpty {
            updateLocalArtworks(using: player.albumArtworks)
            return
        }
        guard artworks[collection.id] == nil else { return }
        guard let connection, let coverID = collection.coverArtID else { return }
        let key = connection.id + ":" + coverID
        if let task = artworkTasks[key] { await task.value; return }
        let request = generation
        let client = self.client
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                var data = try await self.artworkCache.read(key: key)
                if data == nil, let client {
                    data = try await client.coverArt(id: coverID)
                    if let data { try await self.artworkCache.save(data, key: key) }
                }
                guard !Task.isCancelled, request == self.generation,
                      let data, let image = UIImage(data: data) else { return }
                let matching = self.collections.filter { $0.coverArtID == coverID && !$0.remoteID.isEmpty }
                for item in matching { self.artworks[item.id] = image }
                let ids = self.player.tracks.filter { $0.remote?.coverArtID == coverID }.map(\.id)
                self.player.setRemoteArtwork(image, for: ids)
            } catch {
                // A failed cover never blocks the collection or audio. Retry is
                // available when its view appears again; metadata is retained.
                if !Task.isCancelled, request == self.generation, self.message == nil {
                    self.message = "部分封面暂时无法读取，音乐仍可播放，请检查网络后重试。"
                }
            }
        }
        artworkTasks[key] = task
        await task.value
        if request == generation { artworkTasks[key] = nil }
    }

    private func load(connection candidate: NavidromeConnection, password: String, writesCredential: Bool) async -> Bool {
        guard !committing else { return false }
        cancel()
        let request = generation
        isLoading = true; progress = "正在连接服务器…"; message = nil
        let candidateClient = NavidromeClient(connection: candidate, password: password, session: session)
        let task = Task { [weak self] in
            try await candidateClient.ping()
            return try await candidateClient.fetchCatalog { [weak self] text in
                guard let self, self.generation == request else { return }
                self.progress = text
            }
        }
        loadTask = task
        defer {
            if request == generation { isLoading = false; progress = nil; loadTask = nil }
        }
        var savedCredential = false
        do {
            let result = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            try Task.checkCancellation()
            guard request == generation else { return false }
            // No network work occurs during commit. Publish only after both the
            // app-owned credential and catalog are durable; retain old data on failure.
            committing = true
            progress = "正在保存曲库…"
            defer { committing = false }
            if writesCredential {
                try await credentials.save(password, as: candidate.credentialID)
                savedCredential = true
            }
            try await repository.save(result)
            let previousCredential = connection?.credentialID
            apply(result, client: candidateClient)
            if writesCredential, let previousCredential, previousCredential != candidate.credentialID {
                do { try await credentials.remove(previousCredential) }
                catch { message = "音乐库已连接，旧登录信息暂未清理，将在下次启动时重试。" }
            }
            return true
        } catch {
            // Failed cleanup is queued by the credential service, including a
            // newly staged credential whose catalog never committed.
            if savedCredential { try? await credentials.remove(candidate.credentialID) }
            guard request == generation else { return false }
            if !(error is CancellationError) { message = safeMessage(error) }
            return false
        }
    }

    private func apply(_ catalog: NavidromeCatalog, client: NavidromeClient?, restorePlayback: Bool = false) {
        self.catalog = catalog; self.client = client; connection = catalog.connection
        artworks = [:]
        player.setRemoteTracks(catalog.tracks, streamURL: { remote in
            guard let client, remote.connectionID == catalog.connection.id else { throw NavidromeError.notConnected }
            return try client.streamURL(songID: remote.songID)
        }, restorePlayback: restorePlayback)
        rebuildCollections(localTracks: player.tracks.filter { $0.remote == nil })
    }

    private func rebuildCollections(localTracks: [Track]) {
        var seen = Set<String>()
        let local = localTracks.filter { seen.insert($0.albumKey).inserted }.map { first in
            let songs = localTracks.filter { $0.albumKey == first.albumKey }.sorted {
                ($0.discNumber ?? 1, $0.trackNumber ?? Int.max) < ($1.discNumber ?? 1, $1.trackNumber ?? Int.max)
            }
            return MusicCollection(id: "local:" + first.albumKey, kind: .album,
                title: first.album, subtitle: first.albumArtist ?? first.artist, remoteID: "",
                trackIDs: songs.map(\.id), coverArtID: nil, year: nil,
                duration: songs.reduce(0) { $0 + $1.duration },
                addedAt: songs.compactMap(\.addedAt).max())
        }
        albums = local + (catalog?.albums ?? [])
        playlists = catalog?.playlists ?? []
        updateLocalArtworks(using: player.albumArtworks)
    }

    private func updateLocalArtworks(using images: [String: UIImage]) {
        let local = albums.filter { $0.remoteID.isEmpty }
        let ids = Set(local.map(\.id))
        var next = artworks.filter { !$0.key.hasPrefix("local:") || ids.contains($0.key) }
        var changed = next.count != artworks.count
        for album in local {
            // Album-specific overrides or automatic embedded art may live on a
            // later song. Song-only overrides deliberately never become sleeves.
            let image = album.trackIDs.lazy.compactMap { images[$0] }.first
            if next[album.id] !== image {
                next[album.id] = image
                changed = true
            }
        }
        if changed { artworks = next }
    }

    private func safeMessage(_ error: Error) -> String {
        if let error = error as? NavidromeError { return error.localizedDescription }
        return "音乐服务器资料未能读取或保存，原曲库已保留，请重试。"
    }
}
