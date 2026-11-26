import XCTest

final class OneTapeOpeningUITests: XCTestCase {
    @MainActor
    func testTearStripUnwrapColdLaunchAndSettingsReplay() {
        continueAfterFailure = false
        let app = launchOpening(reset: true)
        XCTAssertTrue(app.buttons["opening.tearTab"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["tape.play"].isHittable)
        screenshot("opening-01-sealed-sleeve")

        let left = app.coordinate(withNormalizedOffset: CGVector(dx: 0.14, dy: 0.24))
        let right = app.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.24))
        left.press(forDuration: 0.1, thenDragTo: right)
        assertPlayer(app)
        screenshot("opening-02-unwrapped-player")

        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-one-tape-opening-fixture" }
        app.launch()
        assertPlayer(app)
        XCTAssertFalse(app.buttons["opening.tearTab"].exists)

        app.buttons["tape.glass"].tap()
        XCTAssertTrue(app.buttons["nav.settings"].waitForExistence(timeout: 8))
        app.buttons["nav.settings"].tap()
        let replay = app.buttons["settings.opening"]
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        XCTAssertTrue(replay.isHittable)
        XCTAssertEqual(replay.label, "重新演示开屏动画")
        screenshot("opening-settings-first-screen")

        replay.tap()
        XCTAssertTrue(app.buttons["opening.tearTab"].waitForExistence(timeout: 8))
        screenshot("opening-03-replay-sealed")
        app.buttons["opening.tearTab"].tap()
        assertPlayer(app)
        screenshot("opening-04-replay-entered")
    }

    @MainActor
    func testSkipOpensPlayerAndPersistsOnlyTheFixtureCompletion() {
        continueAfterFailure = false
        let app = launchOpening(reset: true)
        XCTAssertTrue(app.buttons["opening.skip"].waitForExistence(timeout: 10))
        app.buttons["opening.skip"].tap()
        assertPlayer(app)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-one-tape-opening-fixture" }
        app.launch()
        assertPlayer(app)
        screenshot("opening-05-skipped-cold-launch")
    }

    @MainActor
    func testZNormalLaunchShowsItsActualSavedDestinationWithoutCompletingOpening() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = []
        app.launch()
        let opening = app.buttons["opening.tearTab"]
        let player = app.buttons["tape.play"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (opening.exists && opening.isHittable) || (player.exists && player.isHittable)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed)
        if opening.exists { XCTAssertTrue(app.buttons["opening.skip"].isHittable) }
        screenshot("opening-06-normal-launch")
    }

    @MainActor
    private func launchOpening(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-opening-fixture", "--one-tape-empty", "--one-tape-appearance-fixture"]
        if reset { app.launchArguments.append("--reset-one-tape-opening-fixture") }
        app.launch()
        return app
    }

    @MainActor
    private func assertPlayer(_ app: XCUIApplication) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.buttons["tape.play"].exists && app.buttons["tape.play"].isHittable
                && !app.buttons["opening.tearTab"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed, app.debugDescription)
        XCTAssertEqual(app.buttons["tape.play"].label, "播放")
        XCTAssertEqual(app.buttons["tape.lcd"].label, "当前播放，还没有磁带")
    }

    @MainActor
    private func screenshot(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
