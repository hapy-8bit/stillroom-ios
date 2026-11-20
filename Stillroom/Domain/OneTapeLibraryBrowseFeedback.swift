import Foundation

enum OneTapeLibraryBrowseEvent: Equatable {
    case began(currentID: String?)
    case crossed(String)
    case ended
}

/// Only user-driven spine crossings create detents. Mounting, restoration,
/// artwork refresh and programmatic scrolling never manufacture feedback.
struct OneTapeLibraryBrowseFeedbackPolicy {
    private var isBrowsing = false
    private var centeredID: String?
    private var lastPulse: TimeInterval?
    private let minimumInterval: TimeInterval = 0.07

    mutating func handle(_ event: OneTapeLibraryBrowseEvent,
                         now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        switch event {
        case .began(let currentID):
            isBrowsing = true
            centeredID = currentID
            lastPulse = nil
            return false
        case .crossed(let id):
            let previous = centeredID
            centeredID = id
            guard isBrowsing, let previous, previous != id, now.isFinite else { return false }
            guard lastPulse.map({ now - $0 >= minimumInterval }) ?? true else { return false }
            lastPulse = now
            return true
        case .ended:
            isBrowsing = false
            centeredID = nil
            lastPulse = nil
            return false
        }
    }
}
