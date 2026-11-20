import XCTest

/// Runs only on the caller's dedicated QA simulator. The Files folder contains
/// generated audio and a project-owned cover, never the user's music.
final class OneTapeSourcesUITests: XCTestCase {
    @MainActor
    func testLocalFolderImportPreviewPlaybackDuplicateAndColdRestore() {
        continueAfterFailure = false
        let app = launch()
        openLocalImport(app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "One Tape，原件保留")).firstMatch.exists)
        app.buttons["import.folder"].tap()
        openQAFolder(app)
        let confirm = app.buttons["import.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 25), app.debugDescription)
        XCTAssertTrue(app.staticTexts["确认音乐与资料目标"].exists)
        screenshot("01-local-preview-cover-and-broken-file")
        confirm.tap()
        XCTAssertTrue(app.staticTexts["本次处理结果"].waitForExistence(timeout: 25), app.debugDescription)
        screenshot("02-local-import-result")
        app.buttons["import.close"].tap()
        openLibrary(app)
        XCTAssertTrue(app.buttons["crate.album.0"].waitForExistence(timeout: 10))
        app.buttons["crate.album.0"].tap()
        let song = app.buttons["album.song.0"]
        XCTAssertTrue(song.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "hittable == true AND enabled == true"), evaluatedWith: song)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(song.label.contains("One Tape QA Tone"))
        song.tap()
        expectation(for: NSPredicate(format: "label == %@", "暂停"), evaluatedWith: app.buttons["album.play"])
        waitForExpectations(timeout: 15)
        screenshot("03-local-real-playing-album")
        app.buttons["nav.nowPlaying"].tap()
        let lcd = app.buttons["tape.lcd"]
        XCTAssertTrue(lcd.waitForExistence(timeout: 10))
        expectation(for: NSPredicate { _, _ in self.position(lcd) >= 2 }, evaluatedWith: lcd)
        waitForExpectations(timeout: 15)
        app.buttons["tape.play"].tap()
        let title = lcd.label
        app.terminate()
        let reopened = launch()
        expectation(for: NSPredicate(format: "label == %@", title), evaluatedWith: reopened.buttons["tape.lcd"])
        waitForExpectations(timeout: 15)
        XCTAssertEqual(reopened.buttons["tape.play"].label, "播放")
        screenshot("04-local-cold-restored-paused")
        openLocalImport(reopened)
        reopened.buttons["import.folder"].tap()
        openQAFolder(reopened)
        XCTAssertTrue(reopened.buttons["import.confirm"].waitForExistence(timeout: 20))
        XCTAssertTrue(reopened.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "复用原歌曲")).firstMatch.exists)
        reopened.buttons["import.confirm"].tap()
        XCTAssertTrue(reopened.staticTexts["本次处理结果"].waitForExistence(timeout: 20), reopened.debugDescription)
        screenshot("05-local-duplicate-reused-and-broken-reported")
        reopened.buttons["import.close"].tap()
    }

    @MainActor
    func testSettingsMusicSourceAndPickerCancellation() {
        continueAfterFailure = false
        let app = launch()
        app.buttons["tape.glass"].tap()
        XCTAssertTrue(app.buttons["nav.settings"].waitForExistence(timeout: 5))
        app.buttons["nav.settings"].tap()
        for _ in 0..<5 where !app.buttons["settings.addMusic"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["本地音乐与 Navidrome"].exists)
        screenshot("06-settings-current-music-sources")
        app.buttons["settings.addMusic"].tap()
        XCTAssertTrue(app.buttons["source.local"].waitForExistence(timeout: 5))
        app.buttons["source.local"].tap()
        XCTAssertTrue(app.buttons["import.files"].waitForExistence(timeout: 5))
        app.buttons["import.files"].tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "取消"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), app.debugDescription)
        cancel.tap()
        XCTAssertTrue(app.buttons["import.files"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["import.confirm"].exists)
        screenshot("07-native-picker-cancel-keeps-import-choice")
        app.buttons["import.close"].tap()
    }

    @MainActor
    func testCachedServerRefreshAndDisconnectKeepsLocalMusic() {
        continueAfterFailure = false
        let app = launch()
        openOneTapeMusicSources(app)
        app.buttons["source.navidrome"].tap()
        let summary = app.staticTexts["navidrome.catalogSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10), "Run the live server connection flow first on this QA device.")
        let originalSummary = summary.label
        screenshot("08-server-only-summary-in-mixed-library")
        // A failed replacement must leave the previously usable account and
        // catalog in place. This address is synthetic and has no music server.
        replace(app.textFields["navidrome.address"], with: "http://127.0.0.1:9")
        replace(app.textFields["navidrome.username"], with: "qa-invalid-account")
        let password = app.secureTextFields["navidrome.password"]
        for _ in 0..<5 where !password.isHittable { app.swipeUp() }
        password.tap()
        password.typeText("test-only-failure\n")
        makeVisible(app.buttons["navidrome.connect"], app: app)
        app.buttons["navidrome.connect"].tap()
        for _ in 0..<6 where !app.staticTexts["navidrome.notice"].exists { app.swipeDown() }
        XCTAssertTrue(app.staticTexts["navidrome.notice"].waitForExistence(timeout: 40))
        XCTAssertEqual(summary.label, originalSummary)
        makeVisible(app.buttons["navidrome.refresh"], app: app, towardTop: true)
        app.buttons["navidrome.refresh"].tap()
        let progress = app.staticTexts["navidrome.progress"]
        for _ in 0..<6 where !progress.exists { app.swipeDown() }
        if progress.waitForExistence(timeout: 5) {
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: progress)
            waitForExpectations(timeout: 240)
        }
        XCTAssertTrue(summary.exists)
        XCTAssertEqual(summary.label, originalSummary)
        makeVisible(app.buttons["navidrome.disconnect"], app: app, towardTop: true)
        app.buttons["navidrome.disconnect"].tap()
        screenshot("09-disconnect-device-confirmation")
        // iOS 27 exposes the system confirmation action as nested AX buttons.
        let disconnect = app.buttons.matching(identifier: "navidrome.confirmDisconnect").firstMatch
        XCTAssertTrue(disconnect.waitForExistence(timeout: 5))
        disconnect.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: summary)
        waitForExpectations(timeout: 15)
        screenshot("10-disconnected-server-form")
        app.buttons["BackButton"].tap()
        app.buttons["sources.close"].tap()
        openLibrary(app)
        XCTAssertTrue(app.buttons["crate.album.0"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["crate.album.1"].exists)
        XCTAssertFalse(app.buttons["crate.album.2"].exists, "Both generated local albums survive, remote albums are removed.")
        app.buttons["crate.album.0"].tap()
        XCTAssertTrue(app.buttons["album.song.0"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["album.song.0"].label.contains("One Tape QA Tone"))
        screenshot("11-local-album-survives-disconnect")
        app.terminate()
        let reopened = launch()
        openLibrary(reopened)
        XCTAssertTrue(reopened.buttons["crate.album.0"].waitForExistence(timeout: 10))
        XCTAssertTrue(reopened.buttons["crate.album.1"].exists)
        XCTAssertFalse(reopened.buttons["crate.album.2"].exists)
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.play"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func openLocalImport(_ app: XCUIApplication) {
        openOneTapeMusicSources(app)
        XCTAssertTrue(app.buttons["source.local"].waitForExistence(timeout: 5))
        app.buttons["source.local"].tap()
        XCTAssertTrue(app.buttons["import.folder"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openLibrary(_ app: XCUIApplication) {
        if !app.buttons["nav.library"].isHittable { app.buttons["tape.glass"].tap() }
        XCTAssertTrue(app.buttons["nav.library"].waitForExistence(timeout: 5))
        app.buttons["nav.library"].tap()
    }

    @MainActor
    private func openQAFolder(_ app: XCUIApplication) {
        let folder = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "One Tape QA")).firstMatch
        if !folder.waitForExistence(timeout: 3) {
            let browse = app.buttons.matching(NSPredicate(format: "label IN %@", ["Browse", "浏览"])).firstMatch
            if browse.exists { browse.tap() }
            if !folder.waitForExistence(timeout: 3) {
                let device = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", ["On My iPhone", "我的 iPhone", "我的iPhone"])).firstMatch
                XCTAssertTrue(device.waitForExistence(timeout: 8), app.debugDescription)
                device.tap()
            }
        }
        XCTAssertTrue(folder.waitForExistence(timeout: 8), app.debugDescription)
        folder.tap()
        let open = app.buttons.matching(NSPredicate(format: "label IN %@", ["Open", "打开"])).firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 8), app.debugDescription)
        open.tap()
    }

    @MainActor
    private func replace(_ field: XCUIElement, with text: String) {
        makeVisible(field, app: XCUIApplication())
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count))
        field.typeText(text)
    }

    @MainActor
    private func makeVisible(_ element: XCUIElement, app: XCUIApplication, towardTop: Bool = false) {
        for _ in 0..<8 where !(element.exists && element.isHittable) {
            if towardTop { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    @MainActor
    private func position(_ lcd: XCUIElement) -> Double {
        let fields = (lcd.value as? String ?? "").components(separatedBy: "；")
        guard fields.count >= 3 else { return 0 }
        let pieces = fields[2].split(separator: ":").compactMap { Double($0) }
        return pieces.count == 2 ? pieces[0] * 60 + pieces[1] : 0
    }

    @MainActor
    private func screenshot(_ name: String) {
        let item = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        item.name = name
        item.lifetime = .keepAlways
        add(item)
    }
}

/// The source sheet remains available through its existing Settings entry after
/// removing the decorative top-left player control.
extension XCTestCase {
    @MainActor
    func openOneTapeMusicSources(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["tape.play"].waitForExistence(timeout: 10))
        if !app.buttons["nav.settings"].exists { app.buttons["tape.glass"].tap() }
        let settings = app.buttons["nav.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let addMusic = app.buttons["settings.addMusic"]
        for _ in 0..<7 where !addMusic.isHittable { app.swipeUp() }
        XCTAssertTrue(addMusic.exists && addMusic.isHittable)
        addMusic.tap()
        XCTAssertTrue(app.buttons["source.local"].waitForExistence(timeout: 5))
    }
}
