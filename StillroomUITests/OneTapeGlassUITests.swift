import XCTest

final class OneTapeGlassUITests: XCTestCase {
    @MainActor
    func testSwipeCoverDoesNotTriggerMenuAndControlsRemainUsable() {
        let app = launch(reset: true)
        let glass = app.buttons["tape.glass"]
        expect(glass, state: "已打开")
        screenshot("01-glass-open")
        swipe(glass, upward: true)
        expect(glass, state: "已关闭")
        XCTAssertFalse(app.buttons["nav.library"].exists)
        screenshot("02-glass-closed")

        glass.tap()
        XCTAssertTrue(app.buttons["nav.library"].waitForExistence(timeout: 3))
        expect(glass, state: "已关闭")
        glass.tap()
        XCTAssertFalse(app.buttons["nav.library"].exists)
        app.buttons["tape.play"].tap()
        XCTAssertEqual(app.buttons["tape.play"].label, "播放")
        app.buttons["tape.lcd"].tap()
        XCTAssertTrue(app.buttons["studio.close"].waitForExistence(timeout: 4))
        app.buttons["studio.close"].tap()
        expect(glass, state: "已关闭")

        swipe(glass, upward: false)
        expect(glass, state: "已打开")
        XCTAssertFalse(app.buttons["nav.library"].exists)
        screenshot("03-glass-reopened")
    }

    @MainActor
    func testCommittedCoverSurvivesRelaunchAndReopensByGesture() {
        let app = launch(reset: true)
        let glass = app.buttons["tape.glass"]
        expect(glass, state: "已打开")
        swipe(glass, upward: true)
        expect(glass, state: "已关闭")
        app.terminate()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        app.launch()
        expect(glass, state: "已关闭")

        glass.tap()
        app.buttons["nav.customize"].tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 4))
        Thread.sleep(forTimeInterval: 0.45)
        app.buttons["customization.tab.print"].tap()
        XCTAssertTrue(app.segmentedControls["customization.glass"].exists)
        XCTAssertTrue(app.segmentedControls["customization.brandPrint"].exists)
        app.buttons["customization.tab.tape"].tap()
        app.buttons["customization.tape.graphite"].tap()
        app.buttons["customization.close"].tap()
        expect(glass, state: "已关闭")
        XCTAssertTrue((glass.value as? String ?? "").contains("黑色"))
        swipe(glass, upward: false)
        expect(glass, state: "已打开")
        screenshot("04-graphite-glass-reopened-by-gesture")
        app.terminate()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        app.launch()
        expect(glass, state: "已打开")
        XCTAssertTrue((glass.value as? String ?? "").contains("黑色"))
        screenshot("05-graphite-glass-open")
        swipe(glass, upward: true)
        expect(glass, state: "已关闭")
        screenshot("06-graphite-glass-closed")
    }

    @MainActor
    private func launch(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        if reset { app.launchArguments.append("--reset-one-tape-appearance-fixture") }
        app.launch()
        return app
    }

    @MainActor
    private func swipe(_ glass: XCUIElement, upward: Bool) {
        let lower = glass.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        let upper = glass.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        let start = upward ? lower : upper
        let end = upward ? upper : lower
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    @MainActor
    private func expect(_ glass: XCUIElement, state: String) {
        XCTAssertTrue(glass.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", state), evaluatedWith: glass)
        waitForExpectations(timeout: 4)
    }

    @MainActor
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
