import Foundation

/// A visual phase in degrees, reconciled with media snapshots. It never supplies playback time.
struct MechanicalWheelMotion {
    let rate: Double
    private var origin = 0.0
    private var correction = 0.0
    private var sampledAt = 0.0
    private var sampledSeconds = 0.0
    private var headroom = 0.0
    private var advancing = false
    private var initialized = false
    private var settlingDuration = 0.18

    init(rate: Double) { self.rate = rate.isFinite ? rate : 0 }

    mutating func observe(seconds: Double, running: Bool, remaining: Double, at time: Double, reset: Bool = false) {
        guard seconds.isFinite, time.isFinite else { return }
        let target = -seconds * 6
        guard target.isFinite else { return }
        guard initialized else {
            initialized = true
            origin = target
            sampledAt = time
            sampledSeconds = seconds
            headroom = remaining.isFinite ? max(0, remaining) : 0
            advancing = running
            return
        }
        let current = angle(at: time)
        let expected = advancing ? min(0.4, max(0, time - sampledAt)) * (rate / -6) : 0
        let jumped = reset || abs(seconds - sampledSeconds - expected) > 0.8
        origin = current
        // Rebase to the nearest equivalent turn on seeking/song changes, avoiding a long rewind.
        correction = Self.shortestTurn(from: current, to: target)
        sampledAt = time
        sampledSeconds = seconds
        headroom = remaining.isFinite ? max(0, remaining) : 0
        advancing = running
        settlingDuration = jumped ? 0.62 : 0.18
    }

    func angle(at time: Double) -> Double {
        guard initialized, time.isFinite else { return origin }
        let elapsed = max(0, time - sampledAt)
        let progress = min(1, elapsed / settlingDuration)
        let eased = 1 - pow(1 - progress, 3)
        // At most 400 ms of visual prediction bridges the 250 ms audio samples. A stalled
        // snapshot cannot leave a wheel spinning, and no phase advances beyond the track end.
        let prediction = advancing ? min(elapsed, 0.4, headroom) * rate : 0
        return origin + correction * eased + prediction
    }

    static func shortestTurn(from: Double, to: Double) -> Double {
        guard from.isFinite, to.isFinite else { return 0 }
        var difference = (to - from).truncatingRemainder(dividingBy: 360)
        if difference > 180 { difference -= 360 }
        if difference < -180 { difference += 360 }
        return difference
    }

    static func detent(from offset: Double, drag: Double, predicted: Double, reducedMotion: Bool) -> Double {
        guard offset.isFinite, drag.isFinite else { return 0 }
        let extra = predicted.isFinite && !reducedMotion ? min(36, max(-36, predicted - drag)) * 0.45 : 0
        return ((offset + drag + extra) / 6).rounded() * 6
    }
}

enum MechanicalDigitMotion {
    /// `phase` is an unwrapped count of digit steps; seconds tens use radix 6 for 59 -> 00.
    static func target(from phase: Double, digit: Int, radix: Int, increasing: Bool, jump: Bool) -> Double {
        guard phase.isFinite, radix >= 2 else { return 0 }
        let base = Double(radix)
        let bounded = min(radix - 1, max(0, digit))
        let current = (phase.truncatingRemainder(dividingBy: base) + base).truncatingRemainder(dividingBy: base)
        var distance = Double(bounded) - current
        if jump {
            if distance > base / 2 { distance -= base }
            if distance < -base / 2 { distance += base }
        } else if increasing && distance < 0 {
            distance += base
        } else if !increasing && distance > 0 {
            distance -= base
        }
        return phase + distance
    }
}
