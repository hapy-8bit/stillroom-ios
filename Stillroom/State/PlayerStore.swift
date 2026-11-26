import SwiftUI
import Combine

@MainActor
final class PlayerStore: ObservableObject {
    @Published private(set) var tracks: [Track]
    @Published private(set) var currentTrack: Track?
    /// Legacy record screens require a value. Empty-library clients use currentTrack;
    /// this compatibility value is never inserted into tracks, queues or persistence.
    var current: Track {
        get { currentTrack ?? Self.emptyCompatibilityTrack }
        set { currentTrack = newValue }
    }
    private static let emptyCompatibilityTrack = Track(id: "", title: "", artist: "", album: "",
        audioFile: "", palette: .local, duration: 0, lyrics: "", isDemo: false, isLyricDemo: false)
    @Published private(set) var snapshot = PlaybackSnapshot()
    @Published private(set) var lyrics: [LyricLine]
    @Published private(set) var importing = false
    @Published private(set) var importReport = ImportReport()
    @Published private(set) var importProgress: ImportProgress?
    @Published var showingImport = false
    @Published private(set) var libraryReady = false
    @Published private(set) var queue = PlaybackQueue()
    @Published private(set) var artworks: [String: UIImage] = [:]
    @Published private(set) var albumArtworks: [String: UIImage] = [:]
    @Published private(set) var selectionRevision = 0
    /// nil follows the engine; ±14 winds briefly and 0 is the mechanical brake.
    @Published private(set) var tapeTrackMotionRate: Double?
    @Published private(set) var recordTransition: OrbitRecordTransition = .initial
    @Published private(set) var queueTitle = "全部音乐"
    @Published private(set) var queueFinished = false
    @Published private(set) var craftedSession: CraftListeningSession?
    @Published var orbitPreferences: OrbitVisualPreferences {
        didSet {
            do { defaults.set(try JSONEncoder().encode(orbitPreferences), forKey: "orbit.visual.v1") }
            catch { notice("唱片外观未能保存，请重新选择后重试。") }
        }
    }
    @Published var importRequest: ImportRequest?
    @Published var message: String?
    @Published var showingPlayer = false
    @Published var showingShelf = false
    @Published private(set) var galleryFocusKey: String?
    @Published var reducedMotion: Bool {
        didSet { defaults.set(reducedMotion, forKey: "reducedMotion") }
    }
    @Published private(set) var favorites: Set<String>
    @Published private(set) var recentlyPlayedTrackIDs: [String] = []
    @Published var listeningLedger: ListeningLedger = ListeningLedger()
    @Published var liveListeningEvent: ListeningSessionEvent?
    private let defaults: UserDefaults
    private let playbackHistory: PlaybackHistoryStore
    let listeningLedgerStore: ListeningLedgerStore
    var listeningTracker = ListeningSessionTracker()
    var lastPublishedLiveSecond = -1
    var listeningLedgerFailureNotified = false
    private let repository: LibraryRepository
    private let directory: URL
    private let mediaOverrides: MediaOverridesStore
    private let bookmarkStore: PlaybackBookmarkStore
    private let bundledTracks: [Track]
    private let sampleIDs: Set<String>
    private let beforeLocalRestorePublication: (@MainActor () async -> Void)?
    private var importBusyObservation: AnyCancellable?
    private var restoredPosition: Double = 0
    private var checkpointAt = Date.distantPast
    lazy var importCoordinator: MusicImportCoordinator = {
        let coordinator = MusicImportCoordinator(repository: repository, directory: directory,
            tracks: { [weak self] in self?.tracks ?? [] },
            commitAudio: { [weak self] track, staging in
                guard let self else { throw LibraryError.missingAudio }
                return try await self.commitPreviewAudio(track, staging: staging)
            }, commitLyrics: { [weak self] id, canonical, original in
                guard let self else { throw LibraryError.missingAudio }
                try await self.setImportedLyrics(id, canonical: canonical, original: original)
            }, commitCover: { [weak self] id, url, album in
                guard let self else { throw LibraryError.missingAudio }
                try await self.setImportedCover(id, url: url, album: album)
            })
        // The coordinator is created lazily while a sheet is rendered. Its
        // initial false value must not publish PlayerStore changes in that render.
        importBusyObservation = coordinator.$busy.dropFirst().sink { [weak self] busy in
            if self?.importing != busy { self?.importing = busy }
        }
        return coordinator
    }()
    private let audio = AudioPlayback()
    let visualization = AudioVisualizationSignal()
    private let mediaSession = SystemMediaSession()
    private(set) var loadedID: String?
    private var messageTask: Task<Void, Never>?
    private var importStopRequested = false
    private var remoteURL: ((RemoteTrackReference) throws -> URL)?
    private(set) lazy var windingController = OneTapeWindingController(
        read: { [weak self] in
            guard let self, let track = self.currentTrack else { return nil }
            return .init(trackID: track.id, position: self.position, duration: self.duration,
                         wasPlaying: self.isPlaying || self.snapshot.isPreparing)
        }, prepare: { [weak self] in
            guard let self, self.currentTrack != nil else { throw LibraryError.missingAudio }
            guard self.craftedSession == nil || self.craftedSession?.phase == .listening else { throw LibraryError.missingAudio }
            self.selectionRevision += 1
            self.restoredPosition = 0
            self.queueFinished = false
            if self.loadedID == nil {
                try self.audio.load(self.audioURL(for: self.current), durationHint: self.current.duration)
                self.loadedID = self.current.id
            }
            self.audio.pause()
        }, seek: { [weak self] in self?.audio.seek($0) },
        resumePlayback: { [weak self] in self?.play() }
    )
    private(set) lazy var trackWindupController = OneTapeTrackWindupController(
        read: { [weak self] in
            guard let self, let track = self.currentTrack else { return nil }
            return .init(trackID: track.id, selectionRevision: self.selectionRevision)
        }, prepare: { [weak self] in
            guard let self, let track = self.currentTrack else { throw LibraryError.missingAudio }
            if self.loadedID != track.id {
                try self.audio.load(self.audioURL(for: track), durationHint: track.duration)
                self.loadedID = track.id
            }
            self.audio.pause()
        }, onRateChange: { [weak self] in self?.tapeTrackMotionRate = $0 },
        resumePlayback: { [weak self] in self?.play() }
    )

