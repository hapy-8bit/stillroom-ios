import Foundation

/// Decorative seconds never enter the media readout. The host samples phase in
/// TimelineView and commits only running-state boundaries, avoiding State writes
/// while a Canvas is drawing. Paused, loading and inactive intervals add no time.
struct OneTapeScreenMotionClock: Equatable, Sendable {
    private(set) var accumulatedSeconds: TimeInterval = 0
    private var runningSince: TimeInterval?

    var isRunning: Bool { runningSince != nil }

    func phase(at seconds: TimeInterval) -> Double {
        guard seconds.isFinite, let runningSince else { return accumulatedSeconds }
        let phase = accumulatedSeconds + max(0, seconds - runningSince)
        return phase.isFinite ? phase : accumulatedSeconds
    }

    mutating func setRunning(_ running: Bool, at seconds: TimeInterval) {
        guard seconds.isFinite else { return }
        if running {
            if runningSince == nil { runningSince = seconds }
        } else if runningSince != nil {
            accumulatedSeconds = phase(at: seconds)
            self.runningSince = nil
        }
    }

    mutating func reset(at seconds: TimeInterval, running: Bool = false) {
        accumulatedSeconds = 0
        runningSince = running && seconds.isFinite ? seconds : nil
    }
}
