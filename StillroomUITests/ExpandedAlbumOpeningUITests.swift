import XCTest

final class ExpandedAlbumOpeningUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testNineRealSleevesBrowseBothDirectionsPlayOnExplicitNeedleAndReturnPaused() {
        let app = XCUIApplication()
        app.launchArguments = ["--record-opening-preview", "-reducedMotion", "NO"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.otherElements["recordOpening.scene"].waitForExistence(timeout: 8))
        let viewport = app.windows.firstMatch.frame
        let references = referenceButtons(in: app)
        let identifiers = references.map(\.identifier)
        XCTAssertGreaterThanOrEqual(identifiers.count, 9)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        for id in ["sea", "window", "night"] {
            XCTAssertFalse(app.buttons["recordOpening.album." + id].exists)
        }
        capture(app, "01-nine-distinct-real-sleeves")

        let selections = [
            (id: "cz-dtv", album: "Direct to Video", direction: -1.0),
            (id: "cz-angiesss", album: "Angie's Sunday Service", direction: 1.0)
        ]
        for selection in selections {
            let album = app.buttons["recordOpening.album." + selection.id]
            bringIntoMiddle(album, direction: selection.direction, viewport: viewport, in: app)
            XCTAssertTrue(album.label.contains(selection.album))
            XCTAssertTrue(album.label.contains("Chris Zabriskie"))
            capture(app, "02-browsed-to-" + selection.id)
            // Tap the actual projected spine. There is no alternate play-button selection
            // path, so an occluding neighbor or a broken drag cannot pass this identity check.
            physicalTap(album, in: app)
            waitUntilEnabled(app.buttons["recordOpening.play"])
            let disc = element("recordOpening.disc", in: app)
            XCTAssertEqual(disc.label, selection.album + "，黑胶唱片")
            waitForValue("尚未播放", of: disc)
            let unexpectedPlayback = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", "正在播放"), object: disc)
            unexpectedPlayback.isInverted = true
            XCTAssertEqual(XCTWaiter.wait(for: [unexpectedPlayback], timeout: 1.2), .completed)
            XCTAssertFalse(app.buttons["recordOpening.continue"].exists)
            capture(app, "03-selected-" + selection.id + "-without-autoplay")
            if selection.id == "cz-dtv" {
                // Projected offscreen geometry can confuse AX hit-point heuristics. A real
                // window-coordinate touch plus the engine state verifies actual operability.
                physicalTap(app.buttons["recordOpening.play"], in: app)
                waitForValue("正在播放", of: disc)
                capture(app, "03a-new-original-recording-plays-after-explicit-needle")
            }
            physicalTap(app.buttons["recordOpening.back"], in: app)
            XCTAssertTrue(app.otherElements["recordOpening.shelf"].waitForExistence(timeout: 3))
        }

        physicalTap(app.buttons["recordOpening.skip"], in: app)
        // An explicit play commits this journey to the player. Library remains a peer tab.
        XCTAssertTrue(app.otherElements["room.navigation"].waitForExistence(timeout: 5))
        app.buttons["room.navigation.library"].tap()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 5))
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
        app.buttons["room.library.search"].tap()
        let query = app.textFields["room.library.query"]
        XCTAssertTrue(query.waitForExistence(timeout: 3))
        query.tap()
        query.typeText("Direct to Video")
        let libraryAlbum = app.buttons["room.library.album.cz-dtv"]
        XCTAssertTrue(libraryAlbum.waitForExistence(timeout: 5))
        XCTAssertTrue(libraryAlbum.label.contains("Direct to Video"))
        XCTAssertTrue(libraryAlbum.label.contains("Chris Zabriskie"))
        libraryAlbum.tap()
        XCTAssertTrue(app.scrollViews["room.library.detail"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["room.library.detail.title"].label, "Direct to Video")
        XCTAssertTrue(app.buttons["room.library.track.cz-dtv"].exists)
        waitForLabel("播放", of: app.buttons["room.navigation.play"])
        capture(app, "04-added-real-album-searches-in-normal-library")
    }

    @MainActor
    private func bringIntoMiddle(_ album: XCUIElement, direction: Double, viewport: CGRect, in app: XCUIApplication) {
        let middle = (viewport.minY + viewport.height * 0.25)...(viewport.minY + viewport.height * 0.65)
        for _ in 0..<6 {
            if album.exists, middle.contains(album.frame.midY) { return }
            browse(direction: direction, viewport: viewport, in: app)
        }
        XCTAssertTrue(album.exists)
        XCTAssertTrue(middle.contains(album.frame.midY), "The requested sleeve must move out of the header/footer into the selection area.")
    }

    @MainActor
    private func browse(direction: Double, viewport: CGRect, in app: XCUIApplication) {
        // Start on an actual visible sleeve, not a guessed gap in the zero-height stack.
        // Each bounded release advances at most two rows; repeated gestures reach the ends.
        let middleY = viewport.midY
        let candidates = referenceButtons(in: app).filter {
            (viewport.minY + viewport.height * 0.25...viewport.minY + viewport.height * 0.65).contains($0.frame.midY)
        }
        guard let anchor = candidates.min(by: { abs($0.frame.midY - middleY) < abs($1.frame.midY - middleY) }) else {
            XCTFail("No visible real sleeve can own the browsing gesture.")
            return
        }
        // Index-bound AX queries can change identity when z-order changes. Freeze the stable
        // ID's screen point before dragging; never resolve an endpoint from a moving sleeve.
        let before = anchor.frame.midY
        let point = anchor.frame
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: point.midX - viewport.minX, dy: point.midY - viewport.minY))
        let endY = point.midY - viewport.minY + viewport.height * 0.23 * direction
        XCTAssertGreaterThan(endY, 0)
        XCTAssertLessThan(endY, viewport.height)
        let end = origin.withOffset(CGVector(dx: point.midX - viewport.minX, dy: endY))
        start.press(forDuration: 0.12, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(!anchor.exists || abs(anchor.frame.midY - before) > 20,
                      "A physical browse must move the stack, rather than silently selecting or doing nothing.")
    }

    @MainActor
    private func physicalTap(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let viewport = app.windows.firstMatch.frame
        let point = CGPoint(x: element.frame.midX, y: element.frame.midY)
        XCTAssertTrue(viewport.contains(point), "A real touch must stay within the physical window.")
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x - viewport.minX, dy: point.y - viewport.minY)).tap()
    }

    @MainActor
    private func referenceButtons(in app: XCUIApplication) -> [XCUIElement] {
        let identifiers = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recordOpening.album.cz-"))
            .allElementsBoundByIndex.map(\.identifier)
        return identifiers.sorted().map { app.buttons[$0] }
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
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
        attachment.name = "Expanded real albums — " + stage + " — simulator"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
