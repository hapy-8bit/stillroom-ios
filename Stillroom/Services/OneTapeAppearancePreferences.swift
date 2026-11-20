import Foundation

/// A separate small preference record. It never reads or migrates music indices.
final class OneTapeAppearancePreferences {
    private let defaults: UserDefaults
    private let key = "oneTape.appearance.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> OneTapeAppearance {
        guard let data = defaults.data(forKey: key) else { return OneTapeAppearance() }
        return try JSONDecoder().decode(OneTapeAppearance.self, from: data)
    }

    func save(_ appearance: OneTapeAppearance) throws {
        // Preserve an unreadable record instead of silently replacing it with
        // defaults. The coordinator can still offer a visible session preview.
        _ = try load()
        defaults.set(try JSONEncoder().encode(appearance), forKey: key)
    }

    static func applicationPreferences() -> OneTapeAppearancePreferences {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--one-tape-appearance-fixture"),
              let defaults = UserDefaults(suiteName: "OneTapeAppearanceUITests") else {
            return OneTapeAppearancePreferences()
        }
        if arguments.contains("--reset-one-tape-appearance-fixture") {
            // Only an explicitly named UI-test preference is disposable. The
            // normal app's appearance and all music data are left untouched.
            defaults.removeObject(forKey: "oneTape.appearance.v1")
        }
        return OneTapeAppearancePreferences(defaults: defaults)
    }
}
