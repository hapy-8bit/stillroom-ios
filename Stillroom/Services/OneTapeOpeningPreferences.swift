import Foundation

/// Completion and launch-splash flags live independently of the music library
/// and appearance record.
final class OneTapeOpeningPreferences {
    static let completionKey = "oneTape.opening.completed.v1"
    static let splashEnabledKey = "oneTape.splash.enabled.v1"

    private let defaults: UserDefaults
    let shouldPresent: Bool
    let shouldPresentSplash: Bool

    var splashEnabled: Bool {
        get {
            if defaults.object(forKey: Self.splashEnabledKey) == nil { return true }
            return defaults.bool(forKey: Self.splashEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: Self.splashEnabledKey)
        }
    }

    init(
        defaults: UserDefaults = .standard,
        force: Bool = false,
        suppressed: Bool = false,
        suppressSplash: Bool? = nil
    ) {
        self.defaults = defaults
        shouldPresent = !suppressed && (force || !defaults.bool(forKey: Self.completionKey))
        let splashSuppressed = suppressSplash ?? suppressed
        let enabled = defaults.object(forKey: Self.splashEnabledKey) == nil
            ? true
            : defaults.bool(forKey: Self.splashEnabledKey)
        shouldPresentSplash = !splashSuppressed && enabled
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
            return OneTapeOpeningPreferences(defaults: defaults, suppressSplash: true)
        }
        let fixture = arguments.contains("--one-tape-empty") ||
            arguments.contains("--one-tape-appearance-fixture")
        return OneTapeOpeningPreferences(suppressed: fixture)
    }
}