    var position: Double { snapshot.position }
    var duration: Double { snapshot.duration > 0 ? snapshot.duration : currentTrack?.duration ?? 0 }
    var isPlaying: Bool { snapshot.isPlaying }
    var lyricIndex: Int? { Lyrics.activeIndex(in: lyrics, at: position) }
    /// Keep old bundled identities resolvable for saved records/bookmarks without advertising
    /// them as the new library's samples. Imported tracks always remain visible.
    var libraryTracks: [Track] { tracks.filter { !$0.isDemo || sampleIDs.contains($0.id) } }

    init(directory: URL? = nil, defaults: UserDefaults = .standard, sampleTracks: [Track]? = nil,
         emptyLibrary: Bool = false, beforeLocalRestorePublication: (@MainActor () async -> Void)? = nil) {
        self.defaults = defaults
        playbackHistory = PlaybackHistoryStore(defaults: defaults)
        let ledgerURL = directory?.appendingPathComponent("listening-ledger.json")
            ?? ListeningLedgerStore.defaultURL(for: ProcessInfo.processInfo.arguments)
        listeningLedgerStore = ListeningLedgerStore(fileURL: ledgerURL)
        listeningLedger = listeningLedgerStore.ledger
        self.beforeLocalRestorePublication = beforeLocalRestorePublication
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stillroom/Library", isDirectory: true)
        repository = LibraryRepository(directory: self.directory)
        mediaOverrides = MediaOverridesStore(directory: self.directory)
        bookmarkStore = PlaybackBookmarkStore(defaults: defaults)
        let samples = emptyLibrary ? [] : sampleTracks ?? (ProcessInfo.processInfo.arguments.contains("--original-demo-fixture") ?
            Track.demos : BundledAlbumCatalog.tracks)
        self.sampleIDs = Set(samples.map(\.id))
        // Old IDs must continue to mean the same recordings. Never reuse sea/window/night for
        // reference albums: saved lyrics, memories and frozen record sides refer to those IDs.
        var seen = Set<String>()
        let resolvedBundled = (samples + (emptyLibrary ? [] : Track.demos)).filter { seen.insert($0.id).inserted }
        let initialTrack = samples.first
        bundledTracks = resolvedBundled
        tracks = resolvedBundled
        currentTrack = initialTrack
        lyrics = Lyrics.parse(initialTrack?.lyrics ?? "")
        if let data = defaults.data(forKey: "orbit.visual.v1"), let stored = try? JSONDecoder().decode(OrbitVisualPreferences.self, from: data) {
            orbitPreferences = stored
        } else { orbitPreferences = OrbitVisualPreferences() }
        reducedMotion = defaults.bool(forKey: "reducedMotion")
        favorites = Set(defaults.stringArray(forKey: "favorites") ?? [])
        recentlyPlayedTrackIDs = playbackHistory.trackIDs
        reloadArtworks()
        queue.replace(with: libraryTracks.map(\.id), startingAt: initialTrack?.id ?? "")
        audio.onSnapshot = { [weak self] value in
            guard let self else { return }
            if value.isPlaying, !self.snapshot.isPlaying,
               let id = self.currentTrack?.id, self.loadedID == id {
                do { self.recentlyPlayedTrackIDs = try self.playbackHistory.record(id) }
                catch { self.notice("播放历史未能保存，原记录已保留。") }
            }
            self.snapshot = value
            self.observeListeningSnapshot(value)
            if self.loadedID != nil && Date().timeIntervalSince(self.checkpointAt) >= 5 { self.rememberPlayback() }
            if self.loadedID != nil { self.mediaSession.update(track: self.current, snapshot: value, artwork: self.artworks[self.current.id]) }
        }
        audio.onFinish = { [weak self] in
            guard let self, !self.windingController.isWinding,
                  !self.trackWindupController.isActive else { return }
            self.completeListeningSession()
            self.skip(1, automatic: true)
        }
        audio.onError = { [weak self] text in
            self?.cancelWinding()
            self?.notice(text)
        }
        audio.onExternalPause = { [weak self] in self?.cancelWinding() }
        audio.onAnalysis = { [weak self] in self?.visualization.update($0) }
        audio.onSeekCompleted = { [weak self] in
            guard let self, !self.windingController.isWinding else { return }
            self.rememberPlayback()
        }
        mediaSession.onPlay = { [weak self] in self?.play() }
        mediaSession.onPause = { [weak self] in self?.pause() }
        mediaSession.onNext = { [weak self] in self?.skip(1) }
        mediaSession.onPrevious = { [weak self] in self?.skip(-1) }
        mediaSession.onSeek = { [weak self] in self?.seek($0) }
    }

