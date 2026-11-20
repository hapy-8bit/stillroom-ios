import XCTest

/// Uses the already connected catalog. Appearance reset changes presentation
/// only: these tests never clear music, enter credentials or reconnect a server.
final class OneTapeInteractionUITests: XCTestCase {
    @MainActor
    func testSearchCloseClearsQueryAndRestoresToolbarAndCrate() {
        continueAfterFailure = false
        let app = launchCachedApp()
        openLibrary(app)
        let crate = app.buttons["crate.album.0"]
        waitReady(crate, app: app)
        assertToolbar(app)
        let originalFilterX = app.buttons["library.filter"].frame.midX
        let originalSearchX = app.buttons["library.search"].frame.midX

        tap(app.buttons["library.search"], app: app)
        let field = app.textFields["library.searchField"]
        waitReady(field, app: app)
        waitUntil("Search hides the displaced toolbar from accessibility") {
            !app.buttons["library.albums"].exists && !app.buttons["library.filter"].exists
        }
        XCTAssertGreaterThanOrEqual(field.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(field.frame.maxX, app.frame.maxX)
        tap(field, app: app)
        field.typeText("__onetape_unmatched_20261107__")
        assertForeground(app)
        waitUntil("An unmatched query shows the explicit empty result") {
            app.staticTexts["library.empty"].label == "无匹配结果"
                && !crate.exists
        }
        assertForeground(app)
        screenshot("interaction-search-no-match")

        closeSearch(app)
        assertToolbar(app)
        waitReady(crate, app: app)
        XCTAssertEqual(app.buttons["library.filter"].frame.midX, originalFilterX, accuracy: 2)
        XCTAssertEqual(app.buttons["library.search"].frame.midX, originalSearchX, accuracy: 2)
        XCTAssertFalse(app.staticTexts["library.empty"].exists)
        screenshot("interaction-search-toolbar-restored")

        tap(app.buttons["library.search"], app: app)
        waitReady(field, app: app)
        let reopenedValue = field.value as? String ?? ""
        XCTAssertTrue(reopenedValue.isEmpty || reopenedValue == "搜索磁带和艺人",
                      "Closing search must clear the query rather than merely conceal it.")
        XCTAssertTrue(crate.exists, "The restored empty query keeps the cached catalog visible.")
        closeSearch(app)
    }

    @MainActor
    func testSelectedTapePlaysRealTimeAndIlluminatesAuthoritativePlayKey() {
        continueAfterFailure = false
        let app = launchCachedApp()
        openLibrary(app)
        openFirstTape(app)
        screenshot("interaction-tape-detail-ready")
        tap(app.buttons["album.song.0"], app: app)
        waitUntil("The selected recording must actually enter playback", timeout: 60) {
            app.buttons["album.play"].label == "暂停"
        }
        assertForeground(app)
        tap(app.buttons["nav.nowPlaying"], app: app)
        let lcd = app.buttons["tape.lcd"]
        let play = app.buttons["tape.play"]
        waitReady(play, app: app)
        waitUntil("Key illumination and LCD must agree with real playback", timeout: 30) {
            play.label == "暂停" && play.value as? String == "亮起"
                && (lcd.value as? String ?? "").contains("播放中")
        }
        guard let before = position(lcd) else {
            XCTFail("The loaded LCD must expose a valid media position in seconds.")
            return
        }
        waitUntil("Real media time advances while the key remains illuminated", timeout: 30) {
            guard let current = self.position(lcd) else { return false }
            return current >= before + 2 && play.value as? String == "亮起"
        }
        assertForeground(app)
        screenshot("interaction-player-playing-key-lit")

        tap(play, app: app)
        waitUntil("Pausing extinguishes the key and updates the same LCD readout") {
            play.label == "播放" && play.value as? String == "未亮起"
                && (lcd.value as? String ?? "").contains("已暂停")
        }
        assertForeground(app)
        screenshot("interaction-player-paused-key-unlit")
    }

    @MainActor
    func testTrackFavouriteContextMenuFiltersPersistsAndCancels() {
        continueAfterFailure = false
        let app = launchCachedApp()
        openLibrary(app)
        tap(app.buttons["library.filter"], app: app)
        tap(app.buttons["Navidrome"], app: app)
        let albumLabel = app.buttons["crate.album.0"].label
        openFirstTape(app)
        let song = app.buttons["album.song.0"]
        let songLabel = song.label
        let wasFavourite = (song.value as? String ?? "").contains("已收藏到此设备")
        if wasFavourite { toggleFavourite(song, app: app, expected: false) }
        toggleFavourite(song, app: app, expected: true)
        screenshot("interaction-track-favourite-menu")
        tap(app.buttons["album.back"], app: app)
        waitUntil("The outgoing detail leaves the crate's accessibility tree") {
            !app.buttons["album.back"].exists
        }
        // AX exposes the reinserted toolbar before the outgoing opacity/spring
        // transition has released its full-page touch surface.
        Thread.sleep(forTimeInterval: 0.8)
        tap(app.buttons["library.filter"], app: app)
        tap(app.buttons["Favourites"], app: app)
        waitUntil("The newly favourite album is included immediately") {
            app.buttons["crate.album.0"].label == albumLabel
        }
        screenshot("interaction-favourites-filter")

        // This run belongs only on a dedicated QA simulator. Termination here
        // is deliberate test automation and is not evidence of a product exit.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        openLibrary(app)
        tap(app.buttons["library.filter"], app: app)
        tap(app.buttons["Navidrome"], app: app)
        openFirstTape(app)
        XCTAssertEqual(song.label, songLabel)
        XCTAssertTrue((song.value as? String ?? "").contains("已收藏到此设备"))
        toggleFavourite(song, app: app, expected: false)
        screenshot("interaction-track-favourite-cancelled")
        if wasFavourite { toggleFavourite(song, app: app, expected: true) }
    }

    @MainActor
    func testRecentlyPlayedSortRestoresRemoteAlbumAheadOfNewLocalImports() {
        continueAfterFailure = false
        // The dedicated mixed-library QA has imported One Tape QA Tone albums
        // and a real remote listening history from the preceding live test.
        // This case never starts a song or changes that history.
        let app = launchCachedApp()
        openLibrary(app)
        XCTAssertEqual(app.buttons["library.filter"].value as? String, "Recently added")
        screenshot("history-default-recently-added-mixed-library")
        tap(app.buttons["library.filter"], app: app)
        tap(app.buttons["Recently played"], app: app)
        waitReady(app.buttons["crate.album.0"], app: app)
        let albumLabel = app.buttons["crate.album.0"].label
        XCTAssertFalse(albumLabel.contains("One Tape QA Tone"),
                       "Unplayed local imports cannot outrank the actual remote listening history")
        screenshot("history-recently-played-remote-first")
        openFirstTape(app)
        waitUntil("The most recently played album contains the cold-restored paused recording") {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "album.song."))
                .allElementsBoundByIndex.contains { ($0.value as? String ?? "").contains("已暂停") }
        }
        screenshot("history-restored-remote-track-paused")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        openLibrary(app)
        tap(app.buttons["library.filter"], app: app)
        tap(app.buttons["Recently played"], app: app)
        waitUntil("Song listening history preserves the same album order across a second cold start") {
            app.buttons["crate.album.0"].label == albumLabel
        }
        screenshot("history-recently-played-remote-first-after-relaunch")
    }

    @MainActor
    func testTenContinuousSearchOpeningAndNavigationRoundsStayForeground() {
        continueAfterFailure = false
        let app = launchCachedApp()
        openLibrary(app)
        // One process for all ten rounds. There is deliberately no terminate,
        // activate or relaunch recovery that could conceal an unexpected exit.
        for round in 1...10 {
            XCTContext.runActivity(named: "Continuous interaction round \(round)") { _ in
                assertForeground(app)
                waitReady(app.buttons["crate.album.0"], app: app)
                tap(app.buttons["library.search"], app: app)
                let field = app.textFields["library.searchField"]
                tap(field, app: app)
                field.typeText("__unmatched_round_\(round)__")
                assertForeground(app)
                waitUntil("Round \(round): unmatched search becomes visible") {
                    app.staticTexts["library.empty"].label == "无匹配结果"
                }
                assertForeground(app)
                closeSearch(app)
                assertToolbar(app)
                openFirstTape(app)
                if round == 1 || round == 10 { screenshot("stress-\(round)-tape-ready") }
                tap(app.buttons["album.back"], app: app)
                assertToolbar(app)
                waitReady(app.buttons["crate.album.0"], app: app)
                assertForeground(app)

                tap(app.buttons["nav.nowPlaying"], app: app)
                waitReady(app.buttons["tape.play"], app: app)
                XCTAssertTrue(app.buttons["tape.lcd"].exists)
                assertForeground(app)
                if round == 1 || round == 10 { screenshot("stress-\(round)-player") }
                openLibrary(app)
                assertToolbar(app)
                waitReady(app.buttons["crate.album.0"], app: app)
                assertForeground(app)
                if [1, 5, 10].contains(round) { screenshot("stress-\(round)-library") }
            }
        }
    }

    @MainActor
    private func launchCachedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        waitReady(app.buttons["tape.play"], app: app, timeout: 15)
        return app
    }

    @MainActor
    private func openLibrary(_ app: XCUIApplication) {
        assertForeground(app)
        if !app.buttons["nav.library"].isHittable {
            tap(app.buttons["tape.glass"], app: app)
        }
        tap(app.buttons["nav.library"], app: app)
        waitReady(app.buttons["crate.album.0"], app: app, timeout: 20)
    }

    @MainActor
    private func openFirstTape(_ app: XCUIApplication) {
        tap(app.buttons["crate.album.0"], app: app)
        // The floating intermediate cover is intentionally AX-hidden. Wait
        // for revealed controls; XCTest quiescence is not an animation clock.
        waitReady(app.buttons.matching(identifier: "album.hero").firstMatch, app: app, timeout: 8)
        waitReady(app.buttons["album.song.0"], app: app, timeout: 8)
        waitReady(app.buttons["album.back"], app: app)
        assertForeground(app)
    }

    @MainActor
    private func toggleFavourite(_ song: XCUIElement, app: XCUIApplication, expected: Bool) {
        waitReady(song, app: app)
        song.press(forDuration: 1)
        let action = app.buttons[expected ? "收藏到此设备" : "取消收藏"]
        waitReady(action, app: app)
        XCTAssertEqual(action.label, expected ? "收藏到此设备" : "取消收藏")
        screenshot(expected ? "interaction-add-favourite-action" : "interaction-remove-favourite-action")
        tap(action, app: app)
        waitUntil("The row reflects this device's saved favourite preference") {
            (song.value as? String ?? "").contains("已收藏到此设备") == expected
        }
    }

    @MainActor
    private func closeSearch(_ app: XCUIApplication) {
        tap(app.buttons["library.closeSearch"], app: app)
        waitUntil("Search closes and the original toolbar returns") {
            !app.textFields["library.searchField"].exists
                && app.buttons["library.search"].isHittable
        }
        assertForeground(app)
    }

    @MainActor
    private func assertToolbar(_ app: XCUIApplication) {
        for identifier in ["library.filter", "library.albums", "library.playlists", "library.search"] {
            waitReady(app.buttons[identifier], app: app)
        }
    }

    @MainActor
    private func tap(_ element: XCUIElement, app: XCUIApplication) {
        waitReady(element, app: app)
        element.tap()
        assertForeground(app)
    }

    @MainActor
    private func waitReady(_ element: XCUIElement, app: XCUIApplication, timeout: TimeInterval = 6) {
        assertForeground(app)
        waitUntil("Expected an enabled, hittable element", timeout: timeout) {
            guard element.exists, element.isHittable, element.isEnabled else { return false }
            if element.identifier == "library.searchField" {
                // AX can call a clipped, moving field hittable before the
                // capsule arrives and its delayed keyboard focus is ready.
                return element.frame.minX >= app.frame.minX
                    && element.frame.maxX <= app.frame.maxX
                    && app.keyboards.firstMatch.exists
            }
            return true
        }
        assertForeground(app)
    }

    @MainActor
    private func waitUntil(_ message: String, timeout: TimeInterval = 6,
                           condition: @escaping () -> Bool) {
        if condition() { return }
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed, message)
    }

    @MainActor
    private func assertForeground(_ app: XCUIApplication) {
        XCTAssertEqual(app.state, .runningForeground,
                       "Unexpected process/background transition must fail this run; do not restart it.")
    }

    @MainActor
    private func position(_ lcd: XCUIElement) -> TimeInterval? {
        let fields = (lcd.value as? String ?? "").components(separatedBy: "；")
        guard fields.count >= 3 else { return nil }
        let parts = fields[2].split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2, parts.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
        return parts[0] * 60 + parts[1]
    }

    @MainActor
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
