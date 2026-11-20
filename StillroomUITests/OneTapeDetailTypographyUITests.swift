import XCTest

/// Uses the synthetic tagged album already imported into the caller's own QA
/// simulator. Navigation never reconnects a server, clears music or changes art.
final class OneTapeDetailTypographyUITests: XCTestCase {
    private let albumTitle = "One Tape Cover QA Album"

    @MainActor
    func testDetailTypographyAndFooterRetainPlaybackAndReachableControls() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.play"].waitForExistence(timeout: 15))
        openFixtureAlbum(app)

        let first = app.buttons["album.song.0"]
        let second = app.buttons["album.song.1"]
        XCTAssertTrue(first.label.contains("Cover QA One"))
        XCTAssertTrue(second.label.contains("Cover QA Two"))
        XCTAssertTrue([first, second].contains { !isCurrent($0) },
                      "The two-song fixture always exposes a noncurrent row for visual comparison.")
        assertReachableLayout(app)
        try recordGeometry("detail-before-selection", app: app)
        screenshot("detail-01-normal-rows-and-footer")

        // Choosing an already current recording preserves its media position.
        // Move to the other QA song first so a repeat run still starts song 0
        // from a fresh selection rather than racing its previous end position.
        if isCurrent(first) {
            tap(second, app: app)
            waitUntil("The other fixture recording actually starts", timeout: 15) {
                (second.value as? String ?? "").contains("正在播放")
            }
        }
        tap(first, app: app)
        waitUntil("The selected first recording actually starts", timeout: 15) {
            (first.value as? String ?? "").contains("正在播放")
                && app.buttons["album.play"].label == "暂停"
        }
        assertReachableLayout(app)
        try recordGeometry("detail-current-recording", app: app)
        screenshot("detail-02-current-row-and-footer")

        tap(app.buttons["nav.nowPlaying"], app: app)
        let lcd = app.buttons["tape.lcd"]
        let play = app.buttons["tape.play"]
        waitReady(play, app: app)
        XCTAssertTrue(lcd.label.contains("Cover QA One"))
        waitUntil("The physical player's readout agrees with actual playback") {
            (lcd.value as? String ?? "").contains("播放中") && play.label == "暂停"
        }
        let before = try XCTUnwrap(position(lcd))
        waitUntil("Real media time advances without a second clock", timeout: 12) {
            guard let current = self.position(lcd) else { return false }
            return current >= before + 1
        }
        tap(play, app: app)
        waitUntil("Pause is reflected by the same authoritative player") {
            play.label == "播放" && (lcd.value as? String ?? "").contains("已暂停")
        }