    func restore() async {
        guard !libraryReady else { return }
        let revision = selectionRevision
        do {
            let restored = try await repository.restore()
            let raw = bundledTracks + restored
            let localTracks: [Track]
            do { try await mediaOverrides.restore(); localTracks = try await mediaOverrides.apply(raw) }
            catch { localTracks = raw; notice("自定义歌词或封面未能读取，原资料保留，请重试。") }
            await beforeLocalRestorePublication?()
            // File restoration owns only local data. A connection or disconnect
            // may have replaced the cloud catalog during either await above.
            tracks = localTracks + tracks.filter { $0.remote != nil }
            reloadArtworks()
            let available = Set(tracks.map(\.id))
            // Local restore precedes the remote catalog. Missing IDs may belong
            // to that catalog, an offline account or a repairable local index;
            // absence never means the user has removed a saved preference.
            if revision == selectionRevision, loadedID == nil {
                let bookmark: PlaybackBookmark?
                do { bookmark = try bookmarkStore.restore(available: available) }
                catch { bookmark = nil; notice("续听记录未能读取，曲库仍可正常使用。") }
                if let saved = bookmark, let target = tracks.first(where: { $0.id == saved.trackID }) {
                    current = target; queueTitle = saved.queueTitle ?? "上次队列"; queueFinished = saved.finished ?? false
                    restoredPosition = target.duration > 0 ? MediaTime.clamped(saved.position, duration: target.duration) : saved.position
                    snapshot = PlaybackSnapshot(position: restoredPosition, duration: target.duration)
                    queue.restore(ids: saved.queueIDs, original: saved.originalIDs, shuffled: saved.shuffled, repeatMode: saved.repeatMode)
                    if let craft = saved.craftedSession {
                        if craft.isRestorable(available: available, currentID: target.id) {
                            craftedSession = craft
                            queue.restore(ids: craft.sideIDs, original: craft.sideIDs, shuffled: false, repeatMode: .off)
                            queueFinished = craft.phase != .listening
                        } else {
                            queue.restore(ids: [target.id], original: [target.id], shuffled: false, repeatMode: .off)
                            queueTitle = "单曲续听"; queueFinished = false
                            notice("自制唱片中有歌曲暂不可用，制作资料仍保留；当前歌曲可单独续听。")
                        }
                    }
                } else {
                    currentTrack = tracks.first(where: { $0.id == currentTrack?.id }) ?? tracks.first
                    queue.replace(with: libraryAlbumQueue().map(\.id), startingAt: current.id)
                }
                lyrics = Lyrics.parse(current.lyrics)
            }
            libraryReady = true
        } catch { notice("曲库或续听记录未能读取，原文件保留：" + error.localizedDescription) }
    }

