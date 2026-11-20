import XCTest

final class RealAlbumUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let failure = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            failure.name = "Real albums — failure — " + name
            failure.lifetime = .keepAlways
            add(failure)
        }
    }

    @MainActor
    func testReferenceAlbumsHaveRealCreditsAndPlayThroughTheSharedQueue() {
        let app = XCUIApplication()
        app.launchArguments = ["-recordOpening.completed.v1", "YES", "-reducedMotion", "YES"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 8))
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
        assertNoLegacyAlbums(in: app)
        capture(app, "01-default-reference-album-home")

        // Imported music remains in this simulator. Inspect the two supplied reference albums
        // explicitly instead of requiring the user's whole library to contain only two albums.
        let albums = [
            (id: "cz-cylinder-one", album: "Cylinders", song: "Cylinder One", year: "2014", shot: "cylinders"),
            (id: "cz-heliograph", album: "Divider", song: "Heliograph", year: "2011", shot: "divider")
        ]
        for reference in albums {
            search(reference.album, in: app)
            let album = app.buttons["room.library.album." + reference.id]
            XCTAssertTrue(album.waitForExistence(timeout: 5))
            XCTAssertTrue(album.label.contains(reference.album))
            XCTAssertTrue(album.label.contains("Chris Zabriskie"))
            album.tap()

            let detail = app.scrollViews["room.library.detail"]
            XCTAssertTrue(detail.waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["room.library.detail.title"].label, reference.album)
            let song = app.buttons["room.library.track." + reference.id]
            XCTAssertTrue(song.waitForExistence(timeout: 5))
            XCTAssertTrue(song.label.contains(reference.song))
            XCTAssertTrue(song.label.contains("Chris Zabriskie"))
            let credit = element("room.library.reference.credit", in: app)
            XCTAssertTrue(credit.staticTexts[reference.album + " · " + reference.year].exists)
            let creditArtist = credit.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "Chris Zabriskie")).firstMatch
            reveal(creditArtist, in: detail)
            let license = element("room.library.reference.license", in: app)
            XCTAssertTrue(license.exists)
            XCTAssertEqual(license.label, "Music licensed under CC BY 4.0")
            waitForLabel("播放", of: app.buttons["room.navigation.play"])
            capture(app, "02-" + reference.shot + "-real-metadata-and-credit")

            let play = app.buttons["room.library.detail.play"]
            reveal(play, in: detail, upward: false)
            waitUntilEnabled(play)
            play.tap()
            XCTAssertTrue(app.otherElements["orbit.turntable"].waitForExistence(timeout: 5))
            // These labels come from the authoritative PlaybackSnapshot, after real engine play.
            // A selected card or an animation phase alone must not satisfy this check.
            waitForLabel("暂停", of: app.buttons["orbit.play"])
            XCTAssertFalse(app.buttons["room.navigation.play"].exists)
            XCTAssertTrue(app.buttons["orbit.openPlayer"].label.contains(reference.song))

            revealTools(in: app)
            waitForLabel("暂停", of: app.buttons["room.navigation.play"])
            XCTAssertFalse(app.buttons["orbit.play"].exists)
            app.buttons["room.navigation.queue"].tap()
            XCTAssertTrue(app.otherElements["room.queue"].waitForExistence(timeout: 5))
            let queued = app.buttons["room.queue.track." + reference.id]
            waitForValue("当前歌曲，正在播放", of: queued)
            XCTAssertTrue(queued.label.contains(reference.song))
            XCTAssertTrue(queued.label.contains("Chris Zabriskie"))
            XCTAssertEqual(queueIdentifiers(app), ["room.queue.track." + reference.id])
            capture(app, "03-" + reference.shot + "-shared-live-queue")

            app.buttons["room.navigation.player"].tap()
            XCTAssertTrue(app.otherElements["orbit.turntable"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["orbit.openPlayer"].label.contains(reference.song))
            waitForLabel("暂停", of: app.buttons["orbit.play"])
            XCTAssertFalse(app.buttons["room.navigation.play"].exists)
            app.buttons["orbit.play"].tap()
            waitForLabel("播放", of: app.buttons["orbit.play"])
            capture(app, "04-" + reference.shot + "-matching-turntable-paused")
            revealTools(in: app)
            waitForLabel("播放", of: app.buttons["room.navigation.play"])
            app.buttons["room.navigation.library"].tap()
            XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 5))
        }
        assertNoLegacyAlbums(in: app)
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
    }

    @MainActor
    func testFirstOpeningSelectsRealAlbumsWithoutStartingPlayback() {
        let app = XCUIApplication()
        app.launchArguments = ["-recordOpening.completed.v1", "NO", "-reducedMotion", "NO"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.otherElements["recordOpening.scene"].waitForExistence(timeout: 8))
        for id in ["sea", "window", "night"] {
            XCTAssertFalse(app.buttons["recordOpening.album." + id].exists)
        }
        capture(app, "05-first-opening-real-album-list")

        var centeredReference: Int?
        for reference in [("cz-cylinder-one", "Cylinders"), ("cz-heliograph", "Divider")] {
            let album = app.buttons["recordOpening.album." + reference.0]
            bringOpeningAlbumIntoMiddle(album, centeredReference: &centeredReference, in: app)
            XCTAssertTrue(album.waitForExistence(timeout: 5))
            tapOpeningControl(album, in: app)
            waitUntilEnabled(app.buttons["recordOpening.play"])
            let disc = element("recordOpening.disc", in: app)
            XCTAssertEqual(disc.label, reference.1 + "，黑胶唱片")
            waitForValue("尚未播放", of: disc)
            let unexpectedPlay = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", "正在播放"), object: disc)
            unexpectedPlay.isInverted = true
            XCTAssertEqual(XCTWaiter.wait(for: [unexpectedPlay], timeout: 1.2), .completed)
            XCTAssertFalse(app.buttons["recordOpening.continue"].exists)
            capture(app, "06-opening-" + reference.0 + "-selected-without-autoplay")
            tapOpeningControl(app.buttons["recordOpening.back"], in: app)
            XCTAssertTrue(album.waitForExistence(timeout: 3))
        }
        tapOpeningControl(app.buttons["recordOpening.skip"], in: app)
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 5))
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
        assertNoLegacyAlbums(in: app)
        capture(app, "07-real-opening-skipped-main-remains-paused")
    }

    @MainActor
    private func bringOpeningAlbumIntoMiddle(_ album: XCUIElement, centeredReference: inout Int?,
                                            in app: XCUIApplication) {
        let catalog = ["cz-cylinder-one", "cz-heliograph", "cz-angiesss", "cz-src", "cz-ababab",
                       "cz-asleep", "cz-neptuneflux", "cz-reappear", "cz-dtv"]
        let prefix = "recordOpening.album."
        guard let target = catalog.firstIndex(where: { prefix + $0 == album.identifier }) else {
            XCTFail("The requested sleeve is not a supplied real album.")
            return
        }
        let viewport = app.windows.firstMatch.frame
        let middle = (viewport.minY + viewport.height * 0.25)...(viewport.minY + viewport.height * 0.65)
        if centeredReference == nil {
            let candidates = catalog.indices.filter { index in
                let spine = app.buttons[prefix + catalog[index]]
                return spine.exists && middle.contains(spine.frame.midY)
            }
            centeredReference = candidates.min { left, right in
                abs(app.buttons[prefix + catalog[left]].frame.midY - viewport.midY) <
                    abs(app.buttons[prefix + catalog[right]].frame.midY - viewport.midY)
            }
        }
        // Keep the observed identity across selections, but never infer the release's result
        // from touch distance: the app uses predicted translation. Record actual row frames
        // and scene controls after every drag so a failed return to the shelf remains visible.
        let factor = min(1, max(0, (min(viewport.width, viewport.height) - 375) / 459))
        let stride = 87 + 41 * factor
        for attempt in 0..<6 {
            guard let current = centeredReference else {
                XCTFail("No visible real sleeve establishes the opening stack's center.")
                return
            }
            if current == target { break }
            let anchor = app.buttons[prefix + catalog[current]]
            XCTAssertTrue(anchor.exists && middle.contains(anchor.frame.midY))
            let frame = anchor.frame
            let step = min(2, abs(target - current))
            let direction: CGFloat = target < current ? 1 : -1
            let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: frame.midX - viewport.minX, dy: frame.midY - viewport.minY))
            let end = origin.withOffset(CGVector(dx: frame.midX - viewport.minX,
                dy: frame.midY - viewport.minY + stride * CGFloat(step) * direction))
            captureOpeningBrowse(app, catalog: catalog,
                stage: "before-\(target)-\(attempt)", previousCenter: current,
                requestedTranslation: stride * CGFloat(step) * direction)
            start.press(forDuration: 0.12, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
            centeredReference = captureOpeningBrowse(app, catalog: catalog,
                stage: "after-\(target)-\(attempt)", previousCenter: current,
                requestedTranslation: stride * CGFloat(step) * direction)
        }
        XCTAssertEqual(centeredReference, target)
        XCTAssertTrue(album.exists && middle.contains(album.frame.midY))
    }

    @MainActor @discardableResult
    private func captureOpeningBrowse(_ app: XCUIApplication, catalog: [String], stage: String,
                                      previousCenter: Int, requestedTranslation: CGFloat) -> Int? {
        capture(app, "browse-" + stage)
        let viewport = app.windows.firstMatch.frame
        let middle = (viewport.minY + viewport.height * 0.25)...(viewport.minY + viewport.height * 0.65)
        var rows: [(index: Int, frame: CGRect)] = []
        var lines = ["viewport=\(viewport)", "previousObservedIndex=\(previousCenter)",
                     "requestedTranslationY=\(requestedTranslation) (predicted translation is unknown)"]
        for (index, id) in catalog.enumerated() {
            let spine = app.buttons["recordOpening.album." + id]
            guard spine.exists else { lines.append("\(id): absent"); continue }
            let frame = spine.frame
            rows.append((index, frame))
            lines.append("\(id): frame=\(frame), intersectsWindow=\(frame.intersects(viewport))")
        }
        let observed = rows.filter { middle.contains($0.frame.midY) }.min {
            abs($0.frame.midY - viewport.midY) < abs($1.frame.midY - viewport.midY)
        }?.index
        lines.append("nearestVisibleAXSpine=\(observed.map { catalog[$0] } ?? "none")")
        for id in ["recordOpening.back", "recordOpening.play", "recordOpening.continue", "recordOpening.disc"] {
            let control = element(id, in: app)
            if control.exists {
                lines.append("\(id): label=\(control.label), value=\(String(describing: control.value)), frame=\(control.frame)")
            } else { lines.append("\(id): absent") }
        }
        let details = XCTAttachment(string: lines.joined(separator: "\n"))
        details.name = "Opening browse frames — " + stage
        details.lifetime = .keepAlways
        add(details)
        return observed
    }

    @MainActor
    private func tapOpeningControl(_ element: XCUIElement, in app: XCUIApplication) {
        // Use the physical window, since projected/retired sleeves can expand the AX app frame
        // beyond its clipped screen and make the AX isHittable heuristic disagree with touch.
        let viewport = app.windows.firstMatch.frame
        let point = CGPoint(x: element.frame.midX, y: element.frame.midY)
        XCTAssertTrue(viewport.contains(point))
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x - viewport.minX, dy: point.y - viewport.minY)).tap()
    }

    @MainActor
    private func assertNoLegacyAlbums(in app: XCUIApplication) {
        for id in ["sea", "window", "night"] {
            XCTAssertFalse(app.buttons["room.library.album." + id].exists)
        }
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
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in scroll: XCUIElement, upward: Bool = true) {
        for _ in 0..<4 {
            if element.exists && element.isHittable { return }
            if upward { scroll.swipeUp() } else { scroll.swipeDown() }
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func queueIdentifiers(_ app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "room.queue.track."))
            .allElementsBoundByIndex.map(\.identifier)
    }

    @MainActor
    private func revealTools(in app: XCUIApplication) {
        let reveal = app.buttons["orbit.tools.reveal"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 3))
        reveal.tap()
        XCTAssertTrue(app.buttons["room.navigation.queue"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func waitUntilEnabled(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 8))
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
    }

    @MainActor
    private func waitForLabel(_ label: String, of element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 8), .completed)
    }

    @MainActor
    private func waitForValue(_ value: String, of element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 8), .completed)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ stage: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Real albums — " + stage + " — simulator"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
