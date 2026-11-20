import CoreGraphics
import Foundation

enum OneTapeOpeningStage: String {
    case waiting, unboxing, inspecting, rotating, inserting, revealing, finished

    var caption: String {
        switch self {
        case .waiting: return "向上滑动打开磁带盒"
        case .unboxing: return "正在开盒"
        case .inspecting: return "左右轻拖转动，向左滑入仓"
        case .rotating: return "正在转正"
        case .inserting: return "正在进入播放器"
        case .revealing, .finished: return "播放器"
        }
    }
}

/// A visual journey only. No transition requests music playback or changes media time.
struct OneTapeOpeningJourney {
    private(set) var stage: OneTapeOpeningStage = .waiting

    @discardableResult mutating func openCase() -> Bool {
        guard stage == .waiting else { return false }
        stage = .unboxing
        return true
    }

    @discardableResult mutating func insert() -> Bool {
        guard stage == .inspecting else { return false }
        stage = .rotating
        return true
    }

    @discardableResult mutating func advance() -> Bool {
        switch stage {
        case .unboxing: stage = .inspecting
        case .rotating: stage = .inserting
        case .inserting: stage = .revealing
        case .revealing: stage = .finished
        case .waiting, .inspecting, .finished: return false
        }
        return true
    }

    mutating func finish() { stage = .finished }
    mutating func reset() { stage = .waiting }
}

enum OneTapeOpeningTiming {
    static let unbox = 1.40
    static let turn = 0.72
    static let approachDelay = 0.40
    static let dock = 0.94
    static let reveal = 0.12
}

/// Presentation values for the player's existing cassette layer. Its visual
/// clock, materials and glass state remain the same throughout the opening.
struct OneTapeOpeningPlayerPose {
    var extraction: CGFloat = 1
    var turn: CGFloat = 1
    var approach: CGFloat = 1
    var yaw: Double = 0
    var opacity: Double = 1
    var bodyReveal: Double = 1
    var reducedMotion = false
}

enum OneTapeOpeningGesture {
    enum Action { case none, openCase, insert }

    /// Short horizontal drags inspect the tape. Only a committed left swipe
    /// enters the deck; vertical and rightward gestures never insert it.
    static func action(stage: OneTapeOpeningStage, translation: CGSize,
                       predicted: CGSize, width: CGFloat) -> Action {
        guard width.isFinite, width > 0, translation.width.isFinite,
              translation.height.isFinite, predicted.width.isFinite,
              predicted.height.isFinite else { return .none }
        switch stage {
        case .waiting:
            let up = -translation.height
            return up > abs(translation.width) * 1.2
                && (up > 55 || (up > 24 && predicted.height < -110)) ? .openCase : .none
        case .inspecting:
            let left = -translation.width
            return left > abs(translation.height) * 1.3
                && (left > max(100, width * 0.30)
                    || (left > 65 && predicted.width < -width * 0.65)) ? .insert : .none
        default: return .none
        }
    }

    static func yaw(translationX: CGFloat, width: CGFloat) -> Double {
        guard translationX.isFinite, width.isFinite, width > 0 else { return 0 }
        return Double(min(34, max(-34, translationX / width * 90)))
    }
}

/// All measurements are window-relative logical points. The destination uses
/// the same centered 393 × 852 canvas and cassette origin as PlayerFace.
struct OneTapeOpeningLayout {
    let size: CGSize
    var playerScale: CGFloat { max(0.01, min(size.width / 393, size.height / 852)) }
    var caseScale: CGFloat {
        max(0.01, min(size.width * 0.68 / 598, size.height * 0.23 / 392))
    }
    var boxedTapeScale: CGFloat { caseScale * 0.92 }
    var looseScale: CGFloat {
        max(0.01, min(size.width * 0.84 / 576,
                      size.height * (size.height < 700 ? 0.26 : 0.28) / 376.33))
    }
    var looseCenter: CGPoint {
        CGPoint(x: size.width / 2, y: size.height * (size.height < 700 ? 0.43 : 0.46))
    }
    var dockCenter: CGPoint {
        CGPoint(x: size.width / 2 - 0.005 * playerScale,
                y: size.height / 2 + (57.33 + 288 - 426) * playerScale)
    }

    func center(progress: CGFloat) -> CGPoint {
        let t = min(1, max(0, progress))
        return CGPoint(x: looseCenter.x + (dockCenter.x - looseCenter.x) * t,
                       y: looseCenter.y + (dockCenter.y - looseCenter.y) * t)
    }

    func scale(progress: CGFloat) -> CGFloat {
        looseScale + (playerScale - looseScale) * min(1, max(0, progress))
    }

    func cassetteScale(extraction: CGFloat, approach: CGFloat) -> CGFloat {
        let extracted = boxedTapeScale + (looseScale - boxedTapeScale) * min(1, max(0, extraction))
        return extracted + (playerScale - extracted) * min(1, max(0, approach))
    }
}