    func choose(_ track: Track, in selection: [Track]? = nil, autoplay: Bool = true,
                transition: OrbitRecordTransition? = nil, preserveCraftedSession: Bool = false) {
        cancelWinding()
        if !preserveCraftedSession { craftedSession = nil }
        queueFinished = false
        if let selection {
            queue.replace(with: selection.map(\.id), startingAt: track.id)
            queueTitle = Set(selection.map(\.id)) == Set(tracks.map(\.id)) ? "全部音乐" :
                selection.allSatisfy({ $0.albumKey == track.albumKey }) ? "专辑 · " + track.album : "当前选择"
        }
        if current.id != track.id {
            flushListeningLedger()
            recordTransition = transition ?? (current.albumKey == track.albumKey ? .relocate : .replace)
            selectionRevision += 1; restoredPosition = 0
            loadedID = nil
            audio.stop()
            current = track
            lyrics = Lyrics.parse(track.lyrics)
        }
        if autoplay { play() }
        rememberPlayback()
    }

    func play() {
        cancelWinding()
        guard currentTrack != nil else { return }
        if let session = craftedSession {
            if session.phase == .awaitingFlip { flipCraftedSide(); return }
            if session.phase == .finished { _ = playCrafted(session.record); return }
        }
        if queueFinished, let firstID = queue.ids.first, let first = tracks.first(where: { $0.id == firstID }) {
            queueFinished = false; seek(0); choose(first, autoplay: true); return
        }
        do {
            if loadedID != current.id {
                let url = try audioURL(for: current)
                let resume = restoredPosition
                try audio.load(url, durationHint: current.duration)
                loadedID = current.id; restoredPosition = 0
                if resume > 0 { audio.seek(resume) }
            }
            try audio.play()
        } catch {
            loadedID = nil
            audio.stop()
            notice("无法播放：" + error.localizedDescription)
        }
    }

    func pause() {
        cancelWinding()
        // An unloaded engine has no media clock to replace a restored bookmark.
        if loadedID != nil { audio.pause() }
        flushListeningLedger()
        rememberPlayback()
    }
    func toggle() { isPlaying || snapshot.isPreparing ? pause() : play() }
    func seek(_ seconds: Double) {
        cancelWinding()
        guard currentTrack != nil else { return }
        guard craftedSession?.phase == nil || craftedSession?.phase == .listening else { return }
        noteListeningSeek()
        recordTransition = .relocate; selectionRevision += 1; restoredPosition = 0; queueFinished = false
        if loadedID == nil {
            // Seeking before first play prepares the same engine without starting audio.
            do {
                let url = try audioURL(for: current)
                try audio.load(url, durationHint: current.duration)
                loadedID = current.id
            } catch { notice(error.localizedDescription); return }
        }
        audio.seek(seconds); rememberPlayback()
    }
    func stop() { pause(); seek(0) }

    func presentAlbums(focusing track: Track? = nil) {
        galleryFocusKey = (track ?? current).albumKey
        showingShelf = true
    }

