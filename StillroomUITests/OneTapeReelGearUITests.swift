import XCTest

final class OneTapeReelGearUITests: XCTestCase {
    @MainActor
    func testReelGearTabAndColorSwatchesRenderAndApplyToPlayer() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture",
                               "--reset-one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.glass"].waitForExistence(timeout: 10))

        if !app.buttons["nav.customize"].exists {
            app.buttons["tape.glass"].tap()
        }
        tap(app.buttons["nav.customize"])

        let reelTab = app.buttons["customization.tab.reel"]
        tap(reelTab)
        XCTAssertEqual(reelTab.value as? String, "已选择")

        for rawColor in ["white", "black", "orange", "crimson", "blue"] {
            XCTAssertTrue(app.buttons["customization.reelColor.\(rawColor)"].waitForExistence(timeout: 3))
        }

        let crimson = app.buttons["customization.reelColor.crimson"]
        tap(crimson)
        XCTAssertEqual(crimson.value as? String, "已选择")

        let sheetAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        sheetAttachment.name = "reel-gear-sheet-crimson"
        sheetAttachment.lifetime = .keepAlways
        add(sheetAttachment)

        let blue = app.buttons["customization.reelColor.blue"]
        tap(blue)
        XCTAssertEqual(blue.value as? String, "已选择")

        tap(app.buttons["customization.close"])
        if app.buttons["nav.customize"].exists {
            app.buttons["tape.glass"].tap()
        }
        Thread.sleep(forTimeInterval: 0.4)

        let playerAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        playerAttachment.name = "reel-gear-player-blue"
        playerAttachment.lifetime = .keepAlways
        add(playerAttachment)
    }

    @MainActor
    private func tap(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in element.exists && element.isHittable },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
        element.tap()
    }
}
