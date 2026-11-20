import Foundation

/// Pack radii use the reference portrait material's logical points. The progress
/// input is One Tape's whole selected queue, not a claim about the source clock.
enum OneTapeTapeGeometry {
    static func radii(progress: Double) -> (supply: Double, takeup: Double) {
        let p = progress.isFinite ? min(1, max(0, progress)) : 0
        return (sqrt(11693.827044 - 8246.7281 * p), sqrt(3447.098944 + 8246.7281 * p))
    }

    static func progress(queueIDs: [String], tracks: [Track], currentID: String?, position: Double) -> Double {
        guard let currentID, let index = queueIDs.firstIndex(of: currentID) else { return 0 }
        let lookup = Dictionary(tracks.map { ($0.id, $0.duration) }, uniquingKeysWith: { _, last in last })
        let durations = queueIDs.map { id in
            let duration = lookup[id] ?? 0
            return duration.isFinite ? max(0, duration) : 0
        }
        let total = durations.reduce(0, +)
        guard total.isFinite, total > 0 else { return 0 }
        let position = position.isFinite ? min(durations[index], max(0, position)) : 0
        return min(1, max(0, (durations.prefix(index).reduce(0, +) + position) / total))
    }
}