    func skip(_ delta: Int, automatic: Bool = false) {
        cancelWinding()
        guard currentTrack != nil else { return }
        if craftedSession != nil { advanceCrafted(delta, automatic: automatic); return }
        guard let id = queue.adjacent(to: current.id, delta: delta, automatic: automatic),
              let next = tracks.first(where: { $0.id == id }) else {
            if automatic { queueFinished = true; rememberPlayback() }; return
        }
        // A rapid transport command can arrive before AVPlayer starts. Keep
        // that outstanding play intent when replacing the prepared recording.
        let autoplay = automatic || isPlaying || snapshot.isPreparing
        if next.id == current.id { seek(0) }
        let items = albumTracks(current)
        let index = items.firstIndex(where: { $0.id == current.id })
        let nextIndex = items.firstIndex(where: { $0.id == next.id })
        let continuous = automatic && !queue.shuffled && next.id != current.id && index != nil && nextIndex == index! + 1
        choose(next, autoplay: autoplay, transition: continuous ? .continuous : current.albumKey == next.albumKey ? .relocate : .replace)
    }

    func toggleShuffle() {
        guard craftedSession == nil else { notice("自制唱片按封套曲序播放。"); return }
        queue.toggleShuffle(current: current.id); rememberPlayback()
    }
    func playSomething() {
        let alternatives = libraryTracks.filter { $0.id != current.id }
        if let track = (alternatives.isEmpty ? libraryTracks : alternatives).randomElement() {
            choose(track, in: libraryTracks)
        }
    }
    var playbackMode: OneTapePlaybackMode {
        OneTapePlaybackMode(shuffled: queue.shuffled, repeatMode: queue.repeatMode)
    }

    func cyclePlaybackMode() {
        setPlaybackMode(playbackMode.next)
    }

    func setPlaybackMode(_ mode: OneTapePlaybackMode) {
        guard craftedSession == nil else { notice("自制唱片按封套曲序播放。"); return }
        let currentID = currentTrack?.id ?? ""
        switch mode {
        case .listLoop:
            if queue.shuffled { queue.toggleShuffle(current: currentID) }
            queue.repeatMode = .all
        case .singleLoop:
            if queue.shuffled { queue.toggleShuffle(current: currentID) }
            queue.repeatMode = .one
        case .shuffle:
            if !queue.shuffled { queue.toggleShuffle(current: currentID) }
            queue.repeatMode = .all
        }
        rememberPlayback()
    }

    func cycleRepeat() { setQueueMode(repeatMode: queue.repeatMode.next) }
    func toggleFavorite(_ track: Track) {
        if favorites.contains(track.id) { favorites.remove(track.id) } else { favorites.insert(track.id) }
        defaults.set(Array(favorites), forKey: "favorites")
    }

    func playHomeAlbum(_ key: String) {
        guard let album = albums().first(where: { $0.albumKey == key }), let first = albumTracks(album).first else { return }
        queueTitle = "全部音乐"; choose(first, in: libraryAlbumQueue())
    }

    func setQueueMode(repeatMode: RepeatMode) {
        guard craftedSession == nil else { notice("自制唱片听到面尾后翻面或收针。"); return }
        queue.repeatMode = repeatMode; rememberPlayback()
    }

    /// Resolve the entire frozen edition before touching current playback. Missing source tracks
    /// keep the previous queue intact and remain visible in the maker for repair.
    @discardableResult func playCrafted(_ record: CraftedRecord) -> Bool {
        let ids = record.allTrackIDs
        guard libraryReady, (try? record.validate()) != nil, !record.isDraft, !record.sideA.isEmpty,
              !record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              Set(ids).count == ids.count, ids.allSatisfy({ id in tracks.contains { $0.id == id } }),
              let firstID = record.sideA.first, let first = tracks.first(where: { $0.id == firstID }) else {
            notice("这张唱片有尚未准备好的歌曲，请回到制作页检查。"); return false
        }
        // A new edition needs a fresh decoder identity even if its first track equals current.
        // Otherwise a previously enqueued completion could finish the newly restarted first side.
        audio.stop(); loadedID = nil; restoredPosition = 0
        craftedSession = CraftListeningSession(record: record)
        queue.restore(ids: record.sideA, original: record.sideA, shuffled: false, repeatMode: .off)
        choose(first, autoplay: false, transition: .replace, preserveCraftedSession: true)
        seek(0); queueTitle = record.title + " · A 面"; play(); rememberPlayback()
        return true
    }

