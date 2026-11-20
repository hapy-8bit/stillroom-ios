import XCTest

final class OneTapeOpeningUITests: XCTestCase {
    @MainActor
    func testTwoGesturesInspectionColdLaunchAndSettingsReplay() {
        continueAfterFailure = false
        let app = launchOpening(reset: true)
        XCTAssertTrue(app.buttons["opening.openCase"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["opening.case"].value as? String, "已关闭")
        XCTAssertFalse(app.buttons["opening.insert"].exists)
        XCTAssertFalse(app.buttons["tape.play"].isHittable)
        screenshot("opening-01-closed-box")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -140)))
        XCTAssertTrue(app.buttons["opening.insert"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["opening.case"].exists)
        XCTAssertFalse(app.buttons["tape.play"].isHittable)
        screenshot("opening-02-inspecting-tape")
        let tape = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.43))
        tape.press(forDuration: 0.15, thenDragTo: tape.withOffset(CGVector(dx: 75, dy: 0)))
        XCTAssertTrue(app.buttons["opening.insert"].isHittable, "Viewing a tape must not enter the player.")
        screenshot("opening-03-after-turning")
        let right = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.45))
        let left = app.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.45))
        right.press(forDuration: 0.1, thenDragTo: left)
        assertPlayer(app)
        screenshot("opening-04-left-swipe-entered")

        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-one-tape-opening-fixture" }
        app.launch()
        assertPlayer(app)
        XCTAssertFalse(app.buttons["opening.openCase"].exists)
        app.buttons["tape.glass"].tap()
        XCTAssertTrue(app.buttons["nav.settings"].waitForExistence(timeout: 8))
        app.buttons["nav.settings"].tap()
        let replay = app.buttons["settings.opening"]
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        XCTAssertTrue(replay.isHittable)
        XCTAssertEqual(replay.label, "重新演示开屏动画")
        screenshot("opening-settings-first-screen")
        replay.tap()
        XCTAssertTrue(app.buttons["opening.openCase"].waitForExistence(timeout: 8))
        screenshot("opening-05-replay-closed")
        // Accessible buttons provide the same two separate actions as gestures.
        app.buttons["opening.openCase"].tap()
        XCTAssertTrue(app.buttons["opening.insert"].waitForExistence(timeout: 8))
        app.buttons["opening.insert"].tap()
        assertPlayer(app)
        screenshot("opening-06-replay-entered")
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
        screenshot("opening-07-skipped-cold-launch")
    }

    @MainActor
    func testZNormalLaunchShowsItsActualSavedDestinationWithoutCompletingOpening() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = []
        app.launch()
        let opening = app.buttons["opening.openCase"]
        let player = app.buttons["tape.play"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (opening.exists && opening.isHittable) || (player.exists && player.isHittable)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed)
        if opening.exists { XCTAssertTrue(app.buttons["opening.skip"].isHittable) }
        screenshot("opening-08-normal-launch")
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
                && !app.buttons["opening.openCase"].exists && !app.buttons["opening.insert"].exists
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
