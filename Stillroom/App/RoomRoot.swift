import SwiftUI
import UniformTypeIdentifiers

private enum OrbitUtility: Equatable { case lyrics, crafted, memories }

/// Freeze the sleeve being inspected. A skip while this sheet is open must not retarget its
/// cover, edit action or memory destination to a different record.
private struct TurntableSleeveTarget: Identifiable {
    let album: Track
    let record: CraftedRecord?
    var id: String { record.map { "craft:" + $0.id } ?? "album:" + album.albumKey }
}

struct RoomRoot: View {
    @EnvironmentObject private var player: PlayerStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    @State private var utility: OrbitUtility?
    @State private var settingsVisible = false
    // Start this preview in the collection so everyday browsing is visible. The original's
    // launch/last-page policy was not established by its empty-library captures.
    @State private var destination: RoomDestination = .library
    @State private var pendingMedia: ImportRequest?
    @State private var mediaPickerVisible = false
    @StateObject private var crafted = CraftedRecordsStore()
    @State private var memoryTrack: Track?
    @State private var completionGate = CraftCompletionGate()
    @State private var sleeveTarget: TurntableSleeveTarget?
    @State private var sleeveMemory: Track?
    @State private var pendingSleeveEdit: CraftedRecord?
    @State private var studioEditing: CraftedRecord?
    @State private var studioRequest = UUID()
    @State private var recordOpeningVisible = RecordOpeningPreferences().shouldPresent
    @State private var openingCommitted = false
    private let recordOpeningPreferences = RecordOpeningPreferences()

    private var presentation: OrbitPlaybackPresentation {
        OrbitPlaybackPresentation(current: player.current, albums: player.albums(),
            albumTracks: player.craftedSession == nil ? player.albumTracks(player.current) : player.tracks,
            artworks: player.artworks, albumArtworks: player.albumArtworks, playing: player.isPlaying,
            preparing: player.snapshot.isPreparing, position: player.position, duration: player.duration,
            selectionRevision: player.selectionRevision, transition: player.recordTransition,
            reducedMotion: player.reducedMotion || systemReducedMotion, libraryReady: player.libraryReady,
            active: scenePhase == .active && destination == .player && utility == nil && sleeveTarget == nil && !settingsVisible && !player.showingImport && !recordOpeningVisible,
            queueFinished: player.queueFinished,
            statusCaption: player.craftedSession.map { session in
                session.phase == .awaitingFlip ? "A 面已结束 · 等待翻面" :
                    session.phase == .finished ? (session.allReachedEnd ? "自制唱片已播放至末尾" : "这次试听已收针") :
                    session.record.title + " · " + session.side.label
            }, craftedSession: player.craftedSession,
            craftedCover: player.craftedSession?.record.coverAsset.flatMap { crafted.images[$0] },
            craftedCollected: player.craftedSession.map { session in
                crafted.records.contains { $0.id == session.record.id && $0.collectedAt != nil && $0.hasSameEdition(as: session.record) }
            } ?? false, archiveBusy: crafted.busy,
            canSkipNext: player.queue.ids.count > 1 && player.craftedSession?.phase != .awaitingFlip && player.craftedSession?.phase != .finished,
            canSkipPrevious: player.queue.ids.count > 1)
    }
    private var actions: OrbitHomeActions {
        OrbitHomeActions(selectAlbum: player.playHomeAlbum, toggle: player.toggle, skip: { player.skip($0) }, seek: player.seek,
            library: { destination = .library }, settings: { settingsVisible = true }, lyrics: { utility = .lyrics },
            importMusic: { player.showingImport = true }, queue: { destination = .queue },
            craftedRecords: { studioEditing = nil; studioRequest = UUID(); utility = .crafted },
            songMemories: { memoryTrack = player.current; utility = .memories }, openCurrent: returnToTurntable,
            sleeve: openCurrentSleeve, flip: player.flipCraftedSide,
            collect: {
                guard let record = player.craftedSession?.record else { return false }
                return await collect(record)
            }, endListening: player.endCraftedListening, recordOpening: openRecordOpening,
            rotate: { RoomOrientationAdapter.toggle(onFailure: player.notice) })
    }
    private var mediaTypes: [UTType] {
        if let pendingMedia, case .cover = pendingMedia { return [.jpeg, .png] }
        return [.plainText, .text, UTType(filenameExtension: "lrc") ?? .text]
    }