    func flipCraftedSide() {
        guard var session = craftedSession, let id = session.flip(),
              let track = tracks.first(where: { $0.id == id }) else { return }
        craftedSession = session
        queue.restore(ids: session.sideIDs, original: session.sideIDs, shuffled: false, repeatMode: .off)
        choose(track, autoplay: false, transition: .replace, preserveCraftedSession: true)
        seek(0); queueTitle = session.record.title + " · " + session.side.label; play(); rememberPlayback()
    }

    func endCraftedListening() {
        cancelWinding()
        guard var session = craftedSession else { return }
        audio.pause(); session.phase = .finished; craftedSession = session
        queueFinished = true; rememberPlayback()
    }

    private func advanceCrafted(_ delta: Int, automatic: Bool) {
        guard var session = craftedSession else { return }
        // A manual next at the parked boundary means an explicit flip; a stale decoder event
        // cannot advance a session that is already waiting or finished.
        guard session.phase == .listening else {
            if !automatic && delta > 0 && session.phase == .awaitingFlip { flipCraftedSide() }
            return
        }
        let wasPlaying = automatic || isPlaying || snapshot.isPreparing
        let outcome = session.advance(from: current.id, delta: delta, automatic: automatic)
        craftedSession = session
        switch outcome {
        case .track(let id, _):
            guard let track = tracks.first(where: { $0.id == id }) else { pause(); notice("这首歌曲暂不可用，请重新检查曲库。"); return }
            if id == current.id && !automatic { audio.stop(); loadedID = nil; restoredPosition = 0 }
            queue.restore(ids: session.sideIDs, original: session.sideIDs, shuffled: false, repeatMode: .off)
            choose(track, autoplay: false, transition: .relocate, preserveCraftedSession: true)
            seek(0); queueTitle = session.record.title + " · " + session.side.label
            if wasPlaying { play() }
        case .flip, .finished:
            audio.pause(); queueFinished = true
        }
        rememberPlayback()
    }

    private func rememberPlayback() {
        // A validated remote catalog is independent of the local file index.
        // Local corruption or an unfinished local restore must not discard the
        // user's explicit cloud selection, queue or completed seek position.
        guard let currentTrack, libraryReady || currentTrack.remote != nil else { return }
        checkpointAt = Date()
        do { try bookmarkStore.save(PlaybackBookmark(trackID: current.id, queueIDs: queue.ids, originalIDs: queue.originalIDs,
            shuffled: queue.shuffled, repeatMode: queue.repeatMode, position: position, queueTitle: queueTitle,
            finished: queueFinished, craftedSession: craftedSession)) }
        catch { notice("续听位置未能保存，音乐文件不受影响。") }
    }

    private func commitPreviewAudio(_ track: Track, staging: URL) async throws -> String {
        let result = try await repository.appendPreviewAudio(track, from: staging)
        await publishLibrary(bundledTracks + result.tracks + tracks.filter { $0.remote != nil })
        return result.track.id
    }

    func setImportedLyrics(_ id: String, canonical: String, original: String) async throws {
        guard tracks.contains(where: { $0.id == id }) else { throw LibraryError.missingAudio }
        try await mediaOverrides.saveLyrics(trackID: id, canonical: canonical, original: original)
        await publishLibrary(tracks)
    }

    func setImportedCover(_ id: String, url: URL, album: Bool) async throws {
        guard let target = tracks.first(where: { $0.id == id }) else { throw LibraryError.missingAudio }
        try await mediaOverrides.saveCover(targetID: album ? target.albumKey : id, normalizedURL: url, album: album)
        await publishLibrary(tracks)
    }

    private func publishLibrary(_ raw: [Track]) async {
        // Once the repository commits an audio item, a later artwork read failure cannot roll it back.
        do { tracks = try await mediaOverrides.apply(raw) }
        catch {
            let previous = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
            tracks = raw.map { previous[$0.id] ?? $0 }; notice("音乐已保存，部分资料暂时无法读取，请重试。")
        }
        if let live = tracks.first(where: { $0.id == current.id }) { current = live; lyrics = Lyrics.parse(live.lyrics) }
        else if currentTrack == nil {
            currentTrack = tracks.first
            lyrics = Lyrics.parse(currentTrack?.lyrics ?? "")
            queue.replace(with: libraryTracks.map(\.id), startingAt: currentTrack?.id ?? "")
        }
        reloadArtworks()
        if loadedID != nil { mediaSession.update(track: current, snapshot: snapshot, artwork: artworks[current.id]) }
    }

