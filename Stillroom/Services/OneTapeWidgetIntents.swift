import AppIntents
import Foundation

enum OneTapeWidgetCommand: Sendable {
    case togglePlayback
    case nextTrack
    case previousTrack
}

#if !ONE_TAPE_WIDGET_EXTENSION
/// Routes Home Screen widget `AudioPlaybackIntent` invocations into the single
/// authoritative `OneTapeMusicStore` / `PlayerStore` running in the app process.
@MainActor
final class OneTapeWidgetCommandBridge {
    static let shared = OneTapeWidgetCommandBridge()

    private weak var musicStore: OneTapeMusicStore?
    private var fallbackStore: OneTapeMusicStore?

    func attach(_ store: OneTapeMusicStore) {
        musicStore = store
        fallbackStore = nil
    }

    func activeStore() -> OneTapeMusicStore {
        if let musicStore { return musicStore }
        if let fallbackStore { return fallbackStore }
        let created = OneTapeMusicStore()
        fallbackStore = created
        return created
    }

    func perform(_ command: OneTapeWidgetCommand) async {
        let store = activeStore()
        await store.restore()
        guard store.player.currentTrack != nil else {
            publishCurrentState(from: store)
            return
        }
        switch command {
        case .togglePlayback:
            store.togglePlaybackForTape()
        case .nextTrack:
            store.stepTrackForTape(1)
        case .previousTrack:
            store.stepTrackForTape(-1)
        }
        // Allow AVAudioEngine / PlayerStore to publish the updated state before
        // snapshotting into the App Group container for WidgetKit.
        try? await Task.sleep(for: .milliseconds(160))
        publishCurrentState(from: store)
    }

    func publishCurrentState(from store: OneTapeMusicStore) {
        let artwork = store.player.currentTrack.flatMap { store.artwork(for: $0) }
        let rgb = OneTapeArtworkColorSampler.color(from: artwork)
        let snapshot = Self.makeSnapshot(from: store, hasArtwork: artwork != nil, tint: rgb)
        OneTapeWidgetSyncCoordinator.shared.sync(snapshot: snapshot, artwork: artwork, force: true)
    }

    static func makeSnapshot(
        from store: OneTapeMusicStore,
        hasArtwork: Bool,
        tint: OneTapeTransportMaterial.RGB?,
        now: Date = Date()
    ) -> OneTapeWidgetSnapshot {
        guard let track = store.player.currentTrack else {
            return .empty
        }
        let ids = store.player.queue.ids
        let tracks = store.player.tracks
        let trackIndex = ids.firstIndex(of: track.id) ?? 0
        let progress = OneTapeTapeGeometry.progress(
            queueIDs: ids,
            tracks: tracks,
            currentID: track.id,
            position: store.player.position
        )
        let lookup = Dictionary(tracks.map { ($0.id, $0.duration) }, uniquingKeysWith: { _, last in last })
        let totalDuration = ids.reduce(0.0) { partial, id in
            let seconds = lookup[id] ?? 0
            return partial + (seconds.isFinite && seconds > 0 ? seconds : 0)
        }
        let currentDuration = store.player.duration > 0 ? store.player.duration : max(0, track.duration)
        let remainingCurrent = max(0, currentDuration - store.player.position)
        let remainingAfterCurrent = ids.dropFirst(trackIndex + 1).reduce(0.0) { partial, id in
            let seconds = lookup[id] ?? 0
            return partial + (seconds.isFinite && seconds > 0 ? seconds : 0)
        }
        let albumName = track.album.trimmingCharacters(in: .whitespacesAndNewlines)
        let widgetTint = tint.map { OneTapeWidgetTint(red: $0.red, green: $0.green, blue: $0.blue) }
        let artworkKey = hasArtwork ? (track.artworkFile ?? track.remote?.coverArtID ?? track.id) : ""
        return OneTapeWidgetSnapshot(
            title: track.title,
            artist: track.artist,
            album: albumName,
            trackNumber: trackIndex + 1,
            isPlaying: store.player.isPlaying,
            progress: progress,
            tint: widgetTint,
            updated: now,
            artworkID: artworkKey,
            albumDuration: totalDuration > 0 ? totalDuration : currentDuration,
            playbackRemaining: remainingCurrent + remainingAfterCurrent
        )
    }
}
#endif

struct OneTapeTogglePlaybackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "播放或暂停"
    static let description = IntentDescription("在 One Cassette 中播放或暂停磁带。")
    static let openAppWhenRun = false

    init() {}

    func perform() async throws -> some IntentResult {
        #if !ONE_TAPE_WIDGET_EXTENSION
        await OneTapeWidgetCommandBridge.shared.perform(.togglePlayback)
        #endif
        return .result()
    }
}

struct OneTapeNextTrackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "下一首"
    static let description = IntentDescription("跳到磁带的下一首歌曲。")
    static let openAppWhenRun = false

    init() {}

    func perform() async throws -> some IntentResult {
        #if !ONE_TAPE_WIDGET_EXTENSION
        await OneTapeWidgetCommandBridge.shared.perform(.nextTrack)
        #endif
        return .result()
    }
}

struct OneTapePreviousTrackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "上一首"
    static let description = IntentDescription("回到磁带的上一首歌曲。")
    static let openAppWhenRun = false

    init() {}

    func perform() async throws -> some IntentResult {
        #if !ONE_TAPE_WIDGET_EXTENSION
        await OneTapeWidgetCommandBridge.shared.perform(.previousTrack)
        #endif
        return .result()
    }
}
