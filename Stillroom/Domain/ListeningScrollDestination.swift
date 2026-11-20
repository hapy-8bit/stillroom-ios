import Foundation

enum ListeningScrollDestination {
    /// Coordinates are logical points in the parent scroll view. A gesture starting inside
    /// the transition lands on an endpoint; subsequent gestures freely browse the home.
    static func resolve(proposed: Double, origin: Double, travel: Double) -> Double {
        guard proposed.isFinite, origin.isFinite, travel.isFinite, travel > 0 else { return 0 }
        let target = max(0, proposed)
        if origin < travel - 1 || target < travel {
            return target >= travel * 0.5 ? travel : 0
        }
        return target
    }
}
