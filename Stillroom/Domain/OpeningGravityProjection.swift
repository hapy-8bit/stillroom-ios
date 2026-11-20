import Foundation

/// The intro uses gravity relative to the first motion sample, in g units. The recovered
/// callback folds a delta past ±1 back toward zero and publishes only beyond a 0.015 deadband.
struct OpeningGravityProjection {
    static let updateInterval: TimeInterval = 1 / 60
    static let deadband = 0.015
    private var originY: Double?
    private(set) var value = 0.0

    /// Starting a new sensor run captures a new baseline. Retain the visible value until the
    /// first valid sample arrives, so stopping for sleeve selection cannot move its hinge.
    mutating func beginRun() { originY = nil }

    /// Returns only a newly published value. Nonfinite sensor samples do not replace baseline.
    mutating func ingest(rawY: Double) -> Double? {
        guard rawY.isFinite else { return nil }
        if originY == nil { originY = rawY }
        guard let originY else { return nil }
        let delta = rawY - originY
        guard delta.isFinite else { return nil }
        let next = delta > 1 ? 2 - delta : delta < -1 ? -2 - delta : delta
        guard abs(next - value) > Self.deadband else { return nil }
        value = next
        return next
    }
}
