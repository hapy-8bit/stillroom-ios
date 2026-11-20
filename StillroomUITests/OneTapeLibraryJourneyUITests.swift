import XCTest

/// Browses the existing catalog without importing, selecting a song, changing
/// favorites or altering appearance. Physical runs require an explicit opt-in.
final class OneTapeLibraryJourneyUITests: XCTestCase {
    @MainActor
    func testEntranceShelfBrowsingAndAlbumReturnDoNotChangePlayback() throws {
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == "145AB0F0-7904-472C-9A3E-D78A78D5440B" else {
            throw XCTSkip("Use this task's isolated library QA simulator.")
        }
        #else
        guard ProcessInfo.processInfo.environment["ONE_TAPE_LIBRARY_USB_QA"] == "1" else {
            throw XCTSkip("Opt in only after checking the authorized iPhone uses wired transport.")
        }
        #endif
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["tape.lcd"].waitForExistence(timeout: 15))
        if app.alerts.firstMatch.exists { app.alerts.buttons["知道了"].tap() }
        wait("The existing library restores before recording the current selection") {
            !app.buttons["tape.lcd"].label.contains("还没有磁带")
        }
        let initialTitle = app.buttons["tape.lcd"].label
        let initialPlayLabel = app.buttons["tape.play"].label
        if !app.buttons["nav.library"].isHittable { app.buttons["tape.glass"].tap() }
        app.buttons["nav.library"].tap()
        let search = app.buttons["library.search"]
        wait("The entrance finishes with the toolbar reachable") { search.exists && search.isHittable }
        let crate = app.scrollViews["library.crate"]
        XCTAssertTrue(crate.waitForExistence(timeout: 10))
        capture("library-entry-albums-then-toolbar")
        crate.swipeUp(velocity: .slow)
        capture("library-shelf-scrolled-up")
        crate.swipeDown(velocity: .slow)
        capture("library-shelf-scrolled-down")
        let cases = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "crate.album."))
        let chosen = try XCTUnwrap(cases.allElementsBoundByIndex.first(where: { $0.isHittable }),
                                  "An existing album must be visible; never import user music for this check.")
        let title = chosen.label
        chosen.tap()
        let hero = app.buttons["album.hero"]
        wait("The backward cover roll settles and exposes detail controls") { hero.exists && hero.isHittable }
        XCTAssertTrue(hero.label.contains(title.components(separatedBy: " by ")[0]))
        XCTAssertTrue(app.buttons["album.back"].isHittable)
        capture("library-album-detail-full-background")
        let back = app.buttons["album.back"]
        let geometry = XCTAttachment(string: "hero: \(hero.frame); back: \(back.frame)")
        geometry.name = "library-detail-control-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
        app.buttons["album.back"].tap()
        wait("The shelf toolbar returns") { search.exists && search.isHittable }
        capture("library-returned-to-shelf")
        app.buttons["nav.nowPlaying"].tap()
        wait("Returning to the player keeps its original selection") {
            app.buttons["tape.lcd"].exists && app.buttons["tape.lcd"].label == initialTitle
        }
        XCTAssertEqual(app.buttons["tape.play"].label, initialPlayLabel)
        capture("library-player-selection-preserved")
    }


    @MainActor
    func testStackRepairBrowseAndOpenVisibleCases() throws {
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == "B59C8701-05C6-4612-B9B4-97D041DFDD88" else {
            throw XCTSkip("Use the isolated stack-repair fixture simulator.")
        }
        #else
        guard ProcessInfo.processInfo.environment["ONE_TAPE_LIBRARY_USB_QA"] == "1" else {
            throw XCTSkip("Requires the authorized wired iPhone.")
        }
        #endif
        continueAfterFailure = false
        let app = XCUIApplication()
        #if targetEnvironment(simulator)
        app.launchArguments = ["--one-tape-appearance-fixture"]
        #endif
        app.launch()
        XCTAssertTrue(app.buttons["tape.lcd"].waitForExistence(timeout: 15))
        if !app.buttons["nav.library"].isHittable { app.buttons["tape.glass"].tap() }
        app.buttons["nav.library"].tap()
        let menu = app.buttons["library.filter"]
        wait("The library toolbar becomes interactive") { menu.exists && menu.isHittable }
        // Layout is a presentation preference. Restore the original style on exit.
        let wasGrid = app.scrollViews["library.grid"].exists
        if wasGrid { selectLayout("叠放", app: app) }
        defer { if wasGrid && menu.exists { selectLayout("网格", app: app) } }
        let crate = app.scrollViews["library.crate"]
        XCTAssertTrue(crate.waitForExistence(timeout: 10))
        capture("stack-repair-01-entry")
        crate.swipeUp(velocity: .slow)
        capture("stack-repair-02-scrolled")
        let candidates = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "crate.album."))
        for position in [0.30, 0.53, 0.72] {
            let visible = candidates.allElementsBoundByIndex.filter {
                $0.isHittable && $0.frame.midY > app.frame.height * 0.20
                    && $0.frame.midY < app.frame.height * 0.80
            }
            let chosen = try XCTUnwrap(visible.min { abs($0.frame.midY - app.frame.height * position)
                < abs($1.frame.midY - app.frame.height * position) })
            let title = chosen.label.components(separatedBy: " by ")[0]
            chosen.tap()
            let hero = app.buttons["album.hero"]
            Thread.sleep(forTimeInterval: 1.7)
            if !hero.isHittable {
                let diagnostic = XCTAttachment(string: app.debugDescription)
                diagnostic.name = "stack-detail-readiness-\(position)"
                diagnostic.lifetime = .keepAlways
                add(diagnostic)
                capture("stack-detail-readiness-\(position)")
            }
            wait("The selected tape settles before the list accepts touches") {
                hero.exists && hero.isHittable && app.buttons["album.play"].isHittable
                    && app.buttons["album.back"].isHittable && app.buttons["album.back"].isEnabled
            }
            XCTAssertTrue(hero.label.hasPrefix(title))
            XCTAssertTrue(app.buttons["album.play"].isHittable)
            XCTAssertTrue(app.buttons["album.back"].isHittable)
            XCTAssertGreaterThan(hero.frame.width, hero.frame.height)
            capture("stack-repair-detail-\(position)")
            if position == 0.53 {
                hero.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            } else {
                app.buttons["album.back"].tap()
            }
            wait("The shelf returns to its retained position") { menu.exists && menu.isHittable }
        }
        capture("stack-repair-03-returned")
        selectLayout("网格", app: app)
        let grid = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "grid.album."))
        let chosen = try XCTUnwrap(grid.allElementsBoundByIndex.first { $0.isHittable })
        chosen.tap()
        let hero = app.buttons["album.hero"]
        wait("Grid detail remains usable") {
            hero.exists && hero.isEnabled && app.buttons["album.play"].isHittable
                && app.buttons["album.back"].isHittable && app.buttons["album.back"].isEnabled
        }
        XCTAssertGreaterThan(hero.frame.height, hero.frame.width)
        capture("stack-repair-04-grid-detail")
        app.buttons["album.back"].tap()
        wait("The grid toolbar returns") { menu.exists && menu.isHittable }
        if !wasGrid { selectLayout("叠放", app: app) }
    }


    @MainActor
    func testWiredDeliveryOpensLibraryWithoutChangingCatalog() throws {
        #if targetEnvironment(simulator)
        let wiredRun = false
        #else
        let wiredRun = ProcessInfo.processInfo.environment["ONE_TAPE_LIBRARY_USB_QA"] == "1"
        #endif
        try XCTSkipUnless(wiredRun, "Normal delivery check requires the authorized wired iPhone.")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        if app.buttons["opening.skip"].waitForExistence(timeout: 3) { app.buttons["opening.skip"].tap() }
        XCTAssertTrue(app.buttons["tape.lcd"].waitForExistence(timeout: 15))
        capture("stack-phone-normal-player")
        if !app.buttons["nav.library"].isHittable { app.buttons["tape.glass"].tap() }
        app.buttons["nav.library"].tap()
        let menu = app.buttons["library.filter"]
        wait("The installed normal app opens the library") { menu.exists && menu.isHittable }
        capture("stack-phone-normal-library")
        let candidates = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "crate.album."))
        if let chosen = candidates.allElementsBoundByIndex.first(where: { $0.isHittable }) {
            chosen.tap()
            wait("An existing device album exposes its list") { app.buttons["album.play"].isHittable }
            capture("stack-phone-normal-detail")
            app.buttons["album.back"].tap()
            wait("The phone shelf returns") { menu.exists && menu.isHittable }
        } else {
            XCTAssertTrue(app.staticTexts["library.empty"].exists || app.scrollViews["library.grid"].exists)
        }
        app.buttons["nav.nowPlaying"].tap()
        XCTAssertTrue(app.buttons["tape.lcd"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func selectLayout(_ title: String, app: XCUIApplication) {
        app.buttons["library.filter"].tap()
        let option = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        let id = title == "叠放" ? "library.crate" : "library.grid"
        wait("The requested display style finishes reloading") {
            app.scrollViews[id].exists && app.buttons["library.filter"].isHittable
                && !app.progressIndicators["library.reloading"].exists
        }
        // During the reveal AX exposes rows before SwiftUI enables touches.
        // Observe one settled frame after the existing 560ms reload gate.
        Thread.sleep(forTimeInterval: 0.8)
    }

    @MainActor
    private func wait(_ description: String, condition: @escaping () -> Bool) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 15), .completed, description)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
