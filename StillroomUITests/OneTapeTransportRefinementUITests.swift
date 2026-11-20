import XCTest

/// Uses only this chat's existing QA simulator. Appearance uses its separate
/// fixture suite; the tagged, synthetic two-song album is never reimported.
final class OneTapeTransportRefinementUITests: XCTestCase {
    @MainActor
    func testThreeKeysRemainReachableAcrossBodyMaterials() throws {
        try requireOwnSimulator()
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture",
                               "--reset-one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.play"].waitForExistence(timeout: 15))
        capture("materials-black", app: app)
        for (body, color) in [("graphite", "black"), ("black", "green")] {
            showHUD(app)
            tap(app.buttons["nav.customize"], app: app)
            tap(app.buttons["customization.tab.body"], app: app)
            tap(app.buttons["customization.body.\(body)"], app: app)
            tap(app.buttons["customization.bodyColor.\(color)"], app: app)
            tap(app.buttons["customization.close"], app: app)
            let keys = ["tape.previous", "tape.play", "tape.next"].map { app.buttons[$0] }
            for key in keys {
                XCTAssertTrue(key.isHittable)
                XCTAssertGreaterThanOrEqual(key.frame.width, 44)
                XCTAssertGreaterThanOrEqual(key.frame.height, 44)
            }
            XCTAssertLessThan(keys[0].frame.maxY, keys[1].frame.minY)
            XCTAssertLessThan(keys[1].frame.maxY, keys[2].frame.minY)
            XCTAssertEqual(app.buttons["tape.play"].label, "播放")
            capture("materials-\(body)-\(color)", app: app)
        }
    }

    @MainActor
    func testPlayingTrackChangeResumesAndPausedTrackChangeStaysPaused() throws {
        try requireOwnSimulator()
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.play"].waitForExistence(timeout: 15))
        showHUD(app)
        tap(app.buttons["nav.library"], app: app)
        tap(app.buttons["library.search"], app: app)
        let field = app.textFields["library.searchField"]
        wait("Search accepts the isolated album title") { field.exists && field.isHittable }
        field.tap()
        field.typeText("One Tape Cover QA Album\n")
        let album = app.buttons["crate.album.0"]
        wait("Only the existing synthetic album matches") {
            album.exists && album.label.contains("One Tape Cover QA Album")
                && !app.buttons["crate.album.1"].exists && !app.keyboards.firstMatch.exists
        }
        tap(album, app: app)
        let first = app.buttons["album.song.0"]
        let second = app.buttons["album.song.1"]
        wait("Both generated recordings are available") { first.exists && second.exists }
        XCTAssertTrue(first.label.contains("Cover QA One"))
        XCTAssertTrue(second.label.contains("Cover QA Two"))
        if (first.value as? String ?? "").contains("暂停")
            || (first.value as? String ?? "").contains("播放") {
            tap(second, app: app)
            wait("The alternate generated recording starts") { app.buttons["album.play"].label == "暂停" }
        }
        tap(first, app: app)
        wait("The first QA recording is playing") {
            (first.value as? String ?? "").contains("正在播放")
        }
        tap(app.buttons["nav.nowPlaying"], app: app)
        let lcd = app.buttons["tape.lcd"]
        let play = app.buttons["tape.play"]
        wait("Actual media time advances on the physical screen") {
            lcd.label.contains("Cover QA One") && self.position(lcd) >= 1
                && (lcd.value as? String ?? "").contains("播放中")
        }
        tap(app.buttons["tape.next"], app: app)
        wait("The windup completes before the selected real decoder advances") {
            lcd.label.contains("Cover QA Two") && self.position(lcd) >= 1
                && (lcd.value as? String ?? "").contains("播放中")
                && play.value as? String == "亮起"
        }
        capture("windup-next-resumed", app: app)
        tap(play, app: app)
        wait("Explicit pause releases the real engine") {
            play.label == "播放" && (lcd.value as? String ?? "").contains("已暂停")
        }
        tap(app.buttons["tape.previous"], app: app)
        wait("A paused previous command settles without creating playing intent") {
            play.label == "播放" && play.value as? String == "未亮起"
                && (lcd.value as? String ?? "").contains("已暂停")
                && self.position(lcd) < 1
        }
        let paused = position(lcd)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(position(lcd), paused)
        XCTAssertEqual(play.label, "播放")
        capture("windup-paused-previous", app: app)
    }

    private func requireOwnSimulator() throws {
        guard ProcessInfo.processInfo.environment["SIMULATOR_UDID"]
                == "145AB0F0-7904-472C-9A3E-D78A78D5440B" else {
            throw XCTSkip("This fixture belongs only to this chat's dedicated QA simulator.")
        }
    }

    @MainActor
    private func showHUD(_ app: XCUIApplication) {
        if !app.buttons["nav.library"].isHittable { tap(app.buttons["tape.glass"], app: app) }
    }

    @MainActor
    private func position(_ lcd: XCUIElement) -> Double {
        let fields = (lcd.value as? String ?? "").components(separatedBy: "；")
        guard fields.count > 2 else { return -1 }
        let clock = fields[2].split(separator: ":").compactMap { Double($0) }
        return clock.count == 2 ? clock[0] * 60 + clock[1] : -1
    }

    @MainActor
    private func tap(_ element: XCUIElement, app: XCUIApplication) {
        wait("Enabled, reachable control: \(element)") {
            element.exists && element.isEnabled && element.isHittable
        }
        element.tap()
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    private func wait(_ description: String, condition: @escaping () -> Bool) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 15), .completed, description)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        XCTAssertEqual(app.state, .runningForeground)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
