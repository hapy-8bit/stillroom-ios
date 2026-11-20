import Foundation

enum OneTapeTransportRules {
    enum PreviousAction: Equatable { case restart, previous }
    static let windingRate = 6.0
    static let trackChangeWindSeconds = 0.65
    static let trackChangeBrakeSeconds = 0.14
    static let trackChangeRate = 14.0

    static func previousAction(position: TimeInterval) -> PreviousAction {
        position.isFinite && position > 3 ? .restart : .previous
    }

    /// Media positions, elapsed monotonic time and duration are all seconds.
    /// Winding stops at the current recording's boundaries and never wraps.
    static func windingPosition(start: TimeInterval, elapsed: TimeInterval,
                                direction: Int, duration: TimeInterval) -> TimeInterval {
        guard start.isFinite, elapsed.isFinite, duration.isFinite, duration > 0 else { return 0 }
        let signedRate = direction == 0 ? 0 : direction > 0 ? windingRate : -windingRate
        return MediaTime.clamped(start + max(0, elapsed) * signedRate, duration: duration)
    }
}