    private func reloadArtworks() {
        var nextArtworks: [String: UIImage] = [:]
        var nextAlbumArtworks: [String: UIImage] = [:]
        for track in tracks {
            nextArtworks[track.id] = artworkImage(for: track)
            let automatic = track.automaticMedia?.artworkFile ?? (track.automaticMedia == nil ? track.artworkFile : nil)
            if let name = track.albumArtworkFile ?? automatic, LibraryRepository.isSafeBasename(name) {
                nextAlbumArtworks[track.id] = UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
            } else if let asset = BundledAlbumCatalog.artworkAssetName(for: track.id) {
                nextAlbumArtworks[track.id] = UIImage(named: asset)
            } else if track.isDemo && track.id == "sea" { nextAlbumArtworks[track.id] = UIImage(named: "SeaCover") }
        }
        if nextArtworks["sea"] == nil, let sea = tracks.first(where: { $0.id == "sea" }),
           sea.isDemo, sea.artworkFile == nil {
            nextArtworks["sea"] = UIImage(named: "SeaCover")
        }
        // Consumers project whole-album sleeves from these dictionaries. Do
        // not emit a cleared/partially rebuilt library for every individual song.
        artworks = nextArtworks
        albumArtworks = nextAlbumArtworks
    }
    func importFiles(_ urls: [URL], request: ImportRequest) async {
        guard !importing else { return }
        importing = true
        defer { importing = false }
        switch request {
        case .music, .folder:
            await importMusic(urls, folders: request.id == "folder")
        case .cover(let id, let album):
            await importCoordinator.prepareReplacement(urls: urls, trackID: id, kind: .cover, album: album)
            showingImport = true
        case .lyrics(let id):
            guard let url = urls.first, tracks.contains(where: { $0.id == id }) else { return }
            do {
                let text = try await repository.readLyrics(from: url)
                // A server refresh or disconnect may remove this target while
                // file access runs on the repository actor. Re-resolve by ID.
                guard let index = tracks.firstIndex(where: { $0.id == id }) else { throw LibraryError.missingAudio }
                var updated = tracks
                updated[index].lyrics = text
                updated[index].isLyricDemo = false
                if !updated[index].isDemo { try await repository.save(updated) }
                tracks = updated
                // The picker targets the song that opened it, even if a remote command changes tracks meanwhile.
                if current.id == id { current = updated[index]; lyrics = Lyrics.parse(text) }
                notice(updated[index].isDemo ? "歌词已关联；试听曲的歌词修改仅本次保留。" : "歌词已保存并关联到歌曲。")
            } catch { notice(error.localizedDescription) }
        }
    }

    func checkpoint() { rememberPlayback() }

    func stopImportAfterCurrentFile() { importStopRequested = true }

    private func importMusic(_ urls: [URL], folders: Bool) async {
        importReport = ImportReport()
        importStopRequested = false
        importProgress = ImportProgress(completed: 0, total: 0, filename: "正在读取所选内容…")
        defer { importReport.finished = true; importProgress = nil }
        do {
            let sources = try await repository.discover(urls, folders: folders)
            for (index, source) in sources.enumerated() {
                // A stop request finishes the in-flight file and its atomic index write before exiting.
                if importStopRequested { importReport.stopped = true; break }
                importProgress = ImportProgress(completed: index, total: sources.count, filename: source.url.lastPathComponent)
                do {
                    let track = try await repository.stageAudio(from: source.url, scope: source.scope, existing: tracks)
                    do { try await repository.save(tracks + [track]) }
                    catch { await repository.discardStaged(track); throw error }
                    tracks.append(track)
                    artworks[track.id] = artworkImage(for: track)
                    importReport.added += 1
                } catch LibraryError.duplicateAudio {
                    importReport.duplicates += 1
                } catch {
                    importReport.issues.append(ImportIssue(filename: source.url.lastPathComponent, reason: error.localizedDescription))
                }
            }
            // Compatibility tracks are not silently appended to a fresh library queue. Keep
            // a currently selected old recording reachable when importing while it is open.
            let visible = libraryTracks.map(\.id)
            if currentTrack == nil { currentTrack = libraryTracks.first; lyrics = Lyrics.parse(current.lyrics) }
            let ids = currentTrack == nil || visible.contains(current.id) ? visible : [current.id] + visible
            queue.replace(with: ids, startingAt: current.id)
            notice(sources.isEmpty ? "所选文件夹中没有找到音频。" : importReport.summary)
        } catch {
            importReport.issues.append(ImportIssue(filename: "所选文件夹", reason: error.localizedDescription))
            notice("未能读取所选内容，请在「文件」中确认它可以打开。")
        }
    }

