import Foundation

struct ListeningPose {
    let dissolve: Double
    let artworkOpacity: Double
    let controller: Double
    let hintOpacity: Double

    init(progress: Double, reducedMotion: Bool = false) {
        let value = progress.isFinite ? min(1, max(0, progress)) : 0
        func ease(_ start: Double, _ end: Double) -> Double {
            let x = min(1, max(0, (value - start) / (end - start)))
            return x * x * (3 - 2 * x)
        }
        hintOpacity = 1 - ease(0, 0.2)
        // Reference motion overlaps the dispersing foreground and the incoming controls.
        // Every phase derives from one scroll coordinate so reversing never needs a second timeline.
        dissolve = reducedMotion ? 0 : ease(0, 0.92)
        artworkOpacity = 1 - (reducedMotion ? ease(0.12, 0.6) : ease(0.91, 1))
        controller = reducedMotion ? ease(0.38, 0.88) : ease(0.30, 1)
    }
}

