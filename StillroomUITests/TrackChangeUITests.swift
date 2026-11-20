import XCTest

final class TrackChangeUITests: XCTestCase {
    @MainActor
    func testRecordExchangeAndRapidRequestsKeepTheLatestTrack() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.record"].tap()
        let record = quietRecord(app)
        app.buttons["player.play"].tap()
        XCTAssertTrue(record.label.hasPrefix("播放"))
        sceneScreenshot("60-before-record-exchange")
        app.buttons["player.next"].tap()
        waitForTitle("窗边余响", app: app)
        XCTAssertTrue(record.label.hasPrefix("播放"), "A visual exchange must preserve pause")
        sceneScreenshot("61-after-record-exchange")
        app.buttons["player.previous"].tap()
        waitForTitle("海边慢信", app: app)
        app.buttons["player.next"].doubleTap()
        waitForTitle("夜色之中", app: app)
        // Wait beyond the cancelled swap's completion: it must not restore an older selection.
        Thread.sleep(forTimeInterval: 1.1)
        XCTAssertTrue(record.label.contains("夜色之中"))
        XCTAssertTrue(record.label.hasPrefix("播放"))
        sceneScreenshot("62-rapid-exchange-latest-track")
        app.buttons["player.previous"].doubleTap()
        waitForTitle("海边慢信", app: app)
        app.buttons["player.play"].tap()
        app.buttons["player.next"].tap()
        waitForTitle("窗边余响", app: app)
        XCTAssertTrue(record.label.hasPrefix("暂停"))
        sceneScreenshot("63-exchange-while-playing")
        dismissQuietRecord(app)
        XCTAssertTrue(app.buttons["listen.play"].label.contains("暂停"))
    }

    @MainActor
    func testReducedMotionExchangePreservesPauseAndReturnsCleanly() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture", "-reducedMotion", "YES"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.record"].tap()
        let record = quietRecord(app)
        record.tap()
        app.buttons["player.previous"].tap()
        waitForTitle("夜色之中", app: app)
        XCTAssertTrue(record.label.hasPrefix("播放"))
        sceneScreenshot("64-reduced-motion-exchange")
        dismissQuietRecord(app)
        XCTAssertTrue(app.tabBars.buttons["听音"].isHittable)
    }

    @MainActor
    private func waitForTitle(_ title: String, app: XCUIApplication) {
        expectation(for: NSPredicate(format: "label == %@", title), evaluatedWith: app.staticTexts["player.title"])
        waitForExpectations(timeout: 5)
        XCTAssertTrue(quietRecord(app).label.contains(title))
    }
}
