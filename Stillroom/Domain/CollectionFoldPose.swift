import Foundation

struct CollectionFoldPose {
    let progress: Double
    /// The two horizontal paper faces rotate from edge-on (90 degrees) to flat (0 degrees).
    var angle: Double { acos(progress) * 180 / .pi }

    init(_ progress: Double) { self.progress = progress.isFinite ? min(1, max(0, progress)) : 0 }

    func projectedHeight(_ faceHeight: Double) -> Double {
        guard faceHeight.isFinite else { return 0 }
        return max(0, faceHeight) * progress
    }

    static func dragged(base: Double, translation: Double, travel: Double) -> Double {
        guard translation.isFinite, travel.isFinite, travel > 0 else { return Self(base).progress }
        return Self(base + translation / travel).progress
    }

    static func settled(base: Double, translation: Double, predicted: Double, travel: Double) -> Double {
        // A projected release accounts for a deliberate flick, but a tiny movement never flips the state.
        guard translation.isFinite, abs(translation) > 8 else { return Self(base).progress >= 0.5 ? 1 : 0 }
        return dragged(base: base, translation: predicted.isFinite ? predicted : translation, travel: travel) >= 0.5 ? 1 : 0
    }
}
