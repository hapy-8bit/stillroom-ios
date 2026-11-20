import XCTest

final class OneTapeBronzeUITests: XCTestCase {
    @MainActor
    func testBronzePrintAndPhysicalCoverPersistWithoutStartingEmptyPlayback() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture",
                               "--reset-one-tape-appearance-fixture"]
        app.launch()
        let glass = app.buttons["tape.glass"]
        expect(glass, state: "已打开")
        openCustomization(app)
        app.buttons["customization.tab.tape"].tap()
        let bronze = app.buttons["customization.tape.bronze"]
        reveal(bronze, in: app)
        bronze.tap()
        XCTAssertEqual(bronze.value as? String, "已选择")
        screenshot("bronze-01-selected")
        closeCustomization(app)
        assertAppearance(glass, contains: ["古铜", "One Tape 印字"])
        assertEmptyPlayback(app)
        screenshot("bronze-02-brand-open")

        swipe(glass, upward: true)
        expect(glass, state: "已关闭")
        screenshot("bronze-03-brand-closed")
        swipe(glass, upward: false)
        expect(glass, state: "已打开")
        screenshot("bronze-04-brand-reopened")

        openCustomization(app)
        app.buttons["customization.tab.print"].tap()
        let wild = app.buttons["customization.doodle.wild"]
        reveal(wild, in: app)
        wild.tap()
        XCTAssertEqual(wild.value as? String, "已选择")
        closeCustomization(app)
        assertAppearance(glass, contains: ["古铜", "wild", "无品牌印字"])
        assertEmptyPlayback(app)
        // Retain an actual UI frame for visual inspection of the window/hole
        // mask. The summary alone cannot establish correct compositing.
        screenshot("bronze-05-wild-open-mask")
        swipe(glass, upward: true)
        expect(glass, state: "已关闭")
        screenshot("bronze-06-wild-closed")

        app.terminate()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        app.launch()
        expect(glass, state: "已关闭")
        assertAppearance(glass, contains: ["古铜", "wild", "无品牌印字"])
        assertEmptyPlayback(app)
        screenshot("bronze-07-cold-launch-restored")
        swipe(glass, upward: false)
        expect(glass, state: "已打开")
        screenshot("bronze-08-restored-open-mask")

        openCustomization(app)
        app.buttons["customization.tab.print"].tap()
        let noPrint = app.buttons["customization.doodle.none"]
        reveal(noPrint, in: app, towardTop: true)
        noPrint.tap()
        closeCustomization(app)
        assertAppearance(glass, contains: ["古铜", "One Tape 印字"])
        XCTAssertFalse((glass.value as? String ?? "").contains("wild"))
        screenshot("bronze-09-new-wordmark-restored")
    }

    @MainActor
    private func assertEmptyPlayback(_ app: XCUIApplication) {
        XCTAssertEqual(app.buttons["tape.lcd"].value as? String, "lcd")
        XCTAssertTrue(app.buttons["tape.lcd"].label.contains("还没有磁带"))
        app.buttons["tape.play"].tap()
        XCTAssertEqual(app.buttons["tape.play"].label, "播放")
        XCTAssertEqual(app.buttons["tape.lcd"].value as? String, "lcd")
    }

    @MainActor
    private func assertAppearance(_ glass: XCUIElement, contains parts: [String]) {
        for part in parts {
            XCTAssertTrue((glass.value as? String ?? "").contains(part), "Missing appearance: \(part)")
        }
    }

    @MainActor
    private func expect(_ glass: XCUIElement, state: String) {
        XCTAssertTrue(glass.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", state), evaluatedWith: glass)
        waitForExpectations(timeout: 4)
    }

    @MainActor
    private func openCustomization(_ app: XCUIApplication) {
        if !app.buttons["nav.customize"].exists { app.buttons["tape.glass"].tap() }
        XCTAssertTrue(app.buttons["nav.customize"].waitForExistence(timeout: 3))
        app.buttons["nav.customize"].tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 4))
        // AX publishes the drawer's destination before its visible move ends.
        Thread.sleep(forTimeInterval: 0.45)
    }

    @MainActor
    private func closeCustomization(_ app: XCUIApplication) {
        app.buttons["customization.close"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["customization.close"])
        waitForExpectations(timeout: 3)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false) {
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 3))
        for _ in 0..<8 {
            let top = max(scroll.frame.minY, app.buttons["customization.tab.tape"].frame.maxY) + 12
            let bottom = min(scroll.frame.maxY, app.buttons["nav.customize"].frame.minY) - 12
            guard bottom > top else { XCTFail("No visible customization scroll area"); return }
            let center = element.frame.midY
            if element.isHittable, center >= top, center <= bottom { return }
            let downward = element.exists ? center < top : towardTop
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: app.frame.width / 2,
                dy: (downward ? top + 8 : bottom - 8) - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: app.frame.width / 2,
                dy: (downward ? bottom - 8 : top + 8) - app.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func swipe(_ glass: XCUIElement, upward: Bool) {
        let lower = glass.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        let upper = glass.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        (upward ? lower : upper).press(forDuration: 0.1, thenDragTo: upward ? upper : lower)
    }

    @MainActor
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
