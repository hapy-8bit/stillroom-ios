import XCTest

final class RecordOpeningUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testProjectedFaceBetweenSpinesSelectsTheVisibleAlbum() {
        let app = launchOpening(reducedMotion: false)
        let spine = app.buttons["recordOpening.album.sea"]
        XCTAssertTrue(spine.waitForExistence(timeout: 5))
        capture(app, "00a-projected-face-before-selection")
        // This noncentral cover projects below its hinge, into the gap after the 44-point
        // spine target. Exercise the visible face itself, not the central edge-on cover.
        spine.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: 0, dy: 30)).tap()
        waitUntilEnabled(app.buttons["recordOpening.play"])
        let disc = element("recordOpening.disc", in: app)
        XCTAssertEqual(disc.label, "潮汐来信，黑胶唱片")
        waitForValue("尚未播放", of: disc)
        capture(app, "00b-projected-sea-face-selected-correctly")
        app.buttons["recordOpening.back"].tap()
        XCTAssertTrue(app.buttons["recordOpening.album.window"].waitForExistence(timeout: 3))
        app.buttons["recordOpening.skip"].tap()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNormalMotionSelectionArmDragAndContinueUseRealPlayback() {
        let app = launchOpening(reducedMotion: false)
        capture(app, "01-normal-sleeve-list")
        select("sea", in: app)
        let play = app.buttons["recordOpening.play"]
        waitUntilEnabled(play)
        let disc = element("recordOpening.disc", in: app)
        waitForValue("尚未播放", of: disc)
        XCTAssertEqual(disc.label, "潮汐来信，黑胶唱片")
        capture(app, "02-normal-opened-record-ready")

        let arm = element("recordOpening.arm", in: app)
        XCTAssertTrue(arm.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(arm.frame.width, 0)
        XCTAssertGreaterThan(arm.frame.height, 0)
        // Use the real arm's hit region, so this remains a physical drag after window changes.
        // No play-button fallback: failure must expose a broken gesture or playback handoff.
        let start = arm.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.50))
        let end = arm.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.50))
        start.press(forDuration: 0.12, thenDragTo: end,
                    withVelocity: .slow, thenHoldForDuration: 0.1)

        waitForValue("正在播放", of: disc)
        let proceed = app.buttons["recordOpening.continue"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 5))
        capture(app, "03-normal-arm-drag-real-engine-playing")
        proceed.tap()
        XCTAssertTrue(app.otherElements["orbit.home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["orbit.turntable"].waitForExistence(timeout: 5))
        waitForLabel("暂停", of: app.buttons["orbit.play"])
        XCTAssertFalse(app.otherElements["recordOpening.scene"].exists)
        capture(app, "04-normal-main-turntable-playing")
    }

    @MainActor
    func testReducedMotionBackCancelsNeedleAndReselectionStaysPaused() {
        let app = launchOpening(reducedMotion: true)
        select("window", in: app)
        waitUntilEnabled(app.buttons["recordOpening.play"])
        waitForValue("尚未播放", of: element("recordOpening.disc", in: app))
        XCTAssertEqual(element("recordOpening.disc", in: app).label, "午后的房间，黑胶唱片")
        capture(app, "05-reduced-motion-record-ready")

        app.buttons["recordOpening.play"].tap()
        app.buttons["recordOpening.back"].tap()
        XCTAssertTrue(app.buttons["recordOpening.album.window"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["recordOpening.play"].exists)
        XCTAssertFalse(app.buttons["recordOpening.continue"].exists)
        capture(app, "06-back-to-list-after-needle-request")

        // XCUI may deliver Back before or after the half-second commit. Both cases must leave
        // the engine paused, and no cancelled request may restart this same track afterwards.
        select("window", in: app)
        waitUntilEnabled(app.buttons["recordOpening.play"])
        let disc = element("recordOpening.disc", in: app)
        waitForValue("尚未播放", of: disc)
        assertNoDelayedPlayback(disc, in: app)
        capture(app, "07-reselected-record-has-no-late-playback")
        app.buttons["recordOpening.back"].tap()
        XCTAssertTrue(app.buttons["recordOpening.album.window"].waitForExistence(timeout: 3))
        app.buttons["recordOpening.skip"].tap()
        XCTAssertTrue(app.otherElements["room.navigation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["recordOpening.scene"].exists)
        assertMainPlaybackPaused(app)
        capture(app, "08-cancelled-opening-main-remains-paused")
    }

    @MainActor
    func testSkipAndExplicitReplayPreserveTheNonplayingBoundary() {
        let app = launchOpening(reducedMotion: true)
        app.buttons["recordOpening.skip"].tap()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["recordOpening.scene"].exists)
        capture(app, "09-skipped-opening-library-home")

        app.buttons["room.navigation.player"].tap()
        XCTAssertTrue(app.otherElements["orbit.home"].waitForExistence(timeout: 5))
        app.buttons["orbit.more"].tap()
        let replay = app.buttons["orbit.recordOpening"]
        XCTAssertTrue(replay.waitForExistence(timeout: 3))
        replay.tap()
        XCTAssertTrue(app.otherElements["recordOpening.scene"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["recordOpening.album.night"].waitForExistence(timeout: 3))
        capture(app, "10-explicit-replay-sleeve-list")
        select("night", in: app)
        waitUntilEnabled(app.buttons["recordOpening.play"])
        let disc = element("recordOpening.disc", in: app)
        waitForValue("尚未播放", of: disc)
        XCTAssertEqual(disc.label, "月亮留声，黑胶唱片")
        assertNoDelayedPlayback(disc, in: app)
        capture(app, "11-replay-selection-does-not-autoplay")
        app.buttons["recordOpening.skip"].tap()
        XCTAssertTrue(app.otherElements["room.navigation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["recordOpening.scene"].exists)
        assertMainPlaybackPaused(app)
        capture(app, "12-replay-skipped-without-starting-audio")
    }

    @MainActor
    private func launchOpening(reducedMotion: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture", "--record-opening-preview", "-reducedMotion", reducedMotion ? "YES" : "NO"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.otherElements["recordOpening.scene"].waitForExistence(timeout: 8))
        return app
    }

    @MainActor
    private func select(_ trackID: String, in app: XCUIApplication) {
        let album = app.buttons["recordOpening.album." + trackID]
        XCTAssertTrue(album.waitForExistence(timeout: 5))
        XCTAssertTrue(album.isHittable)
        album.tap()
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func waitUntilEnabled(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 8))
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
    }

    @MainActor
    private func waitForValue(_ value: String, of element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 8), .completed)
    }

    @MainActor
    private func waitForLabel(_ label: String, of element: XCUIElement) {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    }

    @MainActor
    private func assertNoDelayedPlayback(_ disc: XCUIElement, in app: XCUIApplication) {
        let unexpectedPlay = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "正在播放"), object: disc)
        unexpectedPlay.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [unexpectedPlay], timeout: 1.2), .completed)
        XCTAssertEqual(disc.value as? String, "尚未播放")
        XCTAssertFalse(app.buttons["recordOpening.continue"].exists)
    }

    @MainActor
    private func assertMainPlaybackPaused(_ app: XCUIApplication) {
        let play = app.buttons["room.navigation.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertFalse(play.label.contains("暂停"), "Leaving an uncommitted preview must not start the audio engine.")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ stage: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Record opening — " + stage + " — simulator"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
