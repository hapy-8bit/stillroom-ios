import XCTest

final class ReferencePlayerLayoutUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let failure = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            failure.name = "Reference layout — failure — " + name
            failure.lifetime = .keepAlways
            add(failure)
        }
    }

    @MainActor
    func testReferenceDeckReplacesPhysicalKeysWithToolsAndKeepsAppearanceInline() {
        let app = launchReferenceLibrary()
        startNineRecordQueue(in: app)
        assertCollapsed(in: app, playing: true)
        let record = element("orbit.turntable.record", in: app)
        let originalAlbum = record.label

        openAppearance(in: app)
        followGlobalIfNeeded(in: app)
        chooseMaterial("smoke", in: app)
        chooseBackground("atmosphere", in: app)
        assertInlineAppearance(in: app)
        XCTAssertEqual(record.label, originalAlbum)
        waitForValue("正在转动", of: record)
        closeAppearance(in: app)
        assertCollapsed(in: app, playing: true)
        app.buttons["orbit.play"].tap()
        assertCollapsed(in: app, playing: false)

        let viewport = app.windows.firstMatch.frame
        XCTAssertGreaterThan(record.frame.width, viewport.width)
        XCTAssertLessThan(record.frame.minX, viewport.minX)
        XCTAssertLessThan(record.frame.maxY, app.buttons["orbit.openPlayer"].frame.minY)
        capture(app, "01-reference-collapsed-atmosphere-smoke")

        revealTools(in: app)
        assertExpanded(in: app, playing: false)
        capture(app, "02-reference-expanded-tools")
        app.buttons["orbit.appearance"].tap()
        assertInlineAppearance(in: app)
        waitForValue("已暂停", of: record)
        XCTAssertEqual(record.label, originalAlbum)
        capture(app, "03-reference-inline-appearance")
        cycleArmLightWithoutChangingPlayback(in: app, record: record, album: originalAlbum)
        closeAppearance(in: app)

        rotateDeck(toLandscape: true, in: app, record: record, album: originalAlbum)
        capture(app, "05-reference-landscape-paused")
        rotateDeck(toLandscape: false, in: app, record: record, album: originalAlbum)

        revealTools(in: app)
        app.buttons["orbit.settings"].tap()
        let closeSettings = app.buttons["settings.close"]
        XCTAssertTrue(closeSettings.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["settings.import"].exists)
        let reducedMotion = app.switches["settings.reduceMotion"]
        let settingsForm = app.collectionViews["settings.form"]
        XCTAssertTrue(settingsForm.waitForExistence(timeout: 4))
        revealVertically(reducedMotion, in: settingsForm)
        XCTAssertTrue(reducedMotion.exists)
        XCTAssertTrue(closeSettings.isHittable)
        closeSettings.tap()
        XCTAssertTrue(app.otherElements["orbit.turntable"].waitForExistence(timeout: 3))

        revealTools(in: app)
        XCTAssertTrue(app.buttons["orbit.play"].waitForExistence(timeout: 9))
        assertCollapsed(in: app, playing: false)

        revealTools(in: app)
        app.buttons["orbit.more"].tap()
        app.buttons["orbit.import"].tap()
        XCTAssertTrue(app.buttons["import.files"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["import.folder"].exists)
        app.buttons["import.close"].tap()
        assertCollapsed(in: app, playing: false)

        revealTools(in: app)
        app.buttons["room.navigation.queue"].tap()
        XCTAssertTrue(app.otherElements["room.queue"].waitForExistence(timeout: 3))
        waitForValue("当前歌曲，已暂停", of: app.buttons["room.queue.track.cz-cylinder-one"])
        app.buttons["room.navigation.player"].tap()
        assertCollapsed(in: app, playing: false)
        XCTAssertEqual(record.label, originalAlbum)
        revealTools(in: app)
        app.buttons["room.navigation.library"].tap()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["room.navigation.library"].isSelected)
    }

    @MainActor
    func testAlbumAppearanceSurvivesRelaunchWithoutLeakingIntoTheNextAlbum() {
        let app = launchReferenceLibrary()
        startNineRecordQueue(in: app)
        app.buttons["orbit.play"].tap()
        assertCollapsed(in: app, playing: false)
        openAppearance(in: app)
        followGlobalIfNeeded(in: app)
        chooseMaterial("smoke", in: app)
        chooseBackground("atmosphere", in: app)
        let addAlbumStyle = app.buttons["orbit.style.album.add"]
        revealVertically(addAlbumStyle, in: app.scrollViews["orbit.style.panel"])
        addAlbumStyle.tap()
        XCTAssertTrue(app.buttons["orbit.style.album.selected"].waitForExistence(timeout: 2))
        chooseMaterial("silver", in: app)
        XCTAssertTrue(app.buttons["orbit.style.album.selected"].isSelected)
        XCTAssertTrue(app.staticTexts["orbit.style.album.title"].label.contains("Cylinders"))
        closeAppearance(in: app)

        selectQueuedTrack("cz-heliograph", in: app)
        waitForLabelContaining("Heliograph", of: app.buttons["orbit.openPlayer"])
        app.buttons["orbit.play"].tap()
        openAppearance(in: app)
        followGlobalIfNeeded(in: app)
        XCTAssertTrue(app.staticTexts["orbit.style.album.title"].label.contains("Divider"))
        XCTAssertTrue(app.buttons["orbit.style.album.add"].exists)
        assertSelectedMaterial("smoke", in: app)
        XCTAssertFalse(app.buttons["orbit.style.material.silver"].isSelected)
        closeAppearance(in: app)

        // Restart through the normal library. No preference injection or library reset may
        // stand in for saving the album-scoped edit made through the actual controls.
        app.terminate()
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 8))
        playAlbum("Cylinders", id: "cz-cylinder-one", in: app)
        app.buttons["orbit.play"].tap()
        openAppearance(in: app)
        XCTAssertTrue(app.buttons["orbit.style.album.selected"].isSelected)
        assertSelectedMaterial("silver", in: app)
        app.buttons["orbit.style.scope.toggle"].tap()
        assertSelectedMaterial("smoke", in: app)
        XCTAssertFalse(app.buttons["orbit.style.album.selected"].isSelected)
        app.buttons["orbit.style.scope.toggle"].tap()
        assertSelectedMaterial("silver", in: app)
        // Leave the demonstration deck following the global material after checking storage.
        app.buttons["orbit.style.restoreGlobal"].tap()
        assertSelectedMaterial("smoke", in: app)
        closeAppearance(in: app)

        navigateToLibrary(in: app)
        playAlbum("Divider", id: "cz-heliograph", in: app)
        app.buttons["orbit.play"].tap()
        openAppearance(in: app)
        XCTAssertTrue(app.buttons["orbit.style.album.add"].exists)
        XCTAssertFalse(app.buttons["orbit.style.album.selected"].exists)
        assertSelectedMaterial("smoke", in: app)
        XCTAssertTrue(app.buttons["orbit.style.background.atmosphere"].isSelected)
        closeAppearance(in: app)
        assertCollapsed(in: app, playing: false)
    }

    @MainActor
    func testNormalMotionRecordDragsSkipInBothDirectionsAndPreservePause() {
        let app = launchReferenceLibrary(reducedMotion: false)
        startNineRecordQueue(in: app)
        app.buttons["orbit.play"].tap()
        assertCollapsed(in: app, playing: false)
        let record = element("orbit.turntable.record", in: app)
        waitForValue("已暂停", of: record)

        dragRecord(in: app, direction: -1)
        waitForLabelContaining("Heliograph", of: app.buttons["orbit.openPlayer"])
        waitForValue("已暂停", of: record)
        waitForLabel("播放", of: app.buttons["orbit.play"])
        dragRecord(in: app, direction: 1)
        waitForLabelContaining("Cylinder One", of: app.buttons["orbit.openPlayer"])
        waitForValue("已暂停", of: record)
        waitForLabel("播放", of: app.buttons["orbit.play"])
        XCTAssertFalse(app.buttons["room.navigation.play"].exists)

        revealTools(in: app)
        app.buttons["room.navigation.queue"].tap()
        waitForValue("当前歌曲，已暂停", of: app.buttons["room.queue.track.cz-cylinder-one"])
        XCTAssertTrue(app.buttons["room.queue.track.cz-heliograph"].exists)
        app.buttons["room.navigation.player"].tap()
        assertCollapsed(in: app, playing: false)

        // Tap is the playback action. A completed drag above must never trigger it as well.
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.28, dy: 0.35)).tap()
        waitForLabel("暂停", of: app.buttons["orbit.play"])
        waitForValue("正在转动", of: record)
        app.buttons["orbit.play"].tap()
        waitForValue("已暂停", of: record)
    }

    @MainActor private func launchReferenceLibrary(reducedMotion: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-recordOpening.completed.v1", "YES", "-reducedMotion", reducedMotion ? "YES" : "NO"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.otherElements["recordOpening.scene"].exists)
        for id in ["sea", "window", "night"] {
            XCTAssertFalse(app.buttons["room.library.album." + id].exists)
        }
        return app
    }

    @MainActor private func startNineRecordQueue(in app: XCUIApplication) {
        let cancelSearch = app.buttons["room.library.search.cancel"]
        if cancelSearch.exists && cancelSearch.isHittable { cancelSearch.tap() }
        else if app.textFields["room.library.query"].exists { app.buttons["room.library.search"].tap() }
        XCTAssertFalse(app.textFields["room.library.query"].exists)
        let playlists = app.buttons["room.library.segment.playlists"]
        XCTAssertTrue(playlists.waitForExistence(timeout: 4))
        if !playlists.isSelected { playlists.tap() }
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: playlists)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 4), .completed)
        let collection = app.buttons["room.library.smart.demos"]
        XCTAssertTrue(collection.waitForExistence(timeout: 4))
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let viewport = app.windows.firstMatch.frame
            guard collection.exists, collection.isHittable else { return false }
            let frame = collection.frame
            return frame.width > 0 && frame.height > 0 && viewport.contains(frame)
        }, object: collection)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 8), .completed)
        // The native AX hit point was (-1,-1) in one run despite an existing row. Freeze a
        // validated visible frame and touch its physical midpoint instead of that cached point.
        let viewport = app.windows.firstMatch.frame
        let frame = collection.frame
        XCTAssertTrue(viewport.contains(frame))
        XCTAssertTrue(collection.isHittable)
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX - viewport.minX, dy: frame.midY - viewport.minY)).tap()
        let detail = app.scrollViews["room.library.detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 4))
        XCTAssertTrue(detail.staticTexts["智能歌单 · 9 首"].exists)
        let play = app.buttons["room.library.detail.play"]
        waitUntilEnabled(play)
        play.tap()
        XCTAssertTrue(app.otherElements["orbit.turntable"].waitForExistence(timeout: 5))
        waitForLabelContaining("Cylinder One", of: app.buttons["orbit.openPlayer"])
        waitForLabel("暂停", of: app.buttons["orbit.play"])
    }

    @MainActor private func playAlbum(_ title: String, id: String, in app: XCUIApplication) {
        app.buttons["room.library.search"].tap()
        let search = app.textFields["room.library.query"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText(title)
        let album = app.buttons["room.library.album." + id]
        XCTAssertTrue(album.waitForExistence(timeout: 4))
        album.tap()
        let play = app.buttons["room.library.detail.play"]
        waitUntilEnabled(play)
        play.tap()
        waitForLabel("暂停", of: app.buttons["orbit.play"])
    }

    @MainActor private func selectQueuedTrack(_ id: String, in app: XCUIApplication) {
        revealTools(in: app)
        app.buttons["room.navigation.queue"].tap()
        let track = app.buttons["room.queue.track." + id]
        XCTAssertTrue(track.waitForExistence(timeout: 3))
        track.tap()
        waitForLabel("暂停", of: app.buttons["orbit.play"])
    }

    @MainActor private func navigateToLibrary(in app: XCUIApplication) {
        revealTools(in: app)
        app.buttons["room.navigation.library"].tap()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 4))
    }

    @MainActor private func revealTools(in app: XCUIApplication) {
        let reveal = app.buttons["orbit.tools.reveal"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 3))
        reveal.tap()
        XCTAssertTrue(app.buttons["orbit.appearance"].waitForExistence(timeout: 3))
    }

    @MainActor private func openAppearance(in app: XCUIApplication) {
        revealTools(in: app)
        app.buttons["orbit.appearance"].tap()
        XCTAssertTrue(app.scrollViews["orbit.style.panel"].waitForExistence(timeout: 3))
    }

    @MainActor private func closeAppearance(in app: XCUIApplication) {
        let done = app.buttons["orbit.style.done"]
        revealVertically(done, in: app.scrollViews["orbit.style.panel"])
        done.tap()
        XCTAssertTrue(app.buttons["orbit.play"].waitForExistence(timeout: 3))
    }

    @MainActor private func followGlobalIfNeeded(in app: XCUIApplication) {
        let follow = app.buttons["orbit.style.restoreGlobal"]
        if follow.exists { follow.tap() }
        XCTAssertTrue(app.buttons["orbit.style.album.add"].exists)
    }

    @MainActor private func chooseMaterial(_ material: String, in app: XCUIApplication) {
        let target = app.buttons["orbit.style.material." + material]
        revealVertically(app.scrollViews["orbit.style.materials"], in: app.scrollViews["orbit.style.panel"])
        revealHorizontally(target, in: app.scrollViews["orbit.style.materials"])
        target.tap()
        XCTAssertTrue(target.isSelected)
    }

    @MainActor private func assertSelectedMaterial(_ material: String, in app: XCUIApplication) {
        let target = app.buttons["orbit.style.material." + material]
        XCTAssertTrue(target.waitForExistence(timeout: 3))
        XCTAssertTrue(target.isSelected)
        for other in ["black", "smoke", "silver", "radial", "resinGreen", "artwork", "split"] where other != material {
            XCTAssertFalse(app.buttons["orbit.style.material." + other].isSelected)
        }
    }

    @MainActor private func chooseBackground(_ background: String, in app: XCUIApplication) {
        let row = app.scrollViews["orbit.style.backgrounds"]
        revealVertically(row, in: app.scrollViews["orbit.style.panel"])
        let target = app.buttons["orbit.style.background." + background]
        revealHorizontally(target, in: row)
        target.tap()
        XCTAssertTrue(target.isSelected)
    }

    @MainActor private func assertCollapsed(in app: XCUIApplication, playing: Bool) {
        waitForLabel(playing ? "暂停" : "播放", of: app.buttons["orbit.play"])
        for id in ["orbit.previous", "orbit.next"] { XCTAssertTrue(app.buttons[id].exists) }
        for id in ["room.navigation.play", "room.navigation.library", "room.navigation.queue",
                   "orbit.appearance", "orbit.more", "orbit.rotate", "orbit.views", "orbit.settings", "orbit.style.done"] {
            XCTAssertFalse(app.buttons[id].exists, id + " must leave the collapsed accessibility tree")
        }
    }

    @MainActor private func assertExpanded(in app: XCUIApplication, playing: Bool) {
        waitForLabel(playing ? "暂停" : "播放", of: app.buttons["room.navigation.play"])
        for id in ["room.navigation.library", "room.navigation.player", "room.navigation.queue",
                   "orbit.appearance", "orbit.more", "orbit.rotate", "orbit.settings"] {
            XCTAssertTrue(app.buttons[id].exists)
        }
        for id in ["orbit.play", "orbit.previous", "orbit.next", "orbit.views", "orbit.style.done"] {
            XCTAssertFalse(app.buttons[id].exists, id + " must leave the expanded accessibility tree")
        }
    }

    @MainActor private func assertInlineAppearance(in app: XCUIApplication) {
        XCTAssertTrue(app.scrollViews["orbit.style.panel"].waitForExistence(timeout: 3))
        XCTAssertTrue(element("orbit.turntable.record", in: app).exists)
        XCTAssertFalse(app.sheets.firstMatch.exists)
        for id in ["orbit.play", "orbit.previous", "orbit.next", "room.navigation.play",
                   "room.navigation.library", "room.navigation.queue", "orbit.appearance", "orbit.more", "orbit.rotate", "orbit.views", "orbit.settings"] {
            XCTAssertFalse(app.buttons[id].exists, id + " must leave the inline editor accessibility tree")
        }
    }

    @MainActor private func cycleArmLightWithoutChangingPlayback(in app: XCUIApplication,
                                                               record: XCUIElement, album: String) {
        let lamp = app.buttons["orbit.style.armLight"]
        revealVertically(lamp, in: app.scrollViews["orbit.style.panel"])
        // Existing preferences may contain a prior lamp color. Reach Off through the real
        // control first, then verify a complete four-step cycle from that known state.
        for _ in 0..<4 {
            if lamp.value as? String == "关闭" { break }
            lamp.tap()
        }
        waitForValue("关闭", of: lamp)
        for color in ["红色", "蓝色", "紫色", "关闭"] {
            lamp.tap()
            waitForValue(color, of: lamp)
            XCTAssertTrue(app.buttons["orbit.style.background.atmosphere"].isSelected)
            XCTAssertEqual(record.label, album)
            waitForValue("已暂停", of: record)
            XCTAssertFalse(app.buttons["room.navigation.play"].exists)
            XCTAssertFalse(app.buttons["orbit.play"].exists)
            if color == "蓝色" { capture(app, "04-reference-blue-arm-light") }
        }
        assertInlineAppearance(in: app)
    }

    @MainActor private func rotateDeck(toLandscape landscape: Bool, in app: XCUIApplication,
                                      record: XCUIElement, album: String) {
        let rotate = app.buttons["orbit.rotate"]
        if !rotate.exists { revealTools(in: app) }
        XCTAssertTrue(rotate.waitForExistence(timeout: 3))
        rotate.tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return landscape ? frame.width > frame.height : frame.height > frame.width
        }, object: app.windows.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 8), .completed)
        let frame = app.windows.firstMatch.frame
        if landscape { XCTAssertGreaterThan(frame.width / frame.height, 1) }
        else { XCTAssertGreaterThan(frame.height / frame.width, 1) }
        XCTAssertEqual(record.label, album)
        waitForValue("已暂停", of: record)
        XCTAssertTrue(app.buttons["orbit.openPlayer"].label.contains("Cylinder One"))
        // Restore tools after geometry settles so the same authoritative paused state is
        // checked through one transport, independently of the six-second idle interval.
        revealTools(in: app)
        assertExpanded(in: app, playing: false)
    }

    @MainActor private func dragRecord(in app: XCUIApplication, direction: CGFloat) {
        // Touch the visible disc away from its spindle and the separate arm. The travel is
        // over the recovered 100-point prediction threshold while staying inside the window.
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: direction < 0 ? 0.63 : 0.19, dy: 0.39))
        let end = start.withOffset(CGVector(dx: window.frame.width * 0.40 * direction, dy: 0))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    @MainActor private func revealVertically(_ target: XCUIElement, in scroll: XCUIElement) {
        for _ in 0..<5 {
            if target.exists && target.isHittable { return }
            if target.exists && target.frame.midY < scroll.frame.minY { scroll.swipeDown() }
            else { scroll.swipeUp() }
        }
        XCTAssertTrue(target.exists && target.isHittable)
    }

    @MainActor private func revealHorizontally(_ target: XCUIElement, in scroll: XCUIElement) {
        for _ in 0..<5 {
            if target.exists && target.isHittable { return }
            scroll.swipeLeft()
        }
        // The same editor can have been scrolled by an earlier color/material choice.
        for _ in 0..<5 {
            if target.exists && target.isHittable { return }
            scroll.swipeRight()
        }
        XCTAssertTrue(target.exists && target.isHittable)
    }

    @MainActor private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor private func waitUntilEnabled(_ target: XCUIElement) {
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
    }

    @MainActor private func waitForLabel(_ label: String, of target: XCUIElement) {
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 8), .completed)
    }

    @MainActor private func waitForLabelContaining(_ text: String, of target: XCUIElement) {
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 8), .completed)
    }

    @MainActor private func waitForValue(_ value: String, of target: XCUIElement) {
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 8), .completed)
    }

    @MainActor private func capture(_ app: XCUIApplication, _ stage: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Reference layout — " + stage + " — simulator"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
