import Foundation

/// Display-only values derived from the same media snapshot as the full player.
struct MechanicalPlaybackReadout {
    let elapsed: Double
    let remaining: Double
    let ordinal: Int
    let total: Int

    init(position: Double, duration: Double, ordinal: Int, total: Int) {
        let safeDuration = duration.isFinite ? max(0, duration) : 0
        elapsed = MediaTime.clamped(position, duration: safeDuration)
        remaining = max(0, safeDuration - elapsed)
        self.total = max(0, total)
        self.ordinal = self.total > 0 ? min(self.total, max(1, ordinal)) : 0
    }

    var trackLabel: String { String(format: "%02d / %02d", ordinal, total) }
    var elapsedLabel: String { MediaTime.label(elapsed) }
    var remainingLabel: String { MediaTime.label(remaining) }
}
