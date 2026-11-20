import Foundation

/// This preview has its own completion key; it never resets library or older appearance data.
final class RecordOpeningPreferences {
    static let completionKey = "recordOpening.completed.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var shouldPresent: Bool {
        ProcessInfo.processInfo.arguments.contains("--record-opening-preview") ||
            !defaults.bool(forKey: Self.completionKey)
    }

    func complete() {
        defaults.set(true, forKey: Self.completionKey)
    }
}
