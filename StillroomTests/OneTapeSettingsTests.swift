import XCTest
@testable import Stillroom

@MainActor
final class OneTapeSettingsTests: XCTestCase {
    func testScreenAwakePreferenceSurvivesColdStoreAndDefaultsToEnabled() throws {
        let suite = "OneTape.behavior." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let appearance = OneTapeAppearancePreferences(defaults: defaults)
        let first = OneTapeStore(appearancePreferences: appearance, behaviorDefaults: defaults)
        XCTAssertTrue(first.keepAwake)
        first.keepAwake = false
        let reopened = OneTapeStore(appearancePreferences: appearance, behaviorDefaults: defaults)
        XCTAssertFalse(reopened.keepAwake)
        reopened.keepAwake = true
        XCTAssertTrue(OneTapeStore(appearancePreferences: appearance, behaviorDefaults: defaults).keepAwake)
    }
}
