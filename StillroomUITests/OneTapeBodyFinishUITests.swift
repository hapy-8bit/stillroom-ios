import XCTest

final class OneTapeBodyFinishUITests: XCTestCase {
    @MainActor
    func testBodyMaterialsAndPaletteApplyAcrossTheWholePlayer() {
        continueAfterFailure = false
        let app = XCUIApplication()
        // The isolated appearance suite leaves the user's saved finish and
        // library intact. This single session never starts audio playback.
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture",
                               "--reset-one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.glass"].waitForExistence(timeout: 10))
        let finishes = [("black", "black"), ("graphite", "black"),
                        ("adaptive", "black"), ("cover", "black")]
            + ["navy", "green", "slate", "dove", "cognac", "white", "garden"].map { ("black", $0) }
        for (style, color) in finishes {
            if !app.buttons["nav.customize"].exists { app.buttons["tape.glass"].tap() }
            tap(app.buttons["nav.customize"])
            tap(app.buttons["customization.tab.body"])
            tap(app.buttons["customization.body.\(style)"])
            let choice = app.buttons["customization.bodyColor.\(color)"]
            let palette = app.scrollViews["customization.bodyColors"]
            if !choice.isHittable { palette.swipeLeft() }
            tap(choice)
            XCTAssertEqual(choice.value as? String, "已选择")
            tap(app.buttons["customization.close"])
            if app.buttons["nav.customize"].exists { app.buttons["tape.glass"].tap() }
            wait("The HUD closes before inspecting the full border") { !app.buttons["nav.customize"].exists }
            Thread.sleep(forTimeInterval: 0.5)
            for key in ["tape.previous", "tape.play", "tape.next", "tape.lcd"] {
                XCTAssertTrue(app.buttons[key].isHittable)
            }
            XCTAssertEqual(app.buttons["tape.play"].label, "播放")
            let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            image.name = "body-finish-\(style)-\(color)"
            image.lifetime = .keepAlways
            add(image)
        }
    }

    @MainActor
    private func tap(_ element: XCUIElement) {
        wait("The customization control is reachable") { element.exists && element.isHittable }
        element.tap()
    }

    @MainActor
    private func wait(_ description: String, condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed, description)
    }
}
