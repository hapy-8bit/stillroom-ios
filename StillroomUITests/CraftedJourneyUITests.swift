import XCTest

final class CraftedJourneyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor func testMakeBothSidesWriteSleeveListenRememberCollectAndColdRestore() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture", "-reducedMotion", "YES", "-recordOpening.completed.v1", "YES"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        let recordTitle = "AFTER THE LAST TRAIN " + String(UUID().uuidString.prefix(5))
        let memoryText = "The last train, and a song to keep the evening. " + String(UUID().uuidString.prefix(5))
        openCabinet(app)
        XCTAssertTrue(app.buttons["craft.cabinet.create"].waitForExistence(timeout: 5))
        app.buttons["craft.cabinet.create"].tap()
        XCTAssertTrue(app.buttons["craft.select.track.sea"].waitForExistence(timeout: 4))
        app.buttons["craft.select.track.sea"].tap()
        app.buttons["craft.side.b"].tap()
        app.buttons["craft.select.track.window"].tap()
        capture(app, "01-select-both-sides")
        app.buttons["craft.composer.next"].tap()
        XCTAssertTrue(app.otherElements["craft.step.arrange"].waitForExistence(timeout: 3))
        capture(app, "02-order-a-side")
        app.buttons["craft.composer.next"].tap()
        let title = app.descendants(matching: .any).matching(identifier: "craft.cover.title").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        reveal(title, app: app)
        title.tap(); title.typeText(recordTitle)
        app.swipeUp()
        let dedication = app.descendants(matching: .any).matching(identifier: "craft.cover.dedication").firstMatch
        reveal(dedication, app: app)
        dedication.tap(); dedication.typeText("A small collection for the quiet way home.")
        app.swipeDown(); app.swipeDown()
        if app.buttons["craft.cover.keyboardDone"].exists { app.buttons["craft.cover.keyboardDone"].tap() }
        app.buttons["craft.cover.flip"].tap(); app.buttons["craft.cover.flip"].tap()
        capture(app, "03-sleeve-making")
        app.buttons["craft.composer.play"].tap()
        assertTurntable(app, title: recordTitle)
        waitLabel(app.buttons["orbit.play"], equals: "暂停")
        XCTAssertFalse(app.otherElements["craft.composer"].exists)
        capture(app, "04-a-side-playing")
        seekNearRealEnd(app)
        XCTAssertTrue(app.buttons["unified.flip"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["orbit.play"].isEnabled)
        capture(app, "05-real-a-side-ended")
        app.buttons["unified.flip"].tap()
        waitLabel(app.buttons["orbit.play"], equals: "暂停")
        XCTAssertTrue(app.buttons["orbit.openPlayer"].label.contains("窗边余响"))
        seekNearRealEnd(app)
        XCTAssertTrue(app.buttons["unified.collect"].waitForExistence(timeout: 10))
        waitLabel(app.buttons["orbit.play"], equals: "从头重听")
        capture(app, "06-real-record-end")
        app.buttons["unified.sleeve"].tap()
        XCTAssertTrue(app.buttons["sleeve.close"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["sleeve.title"].label, recordTitle)
        app.buttons["sleeve.flip"].tap()
        capture(app, "06b-sleeve-back-and-both-sides")
        let memory = app.buttons["sleeve.memory.window"]
        reveal(memory, app: app)
        capture(app, "06c-visible-b-side-memory-target")
        memory.tap()
        XCTAssertTrue(app.otherElements["memory.page"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["memory.add"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["窗边余响"].exists, "The sheet must retain the chosen song as its memory target.")
        app.buttons["memory.add"].tap()
        let writing = app.textViews["memory.text"]
        XCTAssertTrue(writing.waitForExistence(timeout: 4))
        writing.tap(); writing.typeText(memoryText)
        capture(app, "07-song-memory-writing")
        app.buttons["memory.save"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "memory.entry.")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "08-saved-song-memory")
        app.buttons["memory.close"].tap()
        XCTAssertTrue(app.buttons["sleeve.close"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[memoryText].waitForExistence(timeout: 4))
        app.buttons["sleeve.close"].tap()
        let collect = app.buttons["unified.collect"]
        waitEnabled(collect)
        collect.tap()
        waitLabel(collect, equals: "已收藏")
        XCTAssertFalse(collect.isEnabled)
        capture(app, "09-collection-stamp")
        openCabinet(app)
        XCTAssertTrue(app.otherElements["craft.cabinet"].waitForExistence(timeout: 4))
        let savedRecord = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "craft.cabinet.record.", recordTitle)).firstMatch
        reveal(savedRecord, app: app)
        XCTAssertTrue(savedRecord.exists)
        let savedID = savedRecord.identifier
        capture(app, "10-collected-sleeve")
        app.buttons["craft.cabinet.close"].tap()
        app.terminate()
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        showTurntable(app)
        assertTurntable(app, title: recordTitle)
        waitLabel(app.buttons["unified.collect"], equals: "已收藏")
        waitLabel(app.buttons["orbit.play"], equals: "从头重听")
        capture(app, "11-cold-restored-finished-record")
        openCabinet(app)
        let restored = app.buttons[savedID]
        reveal(restored, app: app); XCTAssertTrue(restored.exists); restored.tap()
        XCTAssertTrue(app.buttons["sleeve.close"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["sleeve.title"].label, recordTitle)
        let stamp = app.buttons["sleeve.collect"]
        reveal(stamp, app: app)
        XCTAssertEqual(stamp.label, "已收进唱片柜")
        XCTAssertFalse(stamp.isEnabled)
        XCTAssertTrue(app.staticTexts[memoryText].exists)
        capture(app, "11b-cold-restored-sleeve-and-memory")
    }

    @MainActor func testDraftExitResumeAndMemoryCancelDoNotWritePhantomContent() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture", "-reducedMotion", "YES", "-recordOpening.completed.v1", "YES"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        openCabinet(app)
        app.buttons["craft.cabinet.create"].tap()
        app.buttons["craft.select.track.night"].tap()
        app.buttons["craft.composer.close"].tap()
        app.buttons["保存草稿后离开"].tap()
        XCTAssertTrue(app.otherElements["craft.cabinet"].waitForExistence(timeout: 5))
        let draft = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "craft.cabinet.draft.")).firstMatch
        reveal(draft, app: app)
        XCTAssertTrue(draft.exists)
        draft.tap()
        XCTAssertTrue(app.buttons["craft.select.track.night"].waitForExistence(timeout: 3))
        capture(app, "12-resumed-draft")
        app.buttons["craft.composer.close"].tap()
        if app.buttons["放弃本次修改"].exists { app.buttons["放弃本次修改"].tap() }
        app.buttons["craft.cabinet.close"].tap()
        showTurntable(app)
        revealTools(app)
        app.buttons["orbit.more"].tap(); app.buttons["orbit.memories"].tap()
        app.buttons["memory.add"].tap()
        XCTAssertFalse(app.buttons["memory.save"].isEnabled)
        app.textViews["memory.text"].tap(); app.textViews["memory.text"].typeText("Discard this unfinished note")
        app.buttons["memory.cancel"].tap(); app.buttons["memory.discard"].firstMatch.tap()
        XCTAssertTrue(app.buttons["memory.add"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Discard this unfinished note"].exists)
        capture(app, "13-cancelled-memory")
    }

    @MainActor func testNormalMotionRecordEntryPauseAndExitPreservePlaybackBoundary() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture", "-reducedMotion", "NO", "-recordOpening.completed.v1", "YES"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        let recordTitle = "EVENING STUDY " + String(UUID().uuidString.prefix(5))
        openCabinet(app)
        app.buttons["craft.cabinet.create"].tap()
        app.buttons["craft.select.track.night"].tap()
        app.buttons["craft.composer.next"].tap(); app.buttons["craft.composer.next"].tap()
        let title = app.descendants(matching: .any).matching(identifier: "craft.cover.title").firstMatch
        reveal(title, app: app); title.tap(); title.typeText(recordTitle)
        if app.buttons["craft.cover.keyboardDone"].exists { app.buttons["craft.cover.keyboardDone"].tap() }
        app.buttons["craft.composer.play"].tap()
        assertTurntable(app, title: recordTitle)
        waitLabel(app.buttons["orbit.play"], equals: "暂停")
        capture(app, "14-normal-motion-record-entry")
        let platter = app.descendants(matching: .any).matching(identifier: "orbit.turntable.record").firstMatch
        platter.tap()
        waitLabel(app.buttons["orbit.play"], equals: "播放")
        XCTAssertEqual(platter.value as? String, "已暂停")
        XCTAssertFalse(app.buttons["unified.collect"].exists)
        capture(app, "15-normal-motion-paused")
        let printedIdentity = platter.label
        let window = app.windows.firstMatch
        let handStart = window.coordinate(withNormalizedOffset: CGVector(dx: 0.63, dy: 0.39))
        handStart.press(forDuration: 0.1,
            thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.19, dy: 0.39)),
            withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertEqual(platter.label, printedIdentity)
        XCTAssertEqual(platter.value as? String, "已暂停")
        waitLabel(app.buttons["orbit.play"], equals: "播放")
        XCTAssertTrue(app.buttons["orbit.openPlayer"].label.contains("夜色之中"))
        revealTools(app)
        app.buttons["room.navigation.queue"].tap()
        let queued = app.buttons["room.queue.track.night"]
        XCTAssertTrue(queued.waitForExistence(timeout: 4))
        XCTAssertEqual(queued.value as? String, "当前歌曲，已暂停")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "room.queue.track."))
            .allElementsBoundByIndex.map(\.identifier), ["room.queue.track.night"])
        app.buttons["room.navigation.player"].tap()
        assertTurntable(app, title: recordTitle)
        waitLabel(app.buttons["orbit.play"], equals: "播放")
        XCTAssertEqual(platter.label, printedIdentity, "A one-song side cannot invent another queued song.")
        app.buttons["unified.sleeve"].tap()
        XCTAssertTrue(app.buttons["sleeve.close"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["sleeve.title"].label, recordTitle)
        app.buttons["sleeve.close"].tap()
        waitLabel(app.buttons["orbit.play"], equals: "播放")
        openCabinet(app)
        XCTAssertTrue(app.otherElements["craft.cabinet"].waitForExistence(timeout: 4))
        app.buttons["craft.cabinet.close"].tap()
        waitLabel(app.buttons["orbit.play"], equals: "播放")
        XCTAssertFalse(app.buttons["unified.collect"].exists, "Leaving the turntable must not mark a paused song as completed.")
    }

    @MainActor private func openCabinet(_ app: XCUIApplication) {
        if app.buttons["room.library.menu"].exists {
            app.buttons["room.library.menu"].tap()
            app.buttons["room.library.crafted"].tap()
        } else {
            revealTools(app)
            app.buttons["orbit.more"].tap()
            app.buttons["orbit.crafted.menu"].tap()
        }
        XCTAssertTrue(app.otherElements["craft.cabinet"].waitForExistence(timeout: 5))
    }

    @MainActor private func showTurntable(_ app: XCUIApplication) {
        if !app.otherElements["orbit.home"].exists {
            let player = app.buttons["room.navigation.player"]
            XCTAssertTrue(player.waitForExistence(timeout: 5))
            player.tap()
        }
        if !app.otherElements["orbit.turntable"].exists {
            app.buttons["orbit.views"].tap()
            app.buttons["orbit.view.turntable"].tap()
        }
        XCTAssertTrue(app.otherElements["orbit.turntable"].waitForExistence(timeout: 5))
    }

    @MainActor private func revealTools(_ app: XCUIApplication) {
        showTurntable(app)
        let reveal = app.buttons["orbit.tools.reveal"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 3))
        reveal.tap()
        XCTAssertTrue(app.buttons["orbit.more"].waitForExistence(timeout: 3))
    }

    /// Exercise the real media-time gesture in the existing wheel view. Returning to the turntable
    /// does not finish the track: the boundary assertions still wait for AVAudioPlayer's callback.
    @MainActor private func seekNearRealEnd(_ app: XCUIApplication) {
        let play = app.buttons["orbit.play"]
        if play.label == "暂停" { play.tap() }
        waitLabel(play, equals: "播放")
        revealTools(app)
        app.buttons["orbit.more"].tap()
        app.buttons["orbit.views"].tap()
        // Native nested-menu children retain their visible title, not SwiftUI's item ID.
        let wheel = app.buttons["滚轮"]
        XCTAssertTrue(wheel.waitForExistence(timeout: 3)); wheel.tap()
        let progress = app.descendants(matching: .any).matching(identifier: "orbit.progress").firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 4))
        progress.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).press(forDuration: 0.1,
            thenDragTo: progress.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)))
        let value = progress.value as? String ?? ""
        let times = value.split(separator: "/").map { text -> Double in
            let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":").compactMap { Double($0) }
            return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
        }
        XCTAssertEqual(times.count, 2)
        XCTAssertGreaterThan(times.first ?? 0, (times.last ?? 1) * 0.94, "The native gesture must actually seek close to the decoder's end.")
        app.buttons["orbit.views"].tap()
        let turntable = app.buttons["orbit.view.turntable"]
        XCTAssertTrue(turntable.waitForExistence(timeout: 3)); turntable.tap()
        XCTAssertTrue(app.otherElements["orbit.turntable"].waitForExistence(timeout: 4))
        play.tap()
    }

    @MainActor private func assertTurntable(_ app: XCUIApplication, title: String) {
        let record = app.descendants(matching: .any).matching(identifier: "orbit.turntable.record").firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 4))
        XCTAssertTrue(record.label.contains(title), "The main record must retain the custom edition's printed identity.")
    }

    @MainActor private func waitLabel(_ element: XCUIElement, equals value: String) {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND label == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: 7), .completed)
    }

    @MainActor private func waitEnabled(_ element: XCUIElement) {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: 7), .completed)
    }

    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        revealCraftedControl(element, app: app)
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "crafted-" + name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