    func notice(_ text: String) {
        messageTask?.cancel()
        message = text
        messageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { self?.message = nil }
        }
    }

    /// Catalog replacement updates one authoritative queue/engine. Cloud tracks
    /// never pass through the local file repository; local imports remain present.
    func setRemoteTracks(_ remoteTracks: [Track], streamURL: ((RemoteTrackReference) throws -> URL)?,
                         restorePlayback: Bool = false) {
        cancelWinding()
        remoteURL = streamURL
        tracks = tracks.filter { $0.remote == nil } + remoteTracks
        if let selected = currentTrack, let updated = tracks.first(where: { $0.id == selected.id }) {
            current = updated
        } else {
            audio.stop(); loadedID = nil; restoredPosition = 0
            mediaSession.clear()
            currentTrack = tracks.first
            lyrics = Lyrics.parse(currentTrack?.lyrics ?? "")
        }
        let available = Set(tracks.map(\.id))
        let retained = queue.ids.filter { available.contains($0) }
        let original = queue.originalIDs.filter { available.contains($0) }
        if retained.isEmpty {
            queue.replace(with: libraryTracks.map(\.id), startingAt: currentTrack?.id ?? "")
        } else {
            queue.restore(ids: retained, original: original, shuffled: queue.shuffled, repeatMode: queue.repeatMode)
        }
        if restorePlayback, loadedID == nil {
            do {
                if let saved = try bookmarkStore.restore(available: available),
                   let target = tracks.first(where: { $0.id == saved.trackID }), target.remote != nil {
                    current = target; lyrics = Lyrics.parse(target.lyrics)
                    restoredPosition = target.duration > 0 ? MediaTime.clamped(saved.position, duration: target.duration) : saved.position
                    snapshot = PlaybackSnapshot(position: restoredPosition, duration: target.duration)
                    queue.restore(ids: saved.queueIDs, original: saved.originalIDs,
                                  shuffled: saved.shuffled, repeatMode: saved.repeatMode)
                    queueTitle = saved.queueTitle ?? "上次队列"; queueFinished = saved.finished ?? false
                }
            } catch { notice("续听记录未能读取，曲库仍可正常使用。") }
        }
        reloadArtworks()
    }

    func setRemoteArtwork(_ image: UIImage, for trackIDs: [String]) {
        for id in trackIDs { artworks[id] = image; albumArtworks[id] = image }
        if let currentTrack, trackIDs.contains(currentTrack.id), loadedID != nil {
            mediaSession.update(track: currentTrack, snapshot: snapshot, artwork: image)
        }
    }

    private func audioURL(for track: Track) throws -> URL {
        if let remote = track.remote {
            guard let remoteURL else { throw NavidromeError.notConnected }
            return try remoteURL(remote)
        }
        if track.isDemo {
            guard let url = Bundle.main.url(forResource: track.audioFile, withExtension: nil) else { throw LibraryError.missingAudio }
            return url
        }
        guard LibraryRepository.isSafeBasename(track.audioFile) else { throw LibraryError.missingAudio }
        return directory.appendingPathComponent(track.audioFile)
    }

    private func artworkImage(for track: Track) -> UIImage? {
        if let filename = track.artworkFile, LibraryRepository.isSafeBasename(filename),
           let image = UIImage(contentsOfFile: directory.appendingPathComponent(filename).path) {
            return image
        } else if let asset = BundledAlbumCatalog.artworkAssetName(for: track.id) {
            return UIImage(named: asset)
        } else if track.isDemo && track.id == "sea" {
            return UIImage(named: "SeaCover")
        }
        return nil
    }
}