    var body: some View {
        ZStack(alignment: .top) {
            mainPage
                .environment(\.roomMotionVisible, destination == .player && utility == nil && sleeveTarget == nil && !settingsVisible && !player.showingImport && !recordOpeningVisible)
                .opacity(utility == nil && !recordOpeningVisible ? 1 : 0)
                .allowsHitTesting(utility == nil && !recordOpeningVisible)
                .accessibilityHidden(utility != nil || recordOpeningVisible)
            if let utility {
                utilityPage(utility).transition(.opacity).zIndex(2)
            }
            if recordOpeningVisible {
                RecordOpeningScene(albums: player.albums(),
                    artworks: player.artworks.merging(player.albumArtworks) { _, album in album },
                    playingTrackID: player.current.id, playing: player.isPlaying,
                    preparing: player.snapshot.isPreparing, libraryReady: player.libraryReady,
                    reducedMotion: player.reducedMotion,
                    onPlay: { track in
                        guard player.libraryReady,
                              let live = player.tracks.first(where: { $0.id == track.id }) else {
                            player.notice("曲库还在读取，请稍后再落针。")
                            return
                        }
                        openingCommitted = true
                        player.choose(live, in: player.albumTracks(live), autoplay: true)
                    }, onPause: player.pause, onFinish: finishRecordOpening)
                    .zIndex(4)
            }
            if let message = player.message {
                Text(message).font(.subheadline).foregroundStyle(.white).padding(16).frame(maxWidth: .infinity)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 20).padding(.top, 8)
                    .onTapGesture { player.message = nil }.accessibilityIdentifier("room.notice").zIndex(10)
            }
        }.tint(RoomStyle.accent)
        .preferredColorScheme(!recordOpeningVisible && utility == nil && destination == .player &&
                              player.orbitPreferences.selectedHome == .turntable && !player.orbitPreferences.usesLightContent ? .light : .dark)
        .task {
            await crafted.restore()
            if let record = player.craftedSession?.record { await crafted.prepareEdition(record) }
            persistCraftCompletion()
        }
        .onChange(of: player.craftedSession) { _, session in
            if let record = session?.record { Task { await crafted.prepareEdition(record) } }
            persistCraftCompletion()
        }
        .onChange(of: crafted.busy) { _, busy in if !busy { persistCraftCompletion() } }
        .onChange(of: crafted.error) { _, error in
            if let error, utility != .crafted { player.notice(error) }
        }
        .sheet(item: $sleeveTarget, onDismiss: finishSleeveDismissal) { target in
            sleevePage(target).presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $player.showingImport, onDismiss: { Task { await player.importCoordinator.reset() } }) {
            MusicImportScreen(coordinator: player.importCoordinator).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $settingsVisible) {
            SettingsScreen(onClose: { settingsVisible = false })
                .presentationDetents([.medium, .large]).presentationDragIndicator(.hidden)
        }
        .onChange(of: player.showingPlayer) { _, shown in
            if shown { returnToTurntable(); player.showingPlayer = false }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { player.checkpoint() } }
        .onChange(of: player.importRequest?.id) { _, _ in
            guard let request = player.importRequest else { return }
            switch request {
            case .lyrics, .cover: pendingMedia = request; mediaPickerVisible = true
            case .music, .folder: player.showingImport = true; player.importRequest = nil
            }
        }
        .fileImporter(isPresented: $mediaPickerVisible, allowedContentTypes: mediaTypes, allowsMultipleSelection: false) { result in
            let target = pendingMedia; pendingMedia = nil; player.importRequest = nil
            switch result {
            case .success(let urls):
                Task {
                    guard let target else { return }
                    switch target {
                    case .lyrics(let id):
                        await player.importCoordinator.prepareReplacement(urls: urls, trackID: id, kind: .lyrics)
                    case .cover(let id, let album):
                        await player.importCoordinator.prepareReplacement(urls: urls, trackID: id, kind: .cover, album: album)
                    default: return
                    }
                    player.showingImport = true
                }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { player.notice("文件未能打开：" + error.localizedDescription) }
            }
        }
    }

    private var mainPage: some View {
        ZStack {
            switch destination {
            case .library:
                RoomLibraryHome(tracks: player.libraryTracks, artworks: player.artworks,
                    albumArtworks: player.albumArtworks, favorites: player.favorites,
                    currentID: player.current.id, playing: player.isPlaying,
                    libraryReady: player.libraryReady, reducedMotion: player.reducedMotion,
                    onPlay: { track, items in
                        player.choose(track, in: items, autoplay: true)
                        returnToTurntable()
                    }, onImport: { player.showingImport = true },
                    onSettings: { settingsVisible = true }, onCrafted: actions.craftedRecords)
            case .player:
                OrbitHomeView(presentation: presentation, preferences: $player.orbitPreferences,
                              actions: actions, destination: $destination)
            case .queue:
                RoomQueueHome(tracks: player.tracks, queue: player.queue, title: player.queueTitle,
                    currentID: player.current.id, playing: player.isPlaying,
                    onSelect: { track in player.choose(track); returnToTurntable() },
                    onShuffle: player.toggleShuffle,
                    onRepeat: { player.setQueueMode(repeatMode: $0) })
            }
        }
        // The full-window deck owns its replacing tool/transport presentation. Other pages
        // retain the usual safe-area navigation; they must not shorten the deck's viewport.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if destination != .player || player.orbitPreferences.selectedHome != .turntable {
                RoomMainNavigation(destination: $destination, playing: player.isPlaying,
                    canPlay: player.libraryReady && !player.tracks.isEmpty, onToggle: player.toggle,
                    artwork: player.artworks[player.current.id], reducedMotion: player.reducedMotion)
            }
        }
    }

    @ViewBuilder private func utilityPage(_ page: OrbitUtility) -> some View {
        switch page {
        case .crafted:
            CraftedStudioView(tracks: player.tracks, artworks: player.artworks, archive: crafted,
                initialEditing: studioEditing, onOpen: { record in
                    sleeveTarget = TurntableSleeveTarget(album: player.current, record: record)
                }, onPlay: playCrafted, onClose: { utility = nil })
                .id(studioRequest)
        case .memories:
            if let track = memoryTrack {
                SongMemoriesView(track: track, memories: crafted.memories(for: track.id), images: crafted.images,
                    onSave: { await crafted.saveMemory($0, photoJPEG: $1) }, onClose: { utility = nil })
                    .safeAreaInset(edge: .bottom) { miniPlayer }
            }
        case .lyrics:
            NavigationStack {
                ZStack {
                    RoomBackground()
                    LyricsPanel(lines: player.lyrics, plainText: player.current.lyrics, activeIndex: player.lyricIndex,
                                isDemo: player.current.isLyricDemo, onSeek: player.seek).padding(24)
                }.navigationTitle(player.current.title).navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { Button("返回", action: { utility = nil }).accessibilityIdentifier("lyrics.close") }
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu("资料", systemImage: "ellipsis.circle") {
                                Button("导入歌词") { player.importRequest = .lyrics(trackID: player.current.id) }
                                Button("这首歌曲封面") { player.importRequest = .cover(trackID: player.current.id, album: false) }
                                Button("整张专辑封面") { player.importRequest = .cover(trackID: player.current.id, album: true) }
                            }.accessibilityIdentifier("lyrics.media")
                        }
                    }
            }.safeAreaInset(edge: .bottom) { miniPlayer }.accessibilityIdentifier("lyrics.page")
        }
    }

    private var miniPlayer: some View {
        HStack(spacing: 12) {
            Button {
                returnToTurntable()
            } label: {
                HStack(spacing: 10) {
                    ArtworkView(track: presentation.displayTrack, image: presentation.displayArtwork)
                        .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 5))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.current.title).font(.subheadline).lineLimit(1)
                        Text(player.isPlaying ? player.current.artist : "已暂停").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }.buttonStyle(.plain).accessibilityIdentifier("mini.open")
            Button(action: player.toggle) { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 44, height: 44) }
                .buttonStyle(.plain).accessibilityIdentifier("mini.play").accessibilityLabel(player.isPlaying ? "暂停" : "播放")
            Button { player.skip(1) } label: { Image(systemName: "forward.end.fill").frame(width: 44, height: 44) }
                .buttonStyle(.plain).accessibilityIdentifier("mini.next")
        }.foregroundStyle(.white).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private func returnToTurntable() {
        utility = nil
        destination = .player
        player.orbitPreferences.selectedHome = .turntable
    }

    private func openRecordOpening() {
        // Opening the preview is explicit. Pause the current engine instead of leaving an
        // unrelated playing song behind a visually selected but uncommitted record.
        player.pause()
        utility = nil
        openingCommitted = false
        recordOpeningVisible = true
    }

    private func finishRecordOpening() {
        recordOpeningPreferences.complete()
        recordOpeningVisible = false
        if openingCommitted { returnToTurntable() }
    }

    private func playCrafted(_ record: CraftedRecord) {
        guard player.playCrafted(record) else { return }
        sleeveTarget = nil
        returnToTurntable()
    }

    private func openCurrentSleeve() {
        sleeveTarget = TurntableSleeveTarget(album: presentation.currentAlbum, record: player.craftedSession?.record)
    }

    private func finishSleeveDismissal() {
        sleeveMemory = nil
        if let record = pendingSleeveEdit {
            pendingSleeveEdit = nil
            studioEditing = crafted.records.first { $0.id == record.id } ?? record
            // Editing the same record twice still constitutes two presentation requests.
            studioRequest = UUID()
            utility = .crafted
        }
    }

    private func sleevePage(_ target: TurntableSleeveTarget) -> some View {
        let record = target.record
        let ids = Set(record?.allTrackIDs ?? player.albumTracks(target.album).map(\.id))
        return TurntableSleeveSheet(record: record, album: target.album,
            cover: record.map { $0.coverAsset.flatMap { crafted.images[$0] } } ?? player.albumArtworks[target.album.id],
            tracks: record == nil ? player.albumTracks(target.album) : player.tracks,
            memories: crafted.memories.filter { ids.contains($0.trackID) }, images: crafted.images,
            currentID: player.current.id, playing: player.isPlaying,
            isOnTurntable: record.map { value in
                player.craftedSession.map { $0.record.hasSameEdition(as: value) && $0.phase != .finished } ?? false
            } ?? (player.craftedSession == nil && player.current.albumKey == target.album.albumKey && !player.queueFinished),
            collected: record.map { value in crafted.records.contains { $0.id == value.id && $0.collectedAt != nil && $0.hasSameEdition(as: value) } } ?? false,
            busy: crafted.busy, onPlay: {
                if let record {
                    if let session = player.craftedSession, session.record.hasSameEdition(as: record), session.phase != .finished {
                        sleeveTarget = nil; returnToTurntable()
                    } else { playCrafted(record) }
                } else {
                    if player.craftedSession != nil || player.current.albumKey != target.album.albumKey || player.queueFinished {
                        player.playHomeAlbum(target.album.albumKey)
                    }
                    sleeveTarget = nil; returnToTurntable()
                }
            }, onMemory: { sleeveMemory = $0 }, onEdit: { value in
                // Dismiss the inspection sheet before presenting its editor. Presenting both at once
                // loses the full-screen editor during SwiftUI's dismissal transaction.
                pendingSleeveEdit = value; sleeveTarget = nil
            }, onCollect: {
                guard let record else { return false }
                return await collect(record)
            }, onClose: { sleeveTarget = nil })
            .sheet(item: $sleeveMemory) { track in
                SongMemoriesView(track: track, memories: crafted.memories(for: track.id), images: crafted.images,
                    onSave: { await crafted.saveMemory($0, photoJPEG: $1) }, onClose: { sleeveMemory = nil })
            }
    }

    @MainActor private func collect(_ record: CraftedRecord) async -> Bool {
        guard let latest = crafted.records.first(where: { $0.id == record.id }), latest.hasSameEdition(as: record) else {
            player.notice("这张唱片的制作版本已更新，请先查看最新封套再收藏。")
            return false
        }
        if let session = player.craftedSession, session.record.hasSameEdition(as: record),
           session.allReachedEnd, latest.completedAt == nil {
            guard await crafted.markCompleted(record.id) else { return false }
        }
        return await crafted.collect(record.id)
    }

    private func persistCraftCompletion() {
        guard crafted.ready, !crafted.busy, let session = player.craftedSession,
              let id = completionGate.claim(session: session, records: crafted.records) else { return }
        // A memory save can be in flight at natural completion. The busy→idle observer retries the
        // boundary; the edition gate prevents our write or failure from starting an infinite retry.
        Task {
            // The task starts on the next actor turn. An editor may have committed in between;
            // once this guard passes, the store's synchronous busy latch excludes another edit.
            guard crafted.records.first(where: { $0.id == id })?.hasSameEdition(as: session.record) == true else { return }
            _ = await crafted.markCompleted(id)
        }
    }
}
