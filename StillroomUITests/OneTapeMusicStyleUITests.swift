import XCTest

/// Runs after an authorized real catalog has been connected. The same streamed
/// recording drives every screen, so these captures do not substitute idle art.
final class OneTapeMusicStyleUITests: XCTestCase {
    @MainActor
    func testAppliedScreensAndPrintsWhileRealMusicPlays() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()
        let lcd = app.buttons["tape.lcd"]
        XCTAssertTrue(lcd.waitForExistence(timeout: 15))
        expectation(for: NSPredicate { _, _ in !lcd.label.contains("还没有磁带") }, evaluatedWith: lcd)
        waitForExpectations(timeout: 15)
        app.buttons["tape.glass"].tap()
        app.buttons["nav.library"].tap()
        XCTAssertTrue(app.buttons["crate.album.0"].waitForExistence(timeout: 10))
        app.buttons["crate.album.0"].tap()
        XCTAssertTrue(app.buttons["album.song.0"].waitForExistence(timeout: 5))
        app.buttons["album.song.0"].tap()
        expectation(for: NSPredicate(format: "label == %@", "暂停"), evaluatedWith: app.buttons["album.play"])
        waitForExpectations(timeout: 40)
        app.buttons["nav.nowPlaying"].tap()
        expectation(for: NSPredicate(format: "value CONTAINS %@", "播放中"), evaluatedWith: lcd)
        waitForExpectations(timeout: 40)
        let frame = lcd.frame
        let geometry: [String: Double] = ["x": frame.minX, "y": frame.minY,
            "width": frame.width, "height": frame.height,
            "windowWidth": app.frame.width, "windowHeight": app.frame.height]
        if let data = try? JSONSerialization.data(withJSONObject: geometry, options: [.sortedKeys]) {
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "runtime-lcd-geometry"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let screens = ["fluid", "water", "iron", "dunes", "ink", "rain", "trails", "waterfall",
                       "oscilloscope", "meters", "sand", "name", "fox"]
        for screen in screens {
            openCustomization(app)
            app.buttons["customization.tab.screen"].tap()
            let choice = app.buttons["customization.screen.\(screen)"]
            reveal(choice, in: app)
            choice.tap()
            XCTAssertEqual(choice.value as? String, "已选择")
            app.buttons["customization.close"].tap()
            expectation(for: NSPredicate(format: "value BEGINSWITH %@", screen), evaluatedWith: lcd)
            waitForExpectations(timeout: 3)
            Thread.sleep(forTimeInterval: 0.8)
            hideNavigation(app)
            Thread.sleep(forTimeInterval: 2)
            screenshot("screen-\(screen)-real-music")
            let panel = XCTAttachment(screenshot: lcd.screenshot())
            panel.name = "lcd-\(screen)"
            panel.lifetime = .keepAlways
            add(panel)
            Thread.sleep(forTimeInterval: 2)
        }
        for print in ["dog", "caterpillar", "seesaw", "city", "wild"] {
            openCustomization(app)
            app.buttons["customization.tab.print"].tap()
            let choice = app.buttons["customization.doodle.\(print)"]
            reveal(choice, in: app)
            choice.tap()
            app.buttons["customization.close"].tap()
            XCTAssertTrue((app.buttons["tape.glass"].value as? String ?? "").contains(print))
            Thread.sleep(forTimeInterval: 0.45)
            hideNavigation(app)
            screenshot("print-\(print)-applied")
        }
        openCustomization(app)
        app.buttons["customization.tab.screen"].tap()
        let readoutChoice = app.buttons["customization.screen.lcd"]
        reveal(readoutChoice, in: app, upward: false)
        readoutChoice.tap()
        app.buttons["customization.close"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertLessThan(app.frame.width, app.frame.height)
        XCTAssertLessThan(app.buttons["tape.previous"].frame.midY, app.buttons["tape.next"].frame.midY)
        screenshot("orientation-left-tall-lcd")
        XCUIDevice.shared.orientation = .landscapeRight
        expectation(for: NSPredicate { _, _ in
            app.buttons["tape.previous"].frame.midY < app.buttons["tape.next"].frame.midY
        }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("orientation-right-blocked-wide-lcd")
        XCUIDevice.shared.orientation = .portrait
        lcd.tap()
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "fluid"), evaluatedWith: lcd)
        waitForExpectations(timeout: 3)
        XCTAssertFalse(app.buttons["studio.close"].exists)
        XCTAssertTrue((lcd.value as? String ?? "").contains("播放中"))
        screenshot("tap-to-cycle-screen")
        openCustomization(app)
        app.buttons["customization.tab.screen"].tap()
        reveal(app.buttons["customization.screen.lcd"], in: app, upward: false)
        app.buttons["customization.screen.lcd"].tap()
        app.buttons["customization.close"].tap()
        app.buttons["tape.play"].tap()
        expectation(for: NSPredicate(format: "value CONTAINS %@", "已暂停"), evaluatedWith: lcd)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, upward: Bool = true) {
        for _ in 0..<8 {
            let scroll = app.scrollViews.firstMatch
            let top = max(scroll.frame.minY, app.buttons["customization.tab.screen"].frame.maxY) + 16
            let bottom = min(scroll.frame.maxY, app.buttons["nav.customize"].frame.minY) - 16
            let center = element.frame.midY
            if element.isHittable, center >= top, center <= bottom { return }
            // SwiftUI can report a chip as hittable while its center is clipped
            // beneath the fixed tabs. Use the visible drawer, not the window.
            let downward = element.exists ? center < top : !upward
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: app.frame.width / 2,
                dy: (downward ? top + 12 : bottom - 12) - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: app.frame.width / 2,
                dy: (downward ? bottom - 12 : top + 12) - app.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func hideNavigation(_ app: XCUIApplication) {
        if app.buttons["nav.customize"].exists {
            app.buttons["tape.glass"].tap()
            Thread.sleep(forTimeInterval: 0.45)
        }
    }

    @MainActor
    private func openCustomization(_ app: XCUIApplication) {
        if !app.buttons["nav.customize"].exists { app.buttons["tape.glass"].tap() }
        XCTAssertTrue(app.buttons["nav.customize"].waitForExistence(timeout: 3))
        app.buttons["nav.customize"].tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 4))
        Thread.sleep(forTimeInterval: 0.45)
    }

    @MainActor
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
