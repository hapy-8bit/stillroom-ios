import Foundation

/// Completion lives independently of the music library and appearance record.
final class OneTapeOpeningPreferences {
    static let completionKey = "oneTape.opening.completed.v1"
    private let defaults: UserDefaults
    let shouldPresent: Bool

    init(defaults: UserDefaults = .standard, force: Bool = false, suppressed: Bool = false) {
        self.defaults = defaults
        shouldPresent = !suppressed && (force || !defaults.bool(forKey: Self.completionKey))
    }

    func complete() { defaults.set(true, forKey: Self.completionKey) }

    static func applicationPreferences() -> OneTapeOpeningPreferences {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--one-tape-opening-fixture"),
           let defaults = UserDefaults(suiteName: "OneTapeOpeningUITests") {
            if arguments.contains("--reset-one-tape-opening-fixture") {
                // Reset only the explicitly disposable opening flag, never user data.
                defaults.removeObject(forKey: completionKey)
            }
            return OneTapeOpeningPreferences(defaults: defaults)
        }
        let fixture = arguments.contains("--one-tape-empty") ||
            arguments.contains("--one-tape-appearance-fixture")
        return OneTapeOpeningPreferences(suppressed: fixture)
    }
}
