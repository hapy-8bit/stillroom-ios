import CoreGraphics
import Foundation

enum OneTapeOpeningStage: String, Equatable, Sendable {
    /// Factory anti-static frosted sleeve covers the live player with a closed
    /// horizontal zipper ready to slide left/right or tap to unzip.
    case sealed
    /// User is actively sliding the horizontal zipper left or right.
    case tearing
    /// Zipper reached the end; slider detaches and top/bottom frosted flaps
    /// glide apart to reveal the live player.
    case peeling
    /// Unwrapping complete; overlay removed and player owns interaction.
    case finished

    var caption: String {
        switch self {
        case .sealed: return "滑动拉链拆封，或轻点拆封拉环"
        case .tearing: return "正在拉开封袋拉链"
        case .peeling: return "正在揭开防静电保护膜"
        case .finished: return "播放器"
        }
    }
}

/// Visual unboxing state machine only. No transition requests music playback or
/// modifies authoritative media time.
struct OneTapeOpeningJourney: Equatable, Sendable {
    private(set) var stage: OneTapeOpeningStage = .sealed

    @discardableResult
    mutating func beginTearing() -> Bool {
        guard stage == .sealed else { return false }
        stage = .tearing
        return true
    }

    @discardableResult
    mutating func commitPeel() -> Bool {
        guard stage == .sealed || stage == .tearing else { return false }
        stage = .peeling
        return true
    }

    @discardableResult
    mutating func pauseTearing() -> Bool {
        guard stage == .tearing else { return false }
        stage = .sealed
        return true
    }

    mutating func finish() { stage = .finished }
    mutating func reset() { stage = .sealed }
}

enum OneTapeOpeningTiming {
    static let zipFinishMax = 0.42
    static let zipFinishMin = 0.14
    static let stripFlyOff = 0.22
    static let peelDelay = 0.08
    static let sleevePeel = 0.68
    static let settle = 0.08
    static let reducedFade = 0.22
}

/// Timing constants (seconds) for the automatic Braun-inspired mini deck
/// launch splash that transitions directly into the main player.
enum OneTapeSplashTiming {
    static let entrance = 0.28
    static let pressDelay = 0.34
    static let spinDuration = 1.18
    static let dissolveDuration = 0.42
    static let reducedHold = 0.42
    static let reducedFade = 0.24
}

/// Presentation pose for the real player sitting beneath the frosted factory
/// sleeve. The player remains live and intact underneath, breathing subtly
/// into focus as the sleeve peels away.
struct OneTapeOpeningPlayerPose: Equatable, Sendable {
    var peelProgress: CGFloat = 1
    var bodyReveal: Double = 1
    var reducedMotion = false

    var deckScale: CGFloat {
        guard !reducedMotion else { return 1 }
        let t = min(1, max(0, peelProgress))
        return 0.976 + 0.024 * t
    }
}

/// Pure bidirectional zipper rules and tooth detent stepping (logical points).
enum OneTapeOpeningTearRules {
    static let commitProgress: CGFloat = 0.72
    static let flickMinProgress: CGFloat = 0.28
    static let flickVelocityRatio: CGFloat = 0.42
    static let perforationSteps: Int = 18

    /// Computes bidirectional zipper progress (`0...1`) so sliding right opens
    /// the top/bottom sleeve flaps and sliding left smoothly zips them back shut.
    static func progress(
        baseProgress: CGFloat,
        translationX: CGFloat,
        trackWidth: CGFloat
    ) -> CGFloat {
        guard baseProgress.isFinite, translationX.isFinite,
              trackWidth.isFinite, trackWidth > 0 else {
            return min(1, max(0, baseProgress.isFinite ? baseProgress : 0))
        }
        let base = min(1, max(0, baseProgress))
        let delta = translationX / trackWidth
        return min(1, max(0, base + delta))
    }

    /// True once the zipper is pulled far enough right or briskly flicked right.
    static func shouldCommit(
        progress: CGFloat,
        predictedTranslationX: CGFloat,
        trackWidth: CGFloat
    ) -> Bool {
        guard progress.isFinite, predictedTranslationX.isFinite,
              trackWidth.isFinite, trackWidth > 0 else { return false }
        if progress >= commitProgress { return true }
        return progress >= flickMinProgress && predictedTranslationX >= trackWidth * flickVelocityRatio
    }

    /// Discrete zipper tooth index (`0...perforationSteps`) for micro-haptics.
    static func detentIndex(for progress: CGFloat) -> Int {
        guard progress.isFinite else { return 0 }
        let clamped = min(1, max(0, progress))
        return Int((clamped * CGFloat(perforationSteps)).rounded(.down))
    }
}
