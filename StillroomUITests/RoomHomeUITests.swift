import XCTest

final class RoomHomeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testPolish35KeepsFloatingHeaderAndFullRowSearchConsistentWithRealAlbums() {
        let app = XCUIApplication()
        app.launchArguments = ["-recordOpening.completed.v1", "YES", "-reducedMotion", "NO"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 8))
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
        for legacyID in ["sea", "window", "night"] {
            XCTAssertFalse(app.buttons["room.library.album." + legacyID].exists)
        }
        assertSelectedDestination("library", in: app)

        let menu = app.buttons["room.library.menu"]
        let searchButton = app.buttons["room.library.search"]
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        XCTAssertTrue(searchButton.exists)
        let menuLeading = menu.frame.minX
        let menuMidY = menu.frame.midY
        let searchMidY = searchButton.frame.midY
        XCTAssertEqual(menuMidY, searchMidY, accuracy: 4)
        capture(app, "polish35-01-initial-floating-header")

        let content = app.scrollViews["room.library.content"]
        XCTAssertTrue(content.waitForExistence(timeout: 3))
        XCTAssertLessThan(content.frame.minY, menu.frame.maxY,
                          "The scroll viewport must extend behind the floating controls.")
        let firstVisibleAlbum = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "room.library.album.")).firstMatch
        XCTAssertTrue(firstVisibleAlbum.exists)
        let firstAlbum = app.buttons[firstVisibleAlbum.identifier]
        let initialAlbumY = firstAlbum.frame.midY
        content.swipeUp()
        XCTAssertTrue(!firstAlbum.exists || firstAlbum.frame.midY < initialAlbumY - 10,
                      "The cover content must actually move before checking the fixed header.")
        XCTAssertEqual(menu.frame.midY, menuMidY, accuracy: 1)
        XCTAssertEqual(searchButton.frame.midY, searchMidY, accuracy: 1)
        capture(app, "polish35-02-covers-scroll-behind-floating-controls")

        XCTAssertTrue(searchButton.isHittable)
        // XCTest's default tap selects the transparent bounding-box corner when these
        // circular controls overlap covers. Use the live bounds' physical interior,
        // rather than a fixed screen coordinate or the unrelated album's activation point.
        searchButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let query = app.textFields["room.library.query"]
        XCTAssertTrue(query.waitForExistence(timeout: 3))
        XCTAssertFalse(menu.exists)
        XCTAssertFalse(searchButton.exists)
        XCTAssertEqual(query.frame.midY, menuMidY, accuracy: 4)
        // AX exposes the text inset after the magnifying glass, rather than the whole
        // capsule. Its leading edge must still reclaim the former left-menu region.
        XCTAssertGreaterThanOrEqual(query.frame.minX, menuLeading)
        XCTAssertLessThanOrEqual(query.frame.minX, menuLeading + 52)
        XCTAssertGreaterThan(query.frame.width, app.frame.width * 0.5)
        XCTAssertFalse(app.buttons["room.library.segment.albums"].exists)
        XCTAssertFalse(app.buttons["room.library.segment.playlists"].exists)
        let cancel = app.buttons["room.library.search.cancel"]
        XCTAssertTrue(cancel.exists)
        XCTAssertEqual(cancel.frame.midY, menuMidY, accuracy: 4)
        XCTAssertEqual(cancel.frame.midY, searchMidY, accuracy: 4)
        XCTAssertGreaterThanOrEqual(cancel.frame.width, 44)
        XCTAssertGreaterThanOrEqual(cancel.frame.height, 44)
        XCTAssertEqual(cancel.frame.width, cancel.frame.height, accuracy: 1)
        XCTAssertGreaterThan(cancel.frame.minX, query.frame.maxX)
        capture(app, "polish35-03-full-row-search-and-round-close")
        query.tap()
        query.typeText("Cylinders")

        let cylinders = app.buttons["room.library.album.cz-cylinder-one"]
        XCTAssertTrue(cylinders.waitForExistence(timeout: 4))
        XCTAssertTrue(cylinders.label.contains("Cylinders"))
        cancel.tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        menu.tap()
        app.buttons["列表"].tap()
        XCTAssertTrue(libraryElement("room.library.list", in: app).waitForExistence(timeout: 3))
        search("Cylinders", in: app)
        XCTAssertTrue(cylinders.exists)
        XCTAssertTrue(cylinders.label.contains("Cylinders"))
        let listHeight = cylinders.frame.height
        XCTAssertGreaterThan(listHeight, 0)
        XCTAssertEqual(query.value as? String, "Cylinders")
        capture(app, "polish35-04-same-real-album-list-layout")
        cancel.tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        menu.tap()
        app.buttons["网格"].tap()
        XCTAssertTrue(libraryElement("room.library.grid", in: app).waitForExistence(timeout: 3))
        search("Cylinders", in: app)
        let gridSettled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            cylinders.exists && cylinders.frame.height > listHeight
        }, object: cylinders)
        XCTAssertEqual(XCTWaiter.wait(for: [gridSettled], timeout: 4), .completed)
        XCTAssertTrue(cylinders.label.contains("Cylinders"))
        XCTAssertEqual(query.value as? String, "Cylinders")
        capture(app, "polish35-05-same-real-album-grid-layout")

        cancel.tap()
        XCTAssertTrue(searchButton.waitForExistence(timeout: 3))
        XCTAssertFalse(query.exists)
        XCTAssertTrue(app.buttons["room.library.segment.albums"].exists)
        XCTAssertTrue(app.buttons["room.library.segment.playlists"].exists)
        XCTAssertEqual(menu.frame.midY, menuMidY, accuracy: 4)
        XCTAssertEqual(searchButton.frame.midY, searchMidY, accuracy: 4)
        capture(app, "polish35-06-close-restores-three-floating-controls")

        // The collection count comes from the normal supplied catalog, not a fixture or
        // injected queue. Opening it must leave the actual paused transport unchanged.
        app.buttons["room.library.segment.playlists"].tap()
        let supplied = app.buttons["room.library.smart.demos"]
        XCTAssertTrue(supplied.waitForExistence(timeout: 3))
        supplied.tap()
        let detail = app.scrollViews["room.library.detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 4))
        XCTAssertTrue(detail.staticTexts["智能歌单 · 9 首"].exists)
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
        assertSelectedDestination("library", in: app)

        app.buttons["room.navigation.queue"].tap()
        XCTAssertTrue(app.otherElements["room.queue"].waitForExistence(timeout: 4))
        assertSelectedDestination("queue", in: app)
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
        capture(app, "polish35-07-only-queue-navigation-selected")
        app.buttons["room.navigation.player"].tap()
        XCTAssertTrue(app.otherElements["orbit.home"].waitForExistence(timeout: 4))
        if !app.otherElements["orbit.turntable"].exists {
            app.buttons["orbit.views"].tap()
            app.buttons["黑胶唱盘"].tap()
        }
        XCTAssertTrue(app.otherElements["orbit.turntable"].waitForExistence(timeout: 4))
        waitForLabel("播放", of: app.buttons["orbit.play"])
        revealTurntableTools(in: app)
        assertSelectedDestination("player", in: app)
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
        capture(app, "polish35-08-only-player-navigation-selected")
        app.buttons["room.navigation.library"].tap()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 4))
        assertSelectedDestination("library", in: app)
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
    }

    @MainActor
    func testCompletedOpeningColdLaunchReturnsToThePersistentLibrary() {
        let app = launchHome()
        XCTAssertTrue(app.buttons["room.navigation.library"].isSelected)
        XCTAssertTrue(app.buttons["room.library.segment.albums"].exists)
        XCTAssertTrue(app.buttons["room.library.segment.playlists"].exists)
        XCTAssertTrue(app.buttons["room.library.search"].exists)
        XCTAssertTrue(app.buttons["room.library.menu"].exists)
        XCTAssertFalse(app.otherElements["recordOpening.scene"].exists)
        // Check the live accessible button bounds, not just the declared SwiftUI icon frame.
        for target in ["library", "player", "queue", "play"] {
            let button = app.buttons["room.navigation." + target]
            XCTAssertTrue(button.waitForExistence(timeout: 3))
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, target + " hit width")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, target + " hit height")
        }
        capture(app, "01-cold-launch-library-home")

        app.buttons["room.navigation.player"].tap()
        XCTAssertTrue(app.otherElements["orbit.home"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["room.navigation.library"].isSelected)
        XCTAssertFalse(app.otherElements["recordOpening.scene"].exists)
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
        capture(app, "02-cold-relaunch-library-without-onboarding")
    }

    @MainActor
    func testAlbumDetailPlaysAndNavigationPreservesTheLiveQueue() {
        let app = launchHome()
        search("潮汐来信", in: app)
        let album = app.buttons["room.library.album.sea"]
        XCTAssertTrue(album.waitForExistence(timeout: 5))
        album.tap()
        XCTAssertTrue(app.scrollViews["room.library.detail"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["room.library.detail.title"].label, "潮汐来信")
        XCTAssertTrue(app.buttons["room.library.track.sea"].exists)
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
        capture(app, "03-real-album-detail-before-play")

        let playAlbum = app.buttons["room.library.detail.play"]
        waitUntilEnabled(playAlbum)
        playAlbum.tap()
        XCTAssertTrue(app.otherElements["orbit.turntable"].waitForExistence(timeout: 5))
        waitForLabel("暂停", of: app.buttons["orbit.play"])
        XCTAssertFalse(app.buttons["room.navigation.play"].exists)
        XCTAssertTrue(app.buttons["orbit.openPlayer"].label.contains("海边慢信"))
        capture(app, "04-album-play-uses-main-turntable")

        revealTurntableTools(in: app)
        app.buttons["room.navigation.queue"].tap()
        XCTAssertTrue(app.otherElements["room.queue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["room.queue.track.sea"].waitForExistence(timeout: 5))
        let queueBefore = queueIdentifiers(app)
        XCTAssertEqual(queueBefore, ["room.queue.track.sea"])
        waitForValue("当前歌曲，正在播放", of: app.buttons["room.queue.track.sea"])
        capture(app, "05-live-album-queue")

        app.buttons["room.navigation.library"].tap()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 5))
        waitForLabel("暂停", of: app.buttons["room.navigation.play"])
        app.buttons["room.library.segment.playlists"].tap()
        app.buttons["room.library.smart.demos"].tap()
        XCTAssertTrue(app.scrollViews["room.library.detail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["room.library.track.window"].exists)
        capture(app, "06-browse-another-collection-without-replacing-queue")

        app.buttons["room.navigation.queue"].tap()
        XCTAssertTrue(app.otherElements["room.queue"].waitForExistence(timeout: 5))
        XCTAssertEqual(queueIdentifiers(app), queueBefore)
        waitForValue("当前歌曲，正在播放", of: app.buttons["room.queue.track.sea"])
        waitForLabel("暂停", of: app.buttons["room.navigation.play"])
        app.buttons["room.navigation.play"].tap()
        waitForValue("当前歌曲，已暂停", of: app.buttons["room.queue.track.sea"])
        app.buttons["room.navigation.player"].tap()
        XCTAssertTrue(app.otherElements["orbit.turntable"].waitForExistence(timeout: 5))
        waitForLabel("播放", of: app.buttons["orbit.play"])
        XCTAssertFalse(app.buttons["room.navigation.play"].exists)
        XCTAssertTrue(app.buttons["orbit.openPlayer"].label.contains("海边慢信"))
        capture(app, "07-explicit-pause-survives-navigation")
    }

    @MainActor
    func testSearchEmptyCancelLayoutsAndSmartPlaylistsUseRealCollections() {
        let app = launchHome()
        search("NO_LIBRARY_MATCH_" + UUID().uuidString, in: app)
        XCTAssertTrue(app.otherElements["room.library.empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["没有找到音乐"].exists)
        XCTAssertFalse(app.buttons["room.library.album.sea"].exists)
        capture(app, "08-search-has-no-fabricated-results")
        app.buttons["room.library.search.cancel"].tap()
        XCTAssertFalse(app.textFields["room.library.query"].exists)
        XCTAssertFalse(app.otherElements["room.library.empty"].exists)

        // Search temporarily replaces the menu. Choose each layout before searching the
        // same known album; existing simulator imports and playback remain untouched.
        app.buttons["room.library.menu"].tap()
        app.buttons["列表"].tap()
        search("潮汐来信", in: app)
        let album = app.buttons["room.library.album.sea"]
        XCTAssertTrue(album.waitForExistence(timeout: 5))
        let listHeight = album.frame.height
        XCTAssertGreaterThan(listHeight, 0)
        capture(app, "09-search-result-list-layout")
        app.buttons["room.library.search.cancel"].tap()
        XCTAssertTrue(app.buttons["room.library.menu"].waitForExistence(timeout: 3))
        app.buttons["room.library.menu"].tap()
        app.buttons["网格"].tap()
        search("潮汐来信", in: app)
        XCTAssertTrue(album.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(album.frame.height, listHeight)
        capture(app, "10-same-album-grid-layout")
        app.buttons["room.library.search.cancel"].tap()
        XCTAssertFalse(app.textFields["room.library.query"].exists)

        app.buttons["room.library.segment.playlists"].tap()
        for kind in ["favorites", "imported", "demos"] {
            XCTAssertTrue(app.buttons["room.library.smart." + kind].exists)
        }
        capture(app, "11-source-and-favorite-smart-playlists")
        app.buttons["room.library.smart.demos"].tap()
        XCTAssertTrue(app.scrollViews["room.library.detail"].waitForExistence(timeout: 5))
        for id in ["sea", "window", "night"] {
            XCTAssertTrue(app.buttons["room.library.track." + id].exists)
        }
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
        capture(app, "12-demo-collection-detail-does-not-autoplay")
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.exists)
        back.tap()
        XCTAssertTrue(app.buttons["room.library.segment.albums"].waitForExistence(timeout: 3))
        app.buttons["room.library.segment.albums"].tap()
        XCTAssertTrue(app.otherElements["room.library"].exists)
        XCTAssertFalse(app.otherElements["recordOpening.scene"].exists)
    }

    @MainActor
    private func launchHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture", "-recordOpening.completed.v1", "YES", "-reducedMotion", "YES"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["room.navigation.play"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func assertSelectedDestination(_ selected: String, in app: XCUIApplication) {
        XCTAssertTrue(libraryElement("room.navigation", in: app).waitForExistence(timeout: 3))
        for destination in ["library", "player", "queue"] {
            let button = app.buttons["room.navigation." + destination]
            XCTAssertTrue(button.exists)
            XCTAssertEqual(button.isSelected, destination == selected,
                           "Only the current destination may carry the selected state.")
        }
        XCTAssertFalse(app.buttons["room.navigation.play"].isSelected)
    }

    @MainActor
    private func libraryElement(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func search(_ query: String, in app: XCUIApplication) {
        app.buttons["room.library.search"].tap()
        let field = app.textFields["room.library.query"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(query)
    }

    @MainActor
    private func queueIdentifiers(_ app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "room.queue.track."))
            .allElementsBoundByIndex.map(\.identifier)
    }

    @MainActor
    private func revealTurntableTools(in app: XCUIApplication) {
        let reveal = app.buttons["orbit.tools.reveal"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 3))
        reveal.tap()
        XCTAssertTrue(app.buttons["room.navigation.queue"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["orbit.rotate"].exists)
    }

    @MainActor
    private func waitUntilEnabled(_ element: XCUIElement) {
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 8), .completed)
    }

    @MainActor
    private func waitForLabel(_ label: String, of element: XCUIElement) {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 8), .completed)
    }

    @MainActor
    private func waitForValue(_ value: String, of element: XCUIElement) {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 8), .completed)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ stage: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Room home — " + stage + " — simulator"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
