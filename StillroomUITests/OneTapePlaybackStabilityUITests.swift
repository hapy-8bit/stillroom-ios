import XCTest

/// Opt-in continuous playback diagnostics. One launch is explicitly recorded;
/// commands then stay in the same app process so a crash cannot pass as a restart.
final class OneTapePlaybackStabilityUITests: XCTestCase {
    @MainActor
    func testContinuousPlaybackPauseTrackBurstsAndScreensRemainInOneProcess() throws {
        guard ProcessInfo.processInfo.environment["ONE_TAPE_PLAYBACK_DIAGNOSTICS"] == "1" else {
            throw XCTSkip("Run only in the explicitly authorized playback diagnosis workflow.")
        }
        continueAfterFailure = false
        let quick = ProcessInfo.processInfo.environment["ONE_TAPE_PLAYBACK_DIAGNOSTICS_QUICK"] == "1"
        let app = XCUIApplication()
        XCTContext.runActivity(named: "CONTROLLED_COLD_LAUNCH — subsequent exits are not requested") { _ in
            app.launch()
        }
        if ProcessInfo.processInfo.environment["ONE_TAPE_PLAYBACK_DEBUGGER"] == "1" {
            Thread.sleep(forTimeInterval: 8)
        }
        let lcd = app.buttons["tape.lcd"]
        wait("The normal saved catalog restores") {
            lcd.exists && !lcd.label.contains("还没有磁带")
        }
        if app.alerts.firstMatch.exists { capture("stability-initial-alert"); XCTFail("Playback setup reported an alert"); return }
        let play = app.buttons["tape.play"]
        let originalTitle = lcd.label
        let originalStyle = fields(lcd).first ?? ""
        mark("begin", app: app, lcd: lcd)
        if play.label == "暂停" { tap(play, stage: "initial-pause", app: app, lcd: lcd) }
        for cycle in 0..<(quick ? 3 : 8) {
            tap(play, stage: "play-\(cycle)", app: app, lcd: lcd)
            wait("Real playback starts in cycle \(cycle)") { self.isPlaying(lcd) }
            Thread.sleep(forTimeInterval: 1)
            tap(play, stage: "pause-\(cycle)", app: app, lcd: lcd)
            wait("Pause settles in cycle \(cycle)") { play.label == "播放" && !self.isPlaying(lcd) }
            Thread.sleep(forTimeInterval: 0.3)
        }
        tap(play, stage: "resume-for-track-tests", app: app, lcd: lcd)
        wait("The real engine is playing before track replacement") { self.isPlaying(lcd) }
        for cycle in 0..<(quick ? 2 : 10) {
            tap(app.buttons["tape.next"], stage: "next-\(cycle)", app: app, lcd: lcd)
            wait("Next resumes on the same app process") { self.isPlaying(lcd) }
            Thread.sleep(forTimeInterval: 0.5)
            tap(app.buttons["tape.previous"], stage: "previous-\(cycle)", app: app, lcd: lcd)
            wait("Previous resumes on the same app process") { self.isPlaying(lcd) }
        }
        for burst in 0..<(quick ? 2 : 8) {
            mark("burst-start-\(burst)", app: app, lcd: lcd)
            app.buttons["tape.next"].tap()
            app.buttons["tape.next"].tap()
            app.buttons["tape.previous"].tap()
            play.tap()
            wait("The burst and explicit pause settle") { play.label == "播放" && !self.isPlaying(lcd) }
            mark("burst-paused-\(burst)", app: app, lcd: lcd)
            play.tap()
            wait("Playback can restart after the burst") { self.isPlaying(lcd) }
        }
        // A complete cycle returns to the original screen style. This also
        // exercises title replacement while each live renderer is mounted.
        for index in 0..<(quick ? 0 : 7) {
            tap(lcd, stage: "screen-\(index)", app: app, lcd: lcd)
            Thread.sleep(forTimeInterval: 0.7)
            tap(app.buttons["tape.next"], stage: "screen-next-\(index)", app: app, lcd: lcd)
            wait("Playback survives the visible screen change") { self.isPlaying(lcd) }
        }
        XCTAssertEqual(fields(lcd).first, originalStyle)
        for cycle in 0..<(quick ? 1 : 5) {
            mark("background-\(cycle)", app: app, lcd: lcd)
            XCUIDevice.shared.press(.home)
            Thread.sleep(forTimeInterval: 1)
            app.activate()
            XCTAssertEqual(app.state, .runningForeground)
            if play.label == "播放" { play.tap() }
            wait("Playback remains available after returning to the foreground") { self.isPlaying(lcd) }
            mark("foreground-\(cycle)", app: app, lcd: lcd)
        }
        tap(play, stage: "final-pause", app: app, lcd: lcd)
        wait("Final pause settles") { play.label == "播放" && !self.isPlaying(lcd) }
        let metadata = XCTAttachment(string: "Original selection label: \(originalTitle)\nFinal app: \(app.debugDescription)")
        metadata.name = "stability-final-process"
        metadata.lifetime = .keepAlways
        add(metadata)
        capture("stability-complete-paused")
        // XCTest's own cleanup may terminate after this marker; it is kept
        // separate from any exit observed while the commands above run.
        mark("CONTROLLED_TEST_CLEANUP_FOLLOWS", app: app, lcd: lcd)
    }

    @MainActor
    private func fields(_ lcd: XCUIElement) -> [String] {
        (lcd.value as? String ?? "").components(separatedBy: "；")
    }

    @MainActor
    private func isPlaying(_ lcd: XCUIElement) -> Bool {
        fields(lcd).dropFirst().first == "播放中"
    }

    @MainActor
    private func tap(_ button: XCUIElement, stage: String, app: XCUIApplication, lcd: XCUIElement) {
        XCTAssertEqual(app.state, .runningForeground, "App exited before \(stage)")
        mark(stage, app: app, lcd: lcd)
        XCTAssertTrue(button.exists && button.isHittable, "Unreachable control at \(stage)")
        button.tap()
        XCTAssertEqual(app.state, .runningForeground, "App exited during \(stage)")
    }

    @MainActor
    private func mark(_ stage: String, app: XCUIApplication, lcd: XCUIElement) {
        let text = "epoch=\(Date().timeIntervalSince1970); stage=\(stage); state=\(app.state.rawValue); readout=\(lcd.value as? String ?? "")"
        print("ONE_TAPE_STABILITY \(text)")
    }

    @MainActor
    private func wait(_ description: String, condition: @escaping () -> Bool) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 35), .completed, description)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
