import Foundation

struct AlbumCoverPose {
    let scale: Double
    let rotation: Double
    let vertical: Double
    let opacity: Double

    init(distance: Double) {
        let value = distance.isFinite ? distance : 0
        scale = max(0.7, 1 - abs(value) * 0.17)
        rotation = min(48, max(-48, -value * 34))
        vertical = min(38, abs(value) * 17)
        opacity = max(0, min(1, 2.6 - abs(value)))
    }
}

enum AlbumFlowMotion {
    static func destination(index: Int, count: Int, translation: Double, predicted: Double, stride: Double) -> Int {
        guard count > 0 else { return 0 }
        let current = min(count - 1, max(0, index))
        guard stride.isFinite, stride > 0, translation.isFinite, abs(translation) > 8 else { return current }
        let distance = predicted.isFinite ? predicted : translation
        // Limit one release to two albums. A fast flick cannot leap across an entire private library.
        let steps = Int(min(2, max(-2, (distance / stride).rounded())))
        return min(count - 1, max(0, current - steps))
    }

    static func drag(_ translation: Double, index: Int, count: Int) -> Double {
        guard translation.isFinite, count > 0 else { return 0 }
        let outside = (index <= 0 && translation > 0) || (index >= count - 1 && translation < 0)
        return translation * (outside ? 0.24 : 1)
    }
}

enum QuietPlayerGesture: Equatable {
    case none, dismiss, next, previous

    static func resolve(x: Double, y: Double, predictedY: Double, width: Double,
                        height: Double, startsOnArm: Bool) -> Self {
        guard !startsOnArm, x.isFinite, y.isFinite, width.isFinite, height.isFinite else { return .none }
        let horizontal = min(90, max(50, width * 0.16))
        let vertical = min(110, max(60, height * 0.09))
        if abs(x) > horizontal && abs(x) > abs(y) * 1.25 { return x < 0 ? .next : .previous }
        let projected = predictedY.isFinite ? predictedY : y
        if y > 28 && y > abs(x) * 1.25 && max(y, projected) > vertical { return .dismiss }
        return .none
    }
}
