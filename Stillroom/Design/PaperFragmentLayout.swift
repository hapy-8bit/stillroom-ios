import Foundation

struct PaperFragment: Identifiable {
    let id: Int
    /// Source rect is normalized to the original artwork, not the screen or image pixels.
    let rect: CGRect
    let seed: Double
}

struct PaperFragmentPose: Equatable {
    let x: Double
    let y: Double
    let rotation: Double
    let fold: Double
    let shear: Double
    let opacity: Double
    let backside: Bool
}

enum PaperFragmentLayout {
    static let fragments: [PaperFragment] = {
        let xs: [Double] = [0, 0.15, 0.33, 0.49, 0.66, 0.83, 1]
        let ys: [Double] = [0, 0.23, 0.49, 0.74, 1]
        return (0..<24).map { id in
            let column = id % 6
            let row = id / 6
            return PaperFragment(id: id,
                                 rect: CGRect(x: xs[column], y: ys[row], width: xs[column + 1] - xs[column],
                                              height: ys[row + 1] - ys[row]),
                                 seed: random(id))
        }
    }()

    static func pose(for fragment: PaperFragment, progress: Double) -> PaperFragmentPose {
        let p = progress.isFinite ? min(1, max(0, progress)) : 0
        let seed = fragment.seed
        let delay = seed * 0.18
        let flight = ease(p, from: 0.035 + delay, to: 0.84 + delay * 0.5)
        let flutter = sin(flight * (5.5 + seed * 3)) * flight
        let foldAngle = flight * (2.4 + random(fragment.id + 31) * 2.3)
        let fold = cos(foldAngle)
        return PaperFragmentPose(
            x: (seed - 0.5) * flight * 0.95 + flutter * 0.055,
            y: -(0.18 + random(fragment.id + 67) * 0.85) * flight + flutter * 0.09,
            rotation: ((seed - 0.5) * 2.8 * flight + flutter * 0.24),
            fold: max(0.065, abs(fold)),
            shear: sin(foldAngle) * 0.20,
            opacity: 1 - ease(p, from: 0.63 + delay * 0.5, to: 1),
            backside: fold < 0)
    }

    /// Heights run from the tile's top (0) to its bottom (1). A value above 1 removes the last edge.
    /// Fixed spatial noise keeps the erosion attached to the paper and retraces it on a reverse drag.
    static func burnBoundary(for fragment: PaperFragment, progress: Double) -> [Double] {
        let p = progress.isFinite ? min(1, max(0, progress)) : 0
        let burn = ease(p, from: 0.18 + fragment.seed * 0.1, to: 0.98)
        return (0...16).map { column in
            let noise = random(fragment.id * 23 + column * 7 + 113) - 0.5
            let fine = random(fragment.id * 11 + column + 307) - 0.5
            return max(0, min(1.08, -0.10 + burn * 1.24 + (noise * 0.24 + fine * 0.1) * sin(burn * .pi)))
        }
    }

    private static func ease(_ value: Double, from start: Double, to end: Double) -> Double {
        let t = max(0, min(1, (value - start) / (end - start)))
        return t * t * (3 - 2 * t)
    }

    private static func random(_ index: Int) -> Double {
        let value = sin(Double(index + 1) * 127.1 + 311.7) * 43758.5453
        return value - floor(value)
    }
}
