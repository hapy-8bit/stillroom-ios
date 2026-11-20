import Foundation

enum OneTapeGlassMotion {
    static let minimumDragDistance: CGFloat = 8

    struct Resolution: Equatable {
        /// Stable positions are 0 (closed) and 1 (open). A live drag may exceed
        /// that range by one sixth of the excess, matching the reference drag.
        let progress: CGFloat
        let targetIsOpen: Bool

        var clampedProgress: CGFloat { min(1, max(0, progress)) }
    }

    /// Translation and height are both local canvas points. The face applies
    /// its window scale outside the control; dividing by that scale again would
    /// make the gesture travel depend on the device size.
    static func resolve(
        isOpen: Bool,
        translationY: CGFloat,
        predictedTranslationY: CGFloat? = nil,
        height: CGFloat
    ) -> Resolution {
        let resting: CGFloat = isOpen ? 1 : 0
        let stable = Resolution(progress: resting, targetIsOpen: isOpen)
        let predicted = predictedTranslationY ?? translationY
        guard height.isFinite, height > 0,
              translationY.isFinite, predicted.isFinite else { return stable }

        let raw = resting + translationY / height
        let projected = resting + predicted / height
        guard raw.isFinite, projected.isFinite else { return stable }

        let progress: CGFloat
        if raw < 0 {
            progress = raw / 6
        } else if raw > 1 {
            progress = 1 + (raw - 1) / 6
        } else {
            progress = raw
        }
        return Resolution(progress: progress, targetIsOpen: projected > 0.5)
    }
}
