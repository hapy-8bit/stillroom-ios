import XCTest

/// Seed only the caller's dedicated QA Files provider with synthetic tagged
/// audio and project-owned images. This flow never clears an existing library.
final class OneTapeAlbumCoverUITests: XCTestCase {
    private let albumTitle = "One Tape Cover QA Album"
    private let importFolder = "One Tape Cover QA"
    private let manualFolder = "One Tape Manual Cover QA"

    @MainActor
    func testLocalAlbumCoverImportManualReplacementAndColdRestore() {
        continueAfterFailure = false
        let app = launch()
        openOneTapeMusicSources(app)
        tap(app.buttons["source.local"], app: app)
        tap(app.buttons["import.folder"], app: app)
        openNativeFolder(importFolder, app: app)
        let open = app.buttons.matching(identifier: "DOCPicker.actionButton").firstMatch
        tap(open, app: app)

        let scope = app.switches.matching(NSPredicate(format: "label CONTAINS %@", "应用到整张专辑")).firstMatch
        XCTAssertTrue(app.staticTexts["确认音乐与资料目标"].waitForExistence(timeout: 25), app.debugDescription)
        makeVisible(scope, app: app)
        XCTAssertEqual(scope.value as? String, "1", "A unique cover.jpg in one album folder suggests an explicit album-wide scope.")
        screenshot("cover-01-directory-cover-album-scope-preview")
        confirmImport(app)
        screenshot("cover-02-directory-import-result")
        tap(app.buttons["import.close"], app: app)

        openFixtureAlbum(app)
        assertFixtureSongs(app)
        assertAlbumCover(app)
        screenshot("cover-03-local-tagged-album-with-directory-cover")

        let hero = app.buttons.matching(identifier: "album.hero").firstMatch
        hero.press(forDuration: 1)
        let identifiedAction = app.buttons.matching(identifier: "album.setCover").firstMatch
        let action = identifiedAction.waitForExistence(timeout: 2) ? identifiedAction :
            app.buttons.matching(NSPredicate(format: "label == %@", "设置专辑封面")).firstMatch
        tap(action, app: app)
        openNativeFolder(manualFolder, app: app)
        let image = nativeCell(named: "Manual Cover QA.png", app: app)
        tap(image, app: app)

        // A single-file document picker usually returns on the file tap. Some
        // system versions keep an Open action; accept either native completion.
        let confirm = app.buttons["import.confirm"]
        if !confirm.waitForExistence(timeout: 2) {
            let fileOpen = app.buttons.matching(identifier: "DOCPicker.actionButton").firstMatch
            if fileOpen.exists { tap(fileOpen, app: app) }
        }
        XCTAssertTrue(confirm.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "整张专辑封面")).firstMatch.exists)
        screenshot("cover-04-fixed-album-replacement-preview")
        confirmImport(app)
        tap(app.buttons["import.close"], app: app)
        assertFixtureSongs(app)
        assertAlbumCover(app)
        screenshot("cover-05-replacement-updates-open-album")

        // Deliberate relaunch belongs only on this independent QA simulator.
        // No fallback relaunch is used to conceal an unexpected product exit.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["tape.play"].waitForExistence(timeout: 15))
        openFixtureAlbum(app)
        assertFixtureSongs(app)
        assertAlbumCover(app)
        screenshot("cover-06-replacement-survives-cold-restore")
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
    private func confirmImport(_ app: XCUIApplication) {
        let confirm = app.buttons["import.confirm"]
        makeVisible(confirm, app: app)
        tap(confirm, app: app)
        // The result VStack may forward its AX identifier to descendants; the
        // visible heading is a more stable native accessibility locator.
        XCTAssertTrue(app.staticTexts["本次处理结果"].waitForExistence(timeout: 25), app.debugDescription)
    }

    @MainActor
    private func openFixtureAlbum(_ app: XCUIApplication) {
        if !app.buttons["nav.library"].isHittable { tap(app.buttons["tape.glass"], app: app) }
        tap(app.buttons["nav.library"], app: app)
        tap(app.buttons["library.search"], app: app)
        let field = app.textFields["library.searchField"]
        waitUntil("The search field is ready inside the window") {
            field.exists && field.isHittable && app.keyboards.firstMatch.exists &&
                field.frame.minX >= app.frame.minX && field.frame.maxX <= app.frame.maxX
        }
        field.tap()
        field.typeText(albumTitle + "\n")
        waitUntil("Submitting search dismisses the keyboard while retaining the query") {
            !app.keyboards.firstMatch.exists
        }
        let album = app.buttons["crate.album.0"]
        waitUntil("Only the synthetic tagged album matches") {
            album.exists && album.label.contains(self.albumTitle) && !app.buttons["crate.album.1"].exists
        }
        XCTAssertTrue(album.label.contains("QA Album Artist"), "Album artist tags keep the two audio files in one actual album.")
        tap(album, app: app)
        waitReady(app.buttons.matching(identifier: "album.hero").firstMatch, app: app, timeout: 12)
        waitReady(app.buttons["album.song.0"], app: app, timeout: 12)
    }

    @MainActor
    private func assertFixtureSongs(_ app: XCUIApplication) {
        let first = app.buttons["album.song.0"], second = app.buttons["album.song.1"]
        waitReady(first, app: app)
        XCTAssertTrue(second.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(first.label.contains("Cover QA One"))
        XCTAssertTrue(second.label.contains("Cover QA Two"))
        XCTAssertFalse(app.buttons["album.song.2"].exists, "Repeated imports reuse the same two audio identities.")
    }

    @MainActor
    private func assertAlbumCover(_ app: XCUIApplication) {
        let hero = app.buttons.matching(identifier: "album.hero").firstMatch
        waitUntil("The local collection receives a real album cover", timeout: 15) {
            (hero.value as? String ?? "").contains("有专辑封面")
        }
    }

    @MainActor
    private func openNativeFolder(_ name: String, app: XCUIApplication) {
        let navigation = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
        XCTAssertTrue(navigation.waitForExistence(timeout: 12), app.debugDescription)
        let folder = nativeCell(named: name, app: app)
        for _ in 0..<8 {
            if folder.waitForExistence(timeout: 2) { tap(folder, app: app); return }
            // The picker remembers its last folder. Its navigation title is
            // sufficient when it has already returned to the requested folder.
            if navigation.staticTexts[name].exists { return }
            let phone = app.cells.matching(NSPredicate(format:
                "label BEGINSWITH %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@",
                "On My iPhone", "我的 iPhone", "我的iPhone")).firstMatch
            if phone.exists { tap(phone, app: app); continue }
            let browse = app.buttons.matching(NSPredicate(format: "label IN %@", ["Browse", "浏览"])).firstMatch
            if browse.exists && !browse.isSelected { tap(browse, app: app); continue }
            let back = app.buttons.matching(identifier: "DOC.navBarButton.backInHistory").firstMatch
            if back.exists { tap(back, app: app); continue }
            XCTFail("The dedicated QA Files folder is missing: \(name). \(app.debugDescription)")
            return
        }
        XCTFail("Could not navigate to the dedicated QA folder: \(name). \(app.debugDescription)")
    }

    @MainActor
    private func nativeCell(named name: String, app: XCUIApplication) -> XCUIElement {
        // Files can hide an image's extension in its visible cell label.
        let stem = (name as NSString).deletingPathExtension
        return app.cells.matching(NSPredicate(format:
            "label == %@ OR label BEGINSWITH %@ OR label == %@ OR label BEGINSWITH %@",
            name, name + ",", stem, stem + ",")).firstMatch
    }

    @MainActor
    private func makeVisible(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<8 where !(element.exists && element.isHittable) { app.swipeUp() }
        XCTAssertTrue(element.exists && element.isHittable, app.debugDescription)
    }

    @MainActor
    private func tap(_ element: XCUIElement, app: XCUIApplication) {
        waitReady(element, app: app)
        element.tap()
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    private func waitReady(_ element: XCUIElement, app: XCUIApplication, timeout: TimeInterval = 8) {
        waitUntil("Expected an enabled, hittable control. \(element)", timeout: timeout) {
            element.exists && element.isEnabled && element.isHittable
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    private func waitUntil(_ message: String, timeout: TimeInterval = 8, condition: @escaping () -> Bool) {
        if condition() { return }
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed, message)
    }

    @MainActor
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
