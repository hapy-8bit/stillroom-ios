import XCTest

extension XCTestCase {
    @MainActor func quietRecord(_ app: XCUIApplication) -> XCUIElement {
        let record = app.buttons["player.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 8))
        return record
    }

    @MainActor func dismissQuietRecord(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.78))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.95))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: app.tabBars.buttons["听音"])
        waitForExpectations(timeout: 8)
    }

    @MainActor func skipQuietRecord(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.66, dy: 0.73))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.73))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    @MainActor func browseNextAlbum(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.33))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.24, dy: 0.33))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    @MainActor func recordMenu(_ app: XCUIApplication, item: String) -> XCUIElement {
        quietRecord(app).press(forDuration: 0.8)
        let button = app.buttons[item]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        return button
    }

    @MainActor func sceneScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
