import XCTest

final class StillroomUITests: XCTestCase {
    @MainActor
    func testPlaybackNavigationWithoutLyricsAndSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.buttons["listen.record"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["mini.open"].exists)
        screenshot("01-listening")
        app.buttons["listen.record"].tap()
        let record = quietRecord(app)
        expectation(for: NSPredicate(format: "label CONTAINS %@", "暂停"), evaluatedWith: record)
        waitForExpectations(timeout: 8)
        expectation(for: NSPredicate(format: "NOT (value CONTAINS %@)", "，0:00 /"), evaluatedWith: record)
        waitForExpectations(timeout: 5)
        screenshot("02-player")
        XCTAssertFalse(app.buttons["player.lyrics"].exists)
        XCTAssertFalse(app.staticTexts["歌词"].exists)
        skipQuietRecord(app)
        XCTAssertTrue(record.label.contains("窗边余响"))
        record.tap()
        dismissQuietRecord(app)
        app.tabBars.buttons["唱片库"].tap()
        XCTAssertTrue(app.buttons["album.sea"].waitForExistence(timeout: 5))
        screenshot("04-library")
        app.buttons["album.sea"].tap()
        XCTAssertTrue(app.buttons["album.play"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.switches["settings.reduceMotion"].waitForExistence(timeout: 5))
        let toggle = app.switches["settings.reduceMotion"]
        let before = toggle.value as? String
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let changed = NSPredicate { element, _ in (element as? XCUIElement)?.value as? String != before }
        expectation(for: changed, evaluatedWith: toggle)
        waitForExpectations(timeout: 5)
        let after = toggle.value as? String
        XCTAssertNotEqual(before, after)
        app.terminate()
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.tabBars.buttons["设置"].tap()
        XCTAssertEqual(app.switches["settings.reduceMotion"].value as? String, after)
        app.switches["settings.reduceMotion"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        screenshot("05-settings")
    }

    @MainActor
    func testReversibleListeningSceneAndShelf() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.reveal"].tap()
        XCTAssertTrue(app.buttons["home.play"].waitForExistence(timeout: 5))
        screenshot("06-music-home")
        app.buttons["home.play"].tap()
        app.buttons["listen.return"].tap()
        XCTAssertTrue(app.buttons["listen.sleeve"].waitForExistence(timeout: 5))
        app.buttons["listen.sleeve"].tap()
        XCTAssertTrue(app.buttons["shelf.sea"].waitForExistence(timeout: 5))
        screenshot("07-shelf")
        app.swipeLeft()
    }