        if !app.buttons["nav.library"].isHittable { tap(app.buttons["tape.glass"], app: app) }
        tap(app.buttons["nav.library"], app: app)
        waitReady(first, app: app, timeout: 12)
        XCTAssertTrue(app.buttons.matching(identifier: "album.hero").firstMatch.label.contains(albumTitle),
                      "Returning through the footer retains the selected album.")
        XCTAssertTrue((first.value as? String ?? "").contains("已暂停"))
        XCTAssertEqual(app.buttons["album.play"].label, "播放")
        assertReachableLayout(app)
        try recordGeometry("detail-paused-after-footer-return", app: app)
        screenshot("detail-03-paused-selection-after-footer-return")
        Thread.sleep(forTimeInterval: 2)
        screenshot("detail-04-paused-stable-frame")
        Thread.sleep(forTimeInterval: 5)
        try recordGeometry("detail-paused-late", app: app)
        screenshot("detail-05-paused-late-frame")
        // Keep the surface alive after capture, rather than racing the runner's
        // automatic app termination at the end of the case.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    private func openFixtureAlbum(_ app: XCUIApplication) {
        if !app.buttons["nav.library"].isHittable { tap(app.buttons["tape.glass"], app: app) }
        tap(app.buttons["nav.library"], app: app)
        tap(app.buttons["library.search"], app: app)
        let field = app.textFields["library.searchField"]
        waitUntil("Search arrives inside the window and accepts text") {
            field.exists && field.isHittable && app.keyboards.firstMatch.exists
                && field.frame.minX >= app.frame.minX && field.frame.maxX <= app.frame.maxX
        }
        field.tap()
        field.typeText(albumTitle + "\n")
        waitUntil("Submitting search dismisses its keyboard") { !app.keyboards.firstMatch.exists }
        let album = app.buttons["crate.album.0"]
        waitUntil("Only the synthetic tagged album matches") {
            album.exists && album.label.contains(self.albumTitle) && !app.buttons["crate.album.1"].exists
        }
        tap(album, app: app)
        waitReady(app.buttons["album.play"], app: app, timeout: 12)
        waitReady(app.buttons["album.song.0"], app: app, timeout: 12)
        waitReady(app.buttons["album.song.1"], app: app, timeout: 12)
    }

    @MainActor
    private func assertReachableLayout(_ app: XCUIApplication) {
        let play = app.buttons["album.play"], shuffle = app.buttons["album.shuffle"]
        let nowPlaying = app.buttons["nav.nowPlaying"], library = app.buttons["nav.library"]
        for element in [play, shuffle, nowPlaying, library] {
            waitReady(element, app: app)
            XCTAssertGreaterThanOrEqual(element.frame.width, 44)
            XCTAssertGreaterThanOrEqual(element.frame.height, 44)
            XCTAssertGreaterThanOrEqual(element.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.maxX)
        }
        XCTAssertLessThanOrEqual(play.frame.maxX, shuffle.frame.minX + 0.5,
                                 "Reducing text must not merge the separate playback hit regions.")
        XCTAssertLessThanOrEqual(nowPlaying.frame.maxX, library.frame.minX + 0.5)
        XCTAssertTrue(library.isSelected, "The library remains semantically selected without a decorative circle.")
        XCTAssertFalse(nowPlaying.isSelected)
        let footerTop = min(nowPlaying.frame.minY, library.frame.minY)
        for index in 0...1 {
            let song = app.buttons["album.song.\(index)"]
            waitReady(song, app: app)
            XCTAssertLessThanOrEqual(song.frame.maxY, footerTop,
                                     "Both fixture rows remain above the floating navigation.")
        }
    }

    @MainActor
    private func recordGeometry(_ name: String, app: XCUIApplication) throws {
        let identifiers = ["album.hero", "album.play", "album.shuffle", "album.song.0",
                           "album.song.1", "nav.nowPlaying", "nav.library"]
        var controls: [String: Any] = [:]
        for identifier in identifiers {
            let element = app.buttons.matching(identifier: identifier).firstMatch
            let frame = element.frame
            let entry: [String: Any] = ["x": frame.minX, "y": frame.minY,
                "width": frame.width, "height": frame.height, "label": element.label,
                "value": element.value as? String ?? "", "selected": element.isSelected]
            controls[identifier] = entry
        }
        let payload: [String: Any] = [
            "window": ["width": app.frame.width, "height": app.frame.height],
            "controls": controls
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .prettyPrinted])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name + "-geometry"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func isCurrent(_ song: XCUIElement) -> Bool {
        let value = song.value as? String ?? ""
        return value.contains("正在播放") || value.contains("已暂停")
    }

    @MainActor
    private func position(_ lcd: XCUIElement) -> Double? {
        let fields = (lcd.value as? String ?? "").components(separatedBy: "；")
        guard fields.count >= 3 else { return nil }
        let parts = fields[2].split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    @MainActor
    private func tap(_ element: XCUIElement, app: XCUIApplication) {
        waitReady(element, app: app)
        element.tap()
        XCTAssertEqual(app.state, .runningForeground,
                       "Unexpected process/background transitions must fail; do not relaunch to hide them.")
    }

    @MainActor
    private func waitReady(_ element: XCUIElement, app: XCUIApplication, timeout: TimeInterval = 8) {
        waitUntil("Expected an enabled, hittable control: \(element)", timeout: timeout) {
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
        // Preserve samples after transitions and after a longer paused interval;
        // AX existence alone cannot prove that the rendered glyphs are present.
        Thread.sleep(forTimeInterval: 0.8)
        let pixels = XCUIScreen.main.screenshot().pngRepresentation
        let attachment = XCTAttachment(data: pixels, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
