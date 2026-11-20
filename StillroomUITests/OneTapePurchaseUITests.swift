import XCTest

/// These entry-point checks never confirm a payment or authenticate an account.
final class OneTapePurchaseUITests: XCTestCase {
    @MainActor
    func testStudioHasPurchaseAndSettingsHasRestore() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        app.launch()
        let glass = app.buttons.matching(identifier: "tape.glass").firstMatch
        XCTAssertTrue(glass.waitForExistence(timeout: 10))
        glass.tap()
        app.buttons.matching(identifier: "nav.settings").firstMatch.tap()
        let restore = app.buttons.matching(identifier: "settings.restorePurchases").firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 10))
        for _ in 0..<10 where restore.exists && !restore.isHittable { app.swipeUp() }
        XCTAssertTrue(restore.exists, "Settings must offer real restore purchases.")
        XCTAssertTrue(restore.isEnabled)
        screenshot("pro-settings-restore-entry")
        let studio = app.buttons.matching(identifier: "settings.studio").firstMatch
        for _ in 0..<12 where !studio.isHittable { app.swipeUp() }
        XCTAssertTrue(studio.isHittable)
        studio.tap()
        let purchase = app.buttons.matching(identifier: "studio.purchase").firstMatch
        for _ in 0..<6 where !purchase.isHittable { app.swipeUp() }
        XCTAssertTrue(purchase.exists, "The paywall must offer the configured App Store product.")
        XCTAssertTrue(app.staticTexts["One Vinyl Pro"].exists)
        XCTAssertFalse(app.buttons.matching(identifier: "studio.restorePurchases").firstMatch.exists)
        screenshot("pro-paywall-entrypoints")
    }

    @MainActor
    private func screenshot(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
