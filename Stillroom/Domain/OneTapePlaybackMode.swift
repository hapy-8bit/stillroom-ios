import Foundation

/// Single-key playback mode cycling for the cassette deck's top-left switch.
/// Maps directly onto `PlaybackQueue` without introducing separate queue state.
enum OneTapePlaybackMode: String, CaseIterable, Equatable, Sendable {
    case listLoop
    case singleLoop
    case shuffle

    init(shuffled: Bool, repeatMode: RepeatMode) {
        if shuffled {
            self = .shuffle
        } else if repeatMode == .one {
            self = .singleLoop
        } else {
            self = .listLoop
        }
    }

    var next: OneTapePlaybackMode {
        switch self {
        case .listLoop: .singleLoop
        case .singleLoop: .shuffle
        case .shuffle: .listLoop
        }
    }

    var title: String {
        switch self {
        case .listLoop: "列表循环"
        case .singleLoop: "单曲循环"
        case .shuffle: "随机播放"
        }
    }
}
