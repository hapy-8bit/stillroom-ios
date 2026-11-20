import XCTest

final class CraftPhotoJourneyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    /// Root seeds only the project's own SeaCover in the dedicated simulator's Photos library.
    /// The system picker is exercised normally; this case never grants whole-library access.
    @MainActor func testSelectPhotoCancelCropThenFrameAndSaveReadyRecord() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture", "-reducedMotion", "YES"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        let recordTitle = "FIELD NOTES " + String(UUID().uuidString.prefix(5))
        XCTAssertTrue(app.buttons["orbit.crafted"].waitForExistence(timeout: 10))
        app.buttons["orbit.crafted"].tap()
        XCTAssertTrue(app.buttons["craft.cabinet.create"].waitForExistence(timeout: 5))
        app.buttons["craft.cabinet.create"].tap()
        XCTAssertTrue(app.buttons["craft.select.track.sea"].waitForExistence(timeout: 5))
        app.buttons["craft.select.track.sea"].tap()
        app.buttons["craft.composer.next"].tap()
        app.buttons["craft.composer.next"].tap()
        let title = app.descendants(matching: .any).matching(identifier: "craft.cover.title").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 4))
        reveal(title, app: app); title.tap(); title.typeText(recordTitle)
        XCTAssertFalse(app.buttons["craft.composer.play"].exists, "Typing must leave the field clear of the production footer.")
        capture(app, "00-title-keyboard-layout")
        let keyboardDone = app.buttons["craft.cover.keyboardDone"]
        if keyboardDone.waitForExistence(timeout: 2) { keyboardDone.tap() }
        let design = app.buttons["craft.cover.design.photo"]
        reveal(design, app: app); design.tap()
        let ready = app.buttons["craft.composer.saveReady"]
        XCTAssertFalse(ready.isEnabled, "A photo design cannot be ready without a confirmed photo.")
        chooseFirstSeededPhoto(app)
        XCTAssertTrue(app.buttons["craft.photo.crop.cancel"].waitForExistence(timeout: 12))
        capture(app, "01-crop-before-cancel")
        app.buttons["craft.photo.crop.cancel"].tap()
        XCTAssertTrue(ready.waitForExistence(timeout: 5))
        XCTAssertFalse(ready.isEnabled, "Cancelling the crop must not commit its photo.")
        XCTAssertEqual(title.value as? String, recordTitle)
        chooseFirstSeededPhoto(app)
        let viewport = app.descendants(matching: .any).matching(identifier: "craft.photo.viewport").firstMatch
        XCTAssertTrue(viewport.waitForExistence(timeout: 12))
        let originalScale = viewport.value as? String
        let zoom = app.sliders["craft.photo.zoom"]
        reveal(zoom, app: app); zoom.adjust(toNormalizedSliderPosition: 0.35)
        XCTAssertNotEqual(viewport.value as? String, originalScale)
        let right = app.buttons["craft.photo.move.right"]
        reveal(right, app: app); right.tap()
        capture(app, "02-adjusted-photo-frame")
        let reset = app.buttons["craft.photo.reset"]
        reveal(reset, app: app); reset.tap()
        XCTAssertEqual(viewport.value as? String, originalScale)
        zoom.adjust(toNormalizedSliderPosition: 0.2)
        // Move back to the visible viewport, then exercise its actual drag gesture as well as controls.
        reveal(viewport, app: app)
        let start = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.45)))
        capture(app, "03-final-square-crop")
        app.buttons["craft.photo.crop.use"].tap()
        let enabled = NSPredicate(format: "exists == true AND enabled == true")
        expectation(for: enabled, evaluatedWith: ready)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(design.isSelected)
        capture(app, "04-confirmed-photo-sleeve")
        ready.tap()
        XCTAssertTrue(app.buttons["craft.cabinet.create"].waitForExistence(timeout: 8))
        let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "craft.cabinet.record.", recordTitle)).firstMatch
        reveal(record, app: app)
        XCTAssertTrue(record.exists)
        capture(app, "05-saved-photo-record")
        app.terminate()
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.buttons["orbit.crafted"].waitForExistence(timeout: 8))
        app.buttons["orbit.crafted"].tap()
        reveal(record, app: app)
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(app.buttons["sleeve.play"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["sleeve.title"].label, recordTitle)
        app.buttons["sleeve.flip"].tap(); app.buttons["sleeve.flip"].tap()
        capture(app, "06-cold-restored-photo-sleeve")
        // Reopening the editor also proves that the saved photo is available as an existing cover,
        // rather than merely retaining the photo design flag or an in-memory crop preview.
        app.buttons["sleeve.edit"].tap()
        XCTAssertTrue(app.buttons["craft.composer.next"].waitForExistence(timeout: 6))
        app.buttons["craft.composer.next"].tap(); app.buttons["craft.composer.next"].tap()
        XCTAssertTrue(design.waitForExistence(timeout: 4))
        XCTAssertTrue(design.isSelected)
        XCTAssertTrue(ready.isEnabled)
        XCTAssertEqual(title.value as? String, recordTitle)
        capture(app, "07-persisted-photo-cover-editor")
        app.buttons["craft.composer.close"].tap()
        XCTAssertTrue(app.buttons["craft.cabinet.create"].waitForExistence(timeout: 5))
        reveal(record, app: app); record.tap()
        XCTAssertTrue(app.buttons["sleeve.edit"].waitForExistence(timeout: 4))
        app.buttons["sleeve.edit"].tap()
        XCTAssertTrue(app.buttons["craft.composer.next"].waitForExistence(timeout: 5), "The same record can be edited twice without recreating its data.")
        app.buttons["craft.composer.close"].tap()
    }

    @MainActor private func chooseFirstSeededPhoto(_ app: XCUIApplication) {
        let button = app.buttons["craft.photo.choose"]
        reveal(button, app: app)
        capture(app, "visible-photo-chooser")
        button.tap()
        let photos = app.buttons.matching(NSPredicate(format: "label IN %@", ["照片", "Photos"])).firstMatch
        let collections = app.buttons.matching(NSPredicate(format: "label IN %@", ["精选集", "Collections"])).firstMatch
        XCTAssertTrue(photos.waitForExistence(timeout: 5), "The native Photos picker must be presented before selecting a photo.")
        XCTAssertTrue(collections.exists)
        capture(app, "system-photo-picker")
        let firstPhoto = app.collectionViews.cells.firstMatch
        if firstPhoto.waitForExistence(timeout: 2) { firstPhoto.tap() }
        else {
            // iOS27 exposes native photo tiles as images, without collection-cell nodes.
            let tile = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
            XCTAssertTrue(tile.waitForExistence(timeout: 5))
            tile.tap()
        }
        let crop = app.buttons["craft.photo.crop.use"]
        if !crop.waitForExistence(timeout: 3) {
            let confirm = app.buttons.matching(NSPredicate(format: "label IN %@", ["Add", "添加", "完成", "Done"])).firstMatch
            if confirm.waitForExistence(timeout: 3), confirm.isHittable { confirm.tap() }
        }
    }

    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        revealCraftedControl(element, app: app)
    }

    @MainActor private func edgeScroll(_ app: XCUIApplication, upward: Bool) {
        scrollCraftedContent(app, upward: upward)
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "craft-photo-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
