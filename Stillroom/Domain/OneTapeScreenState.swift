import Foundation

/// The engine exposes one preparation flag for initial loading and buffering.
/// Screen copy must not invent a separate buffering state or playback intent.
enum OneTapeScreenState: String, Equatable, Sendable {
    case empty, loading, playing, paused

    var statusLabel: String {
        switch self {
        case .empty: "NO TAPE"
        case .loading: "LOADING"
        case .playing: "PLAY"
        case .paused: "PAUSED"
        }
    }

    var allowsMotion: Bool { self == .playing }
}

extension OneTapePlaybackReadout {
    var screenState: OneTapeScreenState {
        guard hasTrack else { return .empty }
        if isPreparing { return .loading }
        return isPlaying ? .playing : .paused
    }

    var screenTitle: String {
        guard hasTrack else { return "还没有磁带" }
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "未命名歌曲" : value
    }

    var screenArtist: String {
        guard hasTrack else { return "在音乐库添加音乐" }
        let value = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "未知艺人" : value
    }

    var screenStatusLabel: String { screenState.statusLabel }
    var screenTrackLabel: String {
        hasTrack ? "曲 " + trackLabel : "曲 --/--"
    }
    var screenSideLabel: String {
        // This is a queue-count display convention, not a transport side or
        // tape-capacity calculation. Odd queues leave the extra track on B.
        let isSideA = trackCount <= 1 || trackIndex < trackCount / 2
        return isSideA ? "面 A" : "面 B"
    }
    var screenElapsedLabel: String { hasTrack ? positionLabel : "--:--" }
    var screenDurationLabel: String { hasTrack && durationSeconds > 0 ? durationLabel : "--:--" }
    var screenTimeLabel: String { screenElapsedLabel + " " + screenRemainingLabel }
}
