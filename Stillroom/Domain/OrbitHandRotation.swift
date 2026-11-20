import Foundation

/// A gesture transaction, not a playback clock. Angles are visual degrees; captured media
/// values are seconds and produce one seek request only when the same owner releases.
struct OrbitHandRotation: Equatable {
    private struct Drag: Equatable {
        let owner: String
        let position: Double
        let duration: Double
        var previousAngle: Double?
    }

    private(set) var restingDegrees: Double = 0
    private(set) var dragDegrees: Double = 0
    private var drag: Drag?
    private var blocked = false

    var degrees: Double { restingDegrees + dragDegrees }

    mutating func update(owner: String, startAngle: Double?, angle: Double?, position: Double, duration: Double) {
        guard !blocked else { return }
        if drag == nil {
            guard let startAngle, startAngle.isFinite else { blocked = true; return }
            drag = Drag(owner: owner, position: position, duration: duration,
                        previousAngle: Self.normalized(startAngle))
        }
        guard drag?.owner == owner else {
            // A selection can change while a finger stays down. Remaining events from that
            // physical gesture must not acquire the new track's owner or captured position.
            cancel(blockUntilRelease: true)
            return
        }
        guard let angle, angle.isFinite else { drag?.previousAngle = nil; return }
        let current = Self.normalized(angle)
        if let previous = drag?.previousAngle { dragDegrees += Self.normalized(current - previous) }
        drag?.previousAngle = current
    }

    mutating func finish(owner: String, active: Bool) -> Double? {
        defer { cancel() }
        guard active, let drag, drag.owner == owner, !blocked else { return nil }
        // Fold only a completed gesture into the held visual phase. The next gesture starts
        // with zero seek delta even though its record print keeps the previous resting angle.
        restingDegrees = Self.normalized(restingDegrees + dragDegrees)
        guard drag.position.isFinite, drag.duration.isFinite, drag.duration > 0 else { return nil }
        return MediaTime.clamped(drag.position + dragDegrees / 360 * drag.duration, duration: drag.duration)
    }

    /// Interrupted motion is discarded; already committed visual rotation is retained. A
    /// hidden/changed view blocks the still-held gesture until its release cleanup runs.
    mutating func cancel(blockUntilRelease: Bool = false) {
        drag = nil
        dragDegrees = 0
        blocked = blockUntilRelease
    }

    /// A new physical record/side starts with a fresh visual phase, never the old hand's turn.
    mutating func resetRecord(blockUntilRelease: Bool = false) {
        restingDegrees = 0
        cancel(blockUntilRelease: blockUntilRelease)
    }

    private static func normalized(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return 0 }
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        if wrapped > 180 { return wrapped - 360 }
        if wrapped < -180 { return wrapped + 360 }
        return wrapped
    }
}
