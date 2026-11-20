import XCTest

final class ListeningExperienceUITests: XCTestCase {
    @MainActor
    func testRecordMenuPreservesPauseAndRestoresFavorite() {
        let app = XCUIApplication()
        // Check the menu while paused: XCTest waits for animation quiescence with
        // a live media snapshot, which can outlast the bundled short sample track.
        app.launchArguments = ["--original-demo-fixture", "-reducedMotion", "YES"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.record"].tap()
        let record = quietRecord(app)
        record.tap()
        expectation(for: NSPredicate(format: "label BEGINSWITH %@", "播放"), evaluatedWith: record)
        waitForExpectations(timeout: 5)
        let favorite = recordMenu(app, item: "player.favorite")
        let original = favorite.label
        favorite.tap()
        XCTAssertTrue(record.label.contains("海边慢信"))
        XCTAssertTrue(record.label.hasPrefix("播放"), "A long press must not also toggle playback")
        let changed = recordMenu(app, item: "player.favorite")
        XCTAssertNotEqual(changed.label, original)
        changed.tap()
        sceneScreenshot("47-record-menu-returned-to-playback")
    }

    @MainActor
    func testSleeveUnfoldsIntoInlineCoverFlowAndReturnsSelectedAlbum() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        sceneScreenshot("40-room-before-unfold")
        app.buttons["listen.sleeve"].tap()
        XCTAssertTrue(app.buttons["gallery.close"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.sheets.firstMatch.exists, "Album browsing belongs to the artwork scene, not a sheet")
        XCTAssertEqual(app.staticTexts["gallery.album-title"].label, "潮汐来信")
        XCTAssertFalse(app.tabBars.buttons["唱片库"].isHittable)
        sceneScreenshot("41-inline-album-gallery")
        browseNextAlbum(app)
        expectation(for: NSPredicate(format: "label == %@", "午后的房间"), evaluatedWith: app.staticTexts["gallery.album-title"])
        waitForExpectations(timeout: 5)
        sceneScreenshot("42-cover-flow-window")
        app.buttons["shelf.window"].tap()
        XCTAssertTrue(app.buttons["listen.record"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["窗边余响"].exists)
        XCTAssertTrue(app.tabBars.buttons["听音"].isHittable)
        sceneScreenshot("43-album-placed-back")
    }

    @MainActor
    func testRecordEntersQuietPlaybackAndGesturesRestoreTheRoom() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.record"].tap()
        let record = quietRecord(app)
        expectation(for: NSPredicate(format: "label CONTAINS %@", "暂停"), evaluatedWith: record)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["player.play"].isHittable)
        XCTAssertTrue(app.staticTexts["player.title"].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "player.progress").firstMatch.exists)
        XCTAssertFalse(app.tabBars.buttons["听音"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "player.tonearm").firstMatch.exists)
        XCTAssertGreaterThan(record.frame.width, app.frame.width * 0.9)
        XCTAssertLessThan(record.frame.maxY, app.frame.height * 0.72)
        sceneScreenshot("44-record-only-playing")
        let onDisc = app.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.5))
        onDisc.press(forDuration: 0.1,
                     thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.68, dy: 0.5)),
                     withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(record.label.contains("夜色之中"))
        XCTAssertTrue(record.label.hasPrefix("暂停"), "Dragging the record must not also toggle playback")
        let back = app.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.5))
        back.press(forDuration: 0.1,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(record.label.contains("海边慢信"))
        record.tap()
        expectation(for: NSPredicate(format: "label BEGINSWITH %@", "播放"), evaluatedWith: record)
        waitForExpectations(timeout: 5)
        skipQuietRecord(app)
        XCTAssertTrue(record.label.contains("窗边余响"))
        record.tap()
        dismissQuietRecord(app)
        XCTAssertTrue(app.buttons["listen.play"].label.contains("暂停"))
        sceneScreenshot("45-room-restored-after-record")
    }

    @MainActor
    func testAlbumAndQuietRecordWorkWithReducedMotion() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture", "-reducedMotion", "YES"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.sleeve"].tap()
        XCTAssertTrue(app.buttons["album.play"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.sheets.firstMatch.exists)
        app.buttons["album.play"].tap()
        let record = quietRecord(app)
        XCTAssertTrue(record.label.contains("海边慢信"))
        XCTAssertFalse(app.buttons["album.play"].exists)
        XCTAssertTrue(app.buttons["player.play"].isHittable)
        sceneScreenshot("46-quiet-record-reduced-motion")
        dismissQuietRecord(app)
        XCTAssertTrue(app.buttons["listen.sleeve"].isHittable)
    }

    @MainActor
    func testStudioTransportControlsTheSameRecordAfterExtraction() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        sceneScreenshot("50-sleeve-before-extraction")
        app.buttons["listen.record"].tap()
        let record = quietRecord(app)
        XCTAssertEqual(app.buttons.matching(identifier: "player.record").count, 1)
        XCTAssertTrue(record.label.hasPrefix("暂停"))
        sceneScreenshot("51-studio-player-after-needle")
        app.buttons["player.play"].tap()
        XCTAssertTrue(record.label.hasPrefix("播放"))
        app.buttons["player.next"].tap()
        XCTAssertTrue(record.label.contains("窗边余响"))
        XCTAssertEqual(app.staticTexts["player.title"].label, "窗边余响")
        app.buttons["player.previous"].tap()
        XCTAssertTrue(record.label.contains("海边慢信"))
        app.buttons["player.play"].tap()
        XCTAssertTrue(record.label.hasPrefix("暂停"))
        dismissQuietRecord(app)
        XCTAssertTrue(app.buttons["listen.sleeve"].isHittable)
        sceneScreenshot("52-room-after-studio-return")
    }
}
