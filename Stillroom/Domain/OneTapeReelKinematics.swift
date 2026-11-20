import Foundation

/// Visual phase is integrated independently for each reel. Media seeks change
/// the target pack size, never the angle already travelled by a reel.
struct OneTapeReelKinematics: Equatable, Sendable {
    enum Layout: Equatable, Sendable {
        case transport
        case matched
    }

    struct Frame: Equatable, Sendable {
        let supplyRadians: Double
        let takeupRadians: Double
        let progress: Double
        let exposureDegrees: Double
    }

    // 48 mm/s is the rounded normal cassette speed in TASCAM's 202MKVII spec.
    // 11 mm is our nominal empty-pack radius, not a measurement of this artwork.
    // Convert once to the shared logical-point canvas; window scaling cancels.
    static let linearSpeed = 48 * OneTapeTapeGeometry.radii(progress: 0).takeup / 11

    private(set) var rate = 0.0
    private(set) var layout: Layout = .transport
    private var anchor: TimeInterval = 0
    private var supplyRadians = 0.0
    private var takeupRadians = 0.0
    private var startProgress = 0.0
    private var targetProgress = 0.0
    private var transitionSeconds = 0.0

    func frame(at seconds: TimeInterval) -> Frame {
        let elapsed = seconds.isFinite ? max(0, seconds - anchor) : 0
        let moving = min(elapsed, transitionSeconds)
        let fraction = transitionSeconds > 0 ? moving / transitionSeconds : 1
        let progress = startProgress + (targetProgress - startProgress) * fraction
        let start = OneTapeTapeGeometry.radii(progress: startProgress)
        let current = OneTapeTapeGeometry.radii(progress: progress)
        let target = OneTapeTapeGeometry.radii(progress: targetProgress)
        let settled = max(0, elapsed - moving)
        // Radius squared varies linearly with progress. Integrating 1/r over
        // that interval is exactly 2*dt/(r0+r1), including equal radii.
        let travel = Self.linearSpeed * rate
        // The six molded shells deliberately use equal decorative packs. Their
        // angular speed must stay equal through playback, seeking and winding.
        let matchedTravel = travel * elapsed / OneTapeTapeGeometry.radii(progress: 0.5).supply
        let supply = layout == .matched ? matchedTravel
            : travel * (2 * moving / (start.supply + current.supply) + settled / target.supply)
        let takeup = layout == .matched ? matchedTravel
            : travel * (2 * moving / (start.takeup + current.takeup) + settled / target.takeup)
        return Frame(supplyRadians: Self.wrapped(supplyRadians + supply),
            takeupRadians: Self.wrapped(takeupRadians + takeup), progress: progress,
            exposureDegrees: abs(rate) > 1 ? min(24, abs(rate) * 2) : 0)
    }

    mutating func update(rate requestedRate: Double, progress: Double, at seconds: TimeInterval,
                         layout requestedLayout: Layout = .transport) {
        guard seconds.isFinite, seconds >= anchor else { return }
        let previous = frame(at: seconds)
        supplyRadians = previous.supplyRadians
        takeupRadians = previous.takeupRadians
        startProgress = previous.progress
        targetProgress = progress.isFinite ? min(1, max(0, progress)) : previous.progress
        rate = requestedRate.isFinite ? min(32, max(-32, requestedRate)) : 0
        layout = requestedLayout
        anchor = seconds
        // Explicit track changes sweep to the target pack size during the same
        // fast-wind interval as the transport. Ordinary 4-Hz engine updates are
        // interpolated; a stopped/reduced-motion view still shows real progress.
        transitionSeconds = rate == 0 ? 0 : abs(rate) > 1
            ? OneTapeTransportRules.trackChangeWindSeconds : 0.25
    }

    private static func wrapped(_ radians: Double) -> Double {
        radians.isFinite ? radians.truncatingRemainder(dividingBy: 2 * .pi) : 0
    }
}
