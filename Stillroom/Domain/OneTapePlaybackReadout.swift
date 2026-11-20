import Foundation

/// A projection of the authoritative player state. Track indices are zero-based
/// and all media times are seconds; decorative animation clocks do not enter it.
struct OneTapePlaybackReadout: Equatable, Sendable {
    let title: String
    let artist: String
    let positionSeconds: TimeInterval
    let durationSeconds: TimeInterval
    let isPlaying: Bool
    let isPreparing: Bool
    let trackIndex: Int
    let trackCount: Int
    let trackID: String

    static let empty = OneTapePlaybackReadout(
        title: "", artist: "", positionSeconds: 0, durationSeconds: 0,
        isPlaying: false, isPreparing: false, trackIndex: 0, trackCount: 0
    )

    init(title: String, artist: String, positionSeconds: TimeInterval,
         durationSeconds: TimeInterval, isPlaying: Bool, isPreparing: Bool,
         trackIndex: Int, trackCount: Int, trackID: String = "") {
        self.title = title
        self.artist = artist
        let duration = Self.finiteSeconds(durationSeconds)
        let position = Self.finiteSeconds(positionSeconds)
        self.durationSeconds = duration
        self.positionSeconds = duration > 0 ? min(position, duration) : position
        self.isPlaying = isPlaying
        self.isPreparing = isPreparing
        self.trackCount = max(0, trackCount)
        self.trackIndex = min(max(0, trackIndex), max(0, self.trackCount - 1))
        self.trackID = trackID
    }

    var hasTrack: Bool { !trackID.isEmpty || trackCount > 0 || !title.isEmpty || !artist.isEmpty }
    var fraction: Double { durationSeconds > 0 ? positionSeconds / durationSeconds : 0 }
    var positionLabel: String { Self.clock(positionSeconds) }
    var durationLabel: String { Self.clock(durationSeconds) }
    var remainingLabel: String { "-" + Self.clock(max(0, durationSeconds - positionSeconds)) }
    var screenRemainingLabel: String {
        guard hasTrack, durationSeconds > 0 else { return "--:--" }
        // Quantize the two counters before subtraction, so a fractional media
        // position cannot make remaining time tick before the elapsed label.
        let remaining = max(0, floor(durationSeconds) - floor(positionSeconds))
        return "-" + Self.clock(remaining)
    }
    var trackLabel: String {
        String(format: "%02d/%02d", hasTrack ? trackIndex + 1 : 1, max(1, trackCount))
    }

    private static func finiteSeconds(_ seconds: TimeInterval) -> TimeInterval {
        seconds.isFinite ? max(0, seconds) : 0
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let value = Int(min(seconds, Double(Int.max / 4)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
