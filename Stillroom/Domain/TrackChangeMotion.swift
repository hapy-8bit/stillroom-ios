import Foundation

/// A visual-only swap: lift the arm, exchange records, then lower it. Direction is +1 for next.
struct TrackChangeMotion {
    static let duration = 0.9
    let outgoingOpacity: Double
    let incomingOpacity: Double
    let outgoingX: Double
    let incomingX: Double
    let outgoingScale: Double
    let incomingScale: Double
    let needle: Double
    let atmosphere: Double

    init(progress: Double, direction: Int, reducedMotion: Bool) {
        let p = progress.isFinite ? min(1, max(0, progress)) : 0
        let sign = direction < 0 ? -1.0 : 1.0
        if reducedMotion {
            outgoingOpacity = 1 - p
            incomingOpacity = p
            outgoingX = 0
            incomingX = 0
            outgoingScale = 1
            incomingScale = 1
            needle = 1
            atmosphere = p
        } else {
            let leave = TurntableJourneyPose.phase(p, from: 0.16, to: 0.56)
            let enter = TurntableJourneyPose.phase(p, from: 0.28, to: 0.78)
            outgoingOpacity = 1 - leave
            incomingOpacity = enter
            // Offsets are fractions of the record diameter, not screen pixels.
            outgoingX = -sign * 0.16 * leave
            incomingX = sign * 0.16 * (1 - enter)
            outgoingScale = 1 - leave * 0.04
            incomingScale = 0.95 + enter * 0.05
            needle = 1 - TurntableJourneyPose.phase(p, from: 0, to: 0.16) +
                TurntableJourneyPose.phase(p, from: 0.78, to: 1)
            atmosphere = TurntableJourneyPose.phase(p, from: 0.18, to: 0.78)
        }
    }
}
