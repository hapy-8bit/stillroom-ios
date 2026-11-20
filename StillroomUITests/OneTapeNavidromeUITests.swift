import XCTest

/// Live opt-in validation reads a private configuration outside the checkout.
/// No server address, account or password is embedded in the test or fixtures.
final class OneTapeNavidromeUITests: XCTestCase {
    private struct Connection: Decodable {
        let address: String
        let username: String
        let password: String
    }

    @MainActor
    func testRealServerSelectionPlaybackWindingAndRelaunch() throws {
        continueAfterFailure = false
        guard let path = ProcessInfo.processInfo.environment["ONETAPE_NAVIDROME_TEST_CONFIG"] else {
            throw XCTSkip("Live Navidrome validation needs an external private test configuration.")
        }
        let connection = try JSONDecoder().decode(Connection.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.play"].waitForExistence(timeout: 15))
        openOneTapeMusicSources(app)
        app.buttons["source.navidrome"].tap()
        let address = app.textFields["navidrome.address"]
        makeVisible(address, app: app)
        if address.value as? String != connection.address {
            address.tap()
            address.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (address.value as? String ?? "").count))
            address.typeText(connection.address)
        }
        let username = app.textFields["navidrome.username"]
        makeVisible(username, app: app)
        if username.value as? String != connection.username {
            username.tap()
            username.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (username.value as? String ?? "").count))
            username.typeText(connection.username)
        }
        let password = app.secureTextFields["navidrome.password"]
        makeVisible(password, app: app)
        password.tap()
        password.typeText(connection.password)
        password.typeText("\n")
        let connect = app.buttons["navidrome.connect"]
        makeVisible(connect, app: app)
        XCTAssertTrue(connect.isEnabled)
        connect.tap()
        let progress = app.staticTexts["navidrome.progress"]
        for _ in 0..<6 where !progress.exists { app.swipeDown() }
        let started = progress.waitForExistence(timeout: 8)
        if !started { screenshot("server-submit-diagnostic") }
        XCTAssertTrue(started,
                      "The submit touch must reach the form before waiting for the server.")
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: progress)
        waitForExpectations(timeout: 240)
        let summary = app.staticTexts["navidrome.catalogSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 240), "The actual server catalog must finish, rather than a synthetic fixture.")
        screenshot("01-live-server-connected")
        app.buttons["navidrome.openLibrary"].tap()
        // The QA library may also contain imported audio. Restrict this flow
        // to remote albums so elapsed time proves a real server stream.
        XCTAssertTrue(app.buttons["library.filter"].waitForExistence(timeout: 15))
        app.buttons["library.filter"].tap()
        app.buttons["Navidrome"].tap()
        let firstCase = app.buttons["crate.album.0"]
        XCTAssertTrue(firstCase.waitForExistence(timeout: 15))
        screenshot("02-live-album-crate")
        firstCase.tap()
        let firstSong = app.buttons["album.song.0"]
        XCTAssertTrue(firstSong.waitForExistence(timeout: 8))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: firstSong)
        waitForExpectations(timeout: 5)
        screenshot("03-live-album-detail")
        firstSong.tap()
        expectLabel(app.buttons["album.play"], "暂停", timeout: 60)
        XCTAssertTrue(firstSong.exists, "Selecting music keeps the reference song list on screen.")
        screenshot("04-live-playing-song-list")
        app.buttons["nav.nowPlaying"].tap()
        let lcd = app.buttons["tape.lcd"]
        XCTAssertTrue(lcd.waitForExistence(timeout: 8))
        expectation(for: NSPredicate { _, _ in self.position(lcd) >= 3 }, evaluatedWith: lcd)
        waitForExpectations(timeout: 30)
        XCTAssertTrue((lcd.value as? String ?? "").contains("播放中"))
        screenshot("05-live-player-elapsed")
        app.buttons["tape.glass"].tap()
        app.buttons["nav.library"].tap()
        XCTAssertTrue(app.buttons["album.song.0"].waitForExistence(timeout: 5),
                      "Returning to the library retains the selected tape and its list.")
        app.buttons["nav.nowPlaying"].tap()
        if app.buttons["nav.customize"].exists { app.buttons["tape.glass"].tap() }
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["nav.customize"])
        waitForExpectations(timeout: 5)
        app.buttons["tape.play"].tap()
        expectLabel(app.buttons["tape.play"], "播放", timeout: 5)
        let before = position(lcd)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(position(lcd), before, accuracy: 1)
        let originalTitle = lcd.label
        app.buttons["tape.next"].press(forDuration: 1.7)
        expectation(for: NSPredicate { _, _ in self.position(lcd) >= before + 4 }, evaluatedWith: lcd)
        waitForExpectations(timeout: 15)
        XCTAssertEqual(lcd.label, originalTitle, "Holding winds this tape; it does not repeatedly skip songs.")
        screenshot("06-live-paused-winding")
        expectLabel(app.buttons["tape.play"], "播放", timeout: 5)
        let woundPosition = position(lcd)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(position(lcd), woundPosition, accuracy: 1,
                       "Winding a paused tape must keep it paused after release.")
        app.buttons["tape.previous"].tap()
        expectation(for: NSPredicate { _, _ in self.position(lcd) <= 1 }, evaluatedWith: lcd)
        waitForExpectations(timeout: 12)
        XCTAssertEqual(lcd.label, originalTitle)
        app.buttons["tape.next"].tap()
        if !lcd.label.contains("共 1 首") {
            XCTAssertNotEqual(lcd.label, originalTitle)
        }
        screenshot("07-live-next-track")
        app.buttons["tape.play"].tap()
        if app.buttons["tape.play"].label == "暂停" { app.buttons["tape.play"].tap() }
        let expectedRestoredLabel = lcd.label
        app.terminate()
        app.launchArguments = ["--one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.lcd"].waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "label == %@", expectedRestoredLabel), evaluatedWith: app.buttons["tape.lcd"])
        waitForExpectations(timeout: 15)
        app.buttons["tape.glass"].tap()
        app.buttons["nav.library"].tap()
        XCTAssertTrue(app.buttons["crate.album.0"].waitForExistence(timeout: 15))
        screenshot("08-live-catalog-restored")
    }

    @MainActor
    private func makeVisible(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<8 where !(element.exists && element.isHittable) { app.swipeUp() }
        XCTAssertTrue(element.exists && element.isHittable, "The saved account may push form fields below the visible viewport.")
    }

    @MainActor
    private func position(_ lcd: XCUIElement) -> Double {
        let fields = (lcd.value as? String ?? "").components(separatedBy: "；")
        guard fields.count >= 3 else { return 0 }
        let parts = fields[2].split(separator: ":").compactMap { Double($0) }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
    }

    @MainActor
    private func expectLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval) {
        expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }

    @MainActor
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