    @MainActor
    func testMusicPickerCanCancelAndReopen() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.tabBars.buttons["设置"].tap()
        for _ in 0..<2 {
            app.buttons["settings.import"].tap()
            XCTAssertTrue(app.buttons["import.files"].waitForExistence(timeout: 5))
            app.buttons["import.files"].tap()
            let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "取消"])).firstMatch
            XCTAssertTrue(cancel.waitForExistence(timeout: 8))
            screenshot("08-file-picker")
            cancel.tap()
            waitUntilHittable(app.buttons["import.close"])
            app.buttons["import.close"].tap()
            waitUntilHittable(app.buttons["settings.import"])
            XCTAssertTrue(app.buttons["settings.import"].waitForExistence(timeout: 5))
        }
    }

    @MainActor
    func testAudioContinuesWhenAppGoesToBackground() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.record"].tap()
        let record = quietRecord(app)
        expectation(for: NSPredicate(format: "label CONTAINS %@", "暂停"), evaluatedWith: record)
        waitForExpectations(timeout: 8)
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 3)
        app.activate()
        XCTAssertTrue(record.label.contains("暂停"))
        XCTAssertFalse((record.value as? String ?? "").contains("，0:00 /"))
        screenshot("09-after-background")
        record.tap()
    }

    @MainActor
    func testMiniPlayerOnlyAppearsOutsideListeningAndPlaybackContinues() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.buttons["listen.record"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["mini.open"].exists)
        app.buttons["listen.play"].tap()
        app.tabBars.buttons["唱片库"].tap()
        XCTAssertTrue(app.buttons["mini.open"].waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "label CONTAINS %@", "暂停"), evaluatedWith: app.buttons["mini.play"])
        waitForExpectations(timeout: 5)
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.buttons["mini.open"].exists)
        app.tabBars.buttons["听音"].tap()
        XCTAssertFalse(app.buttons["mini.open"].exists)
        app.buttons["listen.reveal"].tap()
        XCTAssertTrue(app.buttons["home.play"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mini.open"].exists)
        app.buttons["home.play"].tap()
    }

    @MainActor
    func testSlowSwipeDispersesAndRestoresArtwork() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.buttons["listen.record"].waitForExistence(timeout: 10))
        screenshot("10-before-swipe")
        let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.73))
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.17))
        lower.press(forDuration: 0.1, thenDragTo: upper, withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(app.buttons["home.play"].waitForExistence(timeout: 5))
        screenshot("11-after-swipe")
        // The paper now owns drags started on it; use the page margin to reverse the page transition.
        let marginTop = app.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.17))
        let marginBottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.73))
        marginTop.press(forDuration: 0.1, thenDragTo: marginBottom, withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(app.buttons["listen.record"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mini.open"].exists)
        screenshot("12-restored-sleeve")
    }

    @MainActor
    func testHomeCardsOpenAlbumAndKeepAuthoritativePlayback() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.reveal"].tap()
        XCTAssertTrue(app.buttons["home.play"].waitForExistence(timeout: 5))
        screenshot("13-home-cards")
        if !app.buttons["home.album.window"].isHittable { app.swipeUp() }
        app.buttons["home.album.window"].tap()
        XCTAssertTrue(app.buttons["album.play"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["gallery.album-title"].label, "午后的房间")
        screenshot("14-home-album")
        app.buttons["album.play"].tap()
        let record = quietRecord(app)
        XCTAssertTrue(record.label.contains("窗边余响"))
        dismissQuietRecord(app)
        XCTAssertTrue(app.buttons["home.play"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["home.current-title"].label, "窗边余响")
        if !app.buttons["home.current"].isHittable { app.swipeDown() }
        app.buttons["home.current"].tap()
        XCTAssertTrue(quietRecord(app).label.contains("暂停"))
        record.tap()
    }

    @MainActor
    func testFoldKeepsFavoritesAndImportAfterHomeIsSimplified() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture", "-reducedMotion", "YES"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.record"].tap()
        let record = quietRecord(app)
        record.tap()
        expectation(for: NSPredicate(format: "label BEGINSWITH %@", "播放"), evaluatedWith: record)
        waitForExpectations(timeout: 5)
        let favorite = recordMenu(app, item: "player.favorite")
        let originallyFavorite = favorite.label == "取消喜欢"
        if !originallyFavorite { favorite.tap() }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.9)).tap() }
        dismissQuietRecord(app)
        app.buttons["listen.reveal"].tap()
        XCTAssertTrue(app.buttons["home.fold-toggle"].waitForExistence(timeout: 5))
        app.buttons["home.fold-toggle"].tap()
        app.buttons["fold.favorites"].tap()
        XCTAssertTrue(app.buttons["track.sea"].waitForExistence(timeout: 5))
        screenshot("15-home-favorites")
        app.buttons["home.collection.close"].tap()
        waitUntilHittable(app.buttons["fold.import"])
        screenshot("16-home-fold-actions")
        app.buttons["fold.import"].tap()
        XCTAssertTrue(app.buttons["import.files"].waitForExistence(timeout: 5))
        screenshot("22-import-hub")
        app.buttons["import.files"].tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "取消"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 8))
        cancel.tap()
        waitUntilHittable(app.buttons["import.close"])
        app.buttons["import.close"].tap()
        waitUntilHittable(app.tabBars.buttons["唱片库"])
        XCTAssertTrue(app.buttons["fold.import"].waitForExistence(timeout: 5))
        // Restore the simulator's original preference instead of relying on a clean installation.
        if !originallyFavorite {
            app.tabBars.buttons["唱片库"].tap()
            app.buttons["mini.open"].tap()
            recordMenu(app, item: "player.favorite").tap()
        }
    }

    @MainActor
    func testStudioPlayerKeepsTransportClearAndSeeksWhilePaused() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.record"].tap()
        let record = quietRecord(app)
        XCTAssertGreaterThan(record.frame.width, app.frame.width * 0.9)
        XCTAssertLessThan(record.frame.maxY, app.frame.height * 0.72)
        XCTAssertTrue(app.staticTexts["player.title"].isHittable)
        XCTAssertFalse(app.buttons["player.lyrics"].exists)
        record.tap()
        expectation(for: NSPredicate(format: "label BEGINSWITH %@", "播放"), evaluatedWith: record)
        waitForExpectations(timeout: 5)
        screenshot("17-immersive-player")
        let arm = app.descendants(matching: .any).matching(identifier: "player.tonearm").firstMatch
        let before = record.value as? String
        let start = arm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = arm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        expectation(for: NSPredicate { element, _ in (element as? XCUIElement)?.value as? String != before }, evaluatedWith: record)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(record.label.hasPrefix("播放"), "Seeking with the arm stays paused and never dismisses the scene")
        screenshot("18-immersive-seek")
        recordMenu(app, item: "player.shelf").tap()
        XCTAssertTrue(app.buttons["gallery.close"].waitForExistence(timeout: 5))
        browseNextAlbum(app)
        app.buttons["shelf.window"].tap()
        XCTAssertTrue(quietRecord(app).label.contains("窗边余响"))
        XCTAssertTrue((record.value as? String ?? "").contains("0:00 /"))
        screenshot("19-immersive-window")
    }

    @MainActor
    func testImmersivePlayerAtAccessibilityTextSizeKeepsControlsReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.record"].tap()
        let record = quietRecord(app)
        XCTAssertTrue(record.isHittable)
        XCTAssertTrue(app.staticTexts["player.title"].isHittable)
        screenshot("20-immersive-large-text")
        skipQuietRecord(app)
        XCTAssertTrue(record.label.contains("窗边余响"))
        dismissQuietRecord(app)
        XCTAssertTrue(app.tabBars.buttons["听音"].isHittable)
        screenshot("21-immersive-large-controls")
    }

    @MainActor
    func testNativeTabBarKeepsGeometryAndLocalLibraryHasAnImportEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        let dock = app.tabBars.firstMatch
        XCTAssertTrue(dock.waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.count, 1)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "room.dock").firstMatch.exists)
        let initial = dock.frame
        let initialButtons = ["听音", "唱片库", "设置"].map { dock.buttons[$0].frame }
        for (index, tab) in ["唱片库", "设置", "听音"].enumerated() {
            dock.buttons[tab].tap()
            XCTAssertTrue(dock.buttons[tab].isSelected)
            XCTAssertEqual(dock.frame.minX, initial.minX, accuracy: 0.5)
            XCTAssertEqual(dock.frame.minY, initial.minY, accuracy: 0.5)
            XCTAssertEqual(dock.frame.width, initial.width, accuracy: 0.5)
            XCTAssertEqual(dock.frame.height, initial.height, accuracy: 0.5)
            for (buttonIndex, label) in ["听音", "唱片库", "设置"].enumerated() {
                let frame = dock.buttons[label].frame
                XCTAssertEqual(frame.minX, initialButtons[buttonIndex].minX, accuracy: 0.5)
                XCTAssertEqual(frame.width, initialButtons[buttonIndex].width, accuracy: 0.5)
            }
            if tab != "听音" {
                XCTAssertLessThanOrEqual(app.buttons["mini.open"].frame.maxY, dock.frame.minY + 1)
            }
            screenshot("27-native-tabs-\(index)")
        }
        app.tabBars.buttons["唱片库"].tap()
        app.buttons["library.local"].tap()
        XCTAssertTrue(app.buttons["library.empty-import"].waitForExistence(timeout: 5))
        screenshot("24-local-empty")
        app.buttons["library.empty-import"].tap()
        XCTAssertTrue(app.buttons["import.folder"].waitForExistence(timeout: 5))
        screenshot("25-import-options")
        app.buttons["import.folder"].tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "取消"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 8))
        screenshot("26-folder-picker")
        cancel.tap()
        XCTAssertTrue(app.buttons["import.files"].waitForExistence(timeout: 5))
        waitUntilHittable(app.buttons["import.close"])
        app.buttons["import.close"].tap()
        waitUntilHittable(app.tabBars.buttons["唱片库"])
        app.tabBars.buttons["设置"].tap()
        app.tabBars.buttons["唱片库"].tap()
        XCTAssertTrue(app.buttons["library.empty-import"].exists, "Switching tabs retains the library filter")
        app.buttons["library.all"].tap()
    }

    @MainActor
    func testCollectionFoldsDragDownAndUpWithoutMovingThePage() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.reveal"].tap()
        let toggle = app.buttons["home.fold-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.label, "展开唱片收藏")
        let closedY = toggle.frame.minY
        screenshot("28-charcoal-home-folded")
        let start = toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: -1.2))
        let end = start.withOffset(CGVector(dx: 0, dy: 115))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        expectation(for: NSPredicate(format: "label == %@", "收起唱片收藏"), evaluatedWith: toggle)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(toggle.frame.minY - closedY, 112, accuracy: 3, "Only the paper grows; the scroll position remains stable")
        XCTAssertTrue(app.buttons["fold.import"].isHittable)
        screenshot("29-charcoal-home-expanded")
        let raised = toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: -2.0))
        raised.press(forDuration: 0.1, thenDragTo: raised.withOffset(CGVector(dx: 0, dy: -115)),
                     withVelocity: .slow, thenHoldForDuration: 0.2)
        expectation(for: NSPredicate(format: "label == %@", "展开唱片收藏"), evaluatedWith: toggle)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(toggle.frame.minY, closedY, accuracy: 3)
        XCTAssertFalse(app.buttons["fold.import"].isHittable, "Folded-away controls cannot receive a tap")
        screenshot("30-charcoal-home-refolded")
        app.swipeUp()
        XCTAssertTrue(app.buttons["home.album.window"].isHittable, "Outside the folds the page still scrolls")
    }

    @MainActor
    func testCollectionFoldsReducedMotionAndExpandedActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture", "-reducedMotion", "YES"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.reveal"].tap()
        let toggle = app.buttons["home.fold-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(app.buttons["fold.import"].isHittable)
        screenshot("31-charcoal-folds-reduced-motion")
        app.buttons["fold.import"].tap()
        XCTAssertTrue(app.buttons["import.files"].waitForExistence(timeout: 5))
        app.buttons["import.close"].tap()
        waitUntilHittable(app.buttons["fold.albums"])
        app.buttons["fold.albums"].tap()
        XCTAssertTrue(app.buttons["shelf.sea"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMechanicalReadoutRunsPausesAndResetsWithTheCurrentSong() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.reveal"].tap()
        let elapsed = app.descendants(matching: .any).matching(identifier: "home.counter.elapsed").element
        let remaining = app.descendants(matching: .any).matching(identifier: "home.counter.remaining").element
        XCTAssertTrue(elapsed.waitForExistence(timeout: 5))
        XCTAssertEqual(elapsed.label, "0:00")
        XCTAssertEqual(remaining.label, "0:56")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "home.counter.track").element.label, "01 / 03")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "home.counter.elapsed").count, 1)
        screenshot("32-mechanical-counter-paused")
        app.buttons["home.play"].tap()
        expectation(for: NSPredicate(format: "label != %@", "0:00"), evaluatedWith: elapsed)
        waitForExpectations(timeout: 6)
        screenshot("33-mechanical-counter-running")
        app.buttons["home.play"].tap()
        let stopped = elapsed.label
        Thread.sleep(forTimeInterval: 1.2)
        XCTAssertEqual(elapsed.label, stopped, "Counters stop with the real audio engine")
        app.buttons["home.next"].tap()
        XCTAssertEqual(app.staticTexts["home.current-title"].label, "窗边余响")
        XCTAssertEqual(elapsed.label, "0:00")
        XCTAssertEqual(remaining.label, "0:48")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "home.counter.track").element.label, "02 / 03")
        XCTAssertFalse(app.buttons["home.surprise"].exists)
        XCTAssertFalse(app.buttons["home.import"].exists)
        screenshot("34-mechanical-counter-next")
        app.buttons["home.current"].tap()
        XCTAssertTrue(quietRecord(app).label.contains("窗边余响"))
    }

    @MainActor
    func testPaperWheelsCanBeTurnedByHandWithoutSeeking() {
        exercisePaperWheel(reducedMotion: false)
    }

    @MainActor
    func testPaperWheelsRemainInteractiveWithReducedMotion() {
        exercisePaperWheel(reducedMotion: true)
    }

    @MainActor private func exercisePaperWheel(reducedMotion: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        if reducedMotion { app.launchArguments = ["--original-demo-fixture", "-reducedMotion", "YES"] }
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.reveal"].tap()
        let left = app.descendants(matching: .any).matching(identifier: "home.wheel.elapsed").firstMatch
        let right = app.descendants(matching: .any).matching(identifier: "home.wheel.remaining").firstMatch
        XCTAssertTrue(left.waitForExistence(timeout: 5))
        XCTAssertTrue(left.isHittable)
        XCTAssertTrue(right.isHittable)
        XCTAssertLessThan(left.frame.width, app.frame.width * 0.3, "Only the aperture can intercept gestures")
        let elapsed = app.descendants(matching: .any).matching(identifier: "home.counter.elapsed").element
        let remaining = app.descendants(matching: .any).matching(identifier: "home.counter.remaining").element
        XCTAssertTrue(elapsed.waitForExistence(timeout: 5))
        XCTAssertLessThan(left.frame.maxY, elapsed.frame.minY)
        for (wheel, delta) in [(left, 46.0), (right, -46.0)] {
            let before = wheel.value as? String
            let start = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: delta, dy: 0)),
                        withVelocity: .slow, thenHoldForDuration: 0.1)
            expectation(for: NSPredicate { element, _ in
                (element as? XCUIElement)?.value as? String != before
            }, evaluatedWith: wheel)
            waitForExpectations(timeout: 4)
        }
        XCTAssertEqual(elapsed.label, "0:00", "Manual paper rotation never seeks audio")
        XCTAssertEqual(remaining.label, "0:56")
        screenshot(reducedMotion ? "37-paper-wheel-reduced-motion" : "35-paper-wheel-manual")
        app.buttons["home.play"].tap()
        expectation(for: NSPredicate(format: "label != %@", "0:00"), evaluatedWith: elapsed)
        waitForExpectations(timeout: 6)
        app.buttons["home.play"].tap()
        app.buttons["home.fold-toggle"].tap()
        waitUntilHittable(app.buttons["fold.import"])
        screenshot("36-paper-wheel-folds-still-work")
    }

    @MainActor private func waitUntilHittable(_ element: XCUIElement) {
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: element)
        waitForExpectations(timeout: 8)
    }

    @MainActor private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
