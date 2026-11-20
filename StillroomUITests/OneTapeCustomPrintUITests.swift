import XCTest

final class OneTapeCustomPrintUITests: XCTestCase {
    @MainActor
    func testDrawingCanvasImportDialogPaperShareAndPlayerRender() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()

        let glass = app.buttons["tape.glass"]
        XCTAssertTrue(glass.waitForExistence(timeout: 10))
        glass.tap()

        let customizeButton = app.buttons["nav.customize"]
        XCTAssertTrue(customizeButton.waitForExistence(timeout: 5))
        customizeButton.tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.45)

        let printTab = app.buttons["customization.tab.print"]
        XCTAssertTrue(printTab.waitForExistence(timeout: 3))
        printTab.tap()

        let drawButton = app.buttons["customization.draw"]
        XCTAssertTrue(drawButton.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["customization.halftone"].exists)
        XCTAssertTrue(app.buttons["customization.getPaper"].exists)
        XCTAssertTrue(app.buttons["customization.importDrawing"].exists)
        captureAttachment("01-print-section")

        // Open PencilKit cassette canvas: Done & Undo must start disabled until ink exists.
        drawButton.tap()
        let doneButton = app.buttons["drawingCanvas.done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 6))
        let undoButton = app.buttons["drawingCanvas.undo"]
        XCTAssertFalse(doneButton.isEnabled)
        XCTAssertFalse(undoButton.isEnabled)
        Thread.sleep(forTimeInterval: 0.45)
        captureAttachment("02-drawing-canvas-empty")

        let centerCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        let targetCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.68, dy: 0.58))
        centerCoord.press(forDuration: 0.05, thenDragTo: targetCoord)
        Thread.sleep(forTimeInterval: 0.35)
        captureAttachment("02-drawing-canvas")

        XCTAssertTrue(doneButton.isEnabled)
        XCTAssertTrue(undoButton.isEnabled)
        undoButton.tap()
        Thread.sleep(forTimeInterval: 0.2)
        let redoButton = app.buttons["drawingCanvas.redo"]
        XCTAssertTrue(redoButton.isEnabled)
        redoButton.tap()
        Thread.sleep(forTimeInterval: 0.2)

        XCTAssertTrue(doneButton.isEnabled)
        doneButton.tap()

        // Verify saved tile appears in customization and updates main player cassette.
        let savedDrawingTile = app.staticTexts["画作 1"]
        XCTAssertTrue(savedDrawingTile.waitForExistence(timeout: 5))
        captureAttachment("03-print-section-with-drawing")

        // Open Halftone ("网点") and verify New Photo Print empty-state sheet before picking a photo.
        app.buttons["customization.halftone"].tap()
        let chooseImageButton = app.buttons["halftoneEditor.chooseImage"]
        XCTAssertTrue(chooseImageButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["新照片印花"].exists)
        XCTAssertTrue(app.staticTexts["让这盘磁带成为你的专属。"].exists)
        XCTAssertFalse(app.buttons["halftoneEditor.done"].isEnabled)
        Thread.sleep(forTimeInterval: 0.3)
        captureAttachment("06-halftone-empty")
        app.buttons["halftoneEditor.cancel"].tap()
        XCTAssertTrue(drawButton.waitForExistence(timeout: 4))

        // Open import chooser dialog.
        app.buttons["customization.importDrawing"].tap()
        let fromPhotos = app.buttons["从“照片”导入"]
        XCTAssertTrue(fromPhotos.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["从“文件”导入"].exists)
        if app.buttons["取消"].exists {
            app.buttons["取消"].tap()
        } else if app.otherElements["PopoverDismissRegion"].exists {
            app.otherElements["PopoverDismissRegion"].tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        }
        Thread.sleep(forTimeInterval: 0.3)

        // Trigger Get Paper share sheet and dismiss cleanly.
        app.buttons["customization.getPaper"].tap()
        let shareDismiss = app.buttons.matching(NSPredicate(format: "label == '关闭' OR label == 'Close' OR label == '关闭表单'"))
            .allElementsBoundByIndex
            .first(where: { $0.exists && $0.frame.minY < 540 })
        let previewVisible = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Cassette paper'")).firstMatch.waitForExistence(timeout: 5)
        if previewVisible || shareDismiss != nil {
            captureAttachment("04-get-paper-share")
            if let btn = app.buttons.matching(NSPredicate(format: "label == '关闭' OR label == 'Close' OR label == '关闭表单'"))
                .allElementsBoundByIndex
                .first(where: { $0.isHittable && $0.frame.minY < 540 }) {
                btn.tap()
            } else {
                // Tap dimmed area above the medium-detent Share Sheet.
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
            }
            Thread.sleep(forTimeInterval: 0.4)
        }

        // Return to player and verify custom drawing is rendered on cassette.
        let closeCust = app.buttons["customization.close"]
        if closeCust.waitForExistence(timeout: 4) {
            closeCust.tap()
        }
        Thread.sleep(forTimeInterval: 0.45)
        let glassValue = glass.value as? String ?? ""
        XCTAssertTrue(glassValue.contains("自定义画作"), "Expected player glass summary to reflect custom drawing, got: \(glassValue)")
        captureAttachment("05-player-with-custom-drawing")
    }

    @MainActor
    func testBuiltInDoodlesGridAll80ToggleAndCassetteRender() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()

        let glass = app.buttons["tape.glass"]
        XCTAssertTrue(glass.waitForExistence(timeout: 10))
        glass.tap()

        let customizeButton = app.buttons["nav.customize"]
        XCTAssertTrue(customizeButton.waitForExistence(timeout: 5))
        customizeButton.tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.45)

        let printTab = app.buttons["customization.tab.print"]
        XCTAssertTrue(printTab.waitForExistence(timeout: 3))
        printTab.tap()

        // Default Classic order starts with 无, 小狗, 毛毛虫, 跷跷板, 城市, 野生, 攀岩者.
        XCTAssertTrue(app.buttons["customization.doodle.dog"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["customization.doodle.climber"].exists)
        // Clear-exclusive Ant should not appear in Classic shell-filtered mode.
        XCTAssertFalse(app.buttons["customization.doodle.ants"].exists)
        captureAttachment("10-doodle-classic-grid")

        // Tap 攀岩者 (AI redrawn clean ink) and capture cassette preview.
        app.buttons["customization.doodle.climber"].tap()
        Thread.sleep(forTimeInterval: 0.25)
        app.buttons["customization.close"].tap()
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue((glass.value as? String ?? "").contains("攀岩者"))
        captureAttachment("11-player-doodle-climber")

        // Also tap 自行车 (Pelican riding a bicycle!) and capture cassette preview.
        customizeButton.tap()
        XCTAssertTrue(printTab.waitForExistence(timeout: 4))
        printTab.tap()
        let bicycle = app.buttons["customization.doodle.bicycle"]
        XCTAssertTrue(bicycle.waitForExistence(timeout: 3))
        bicycle.tap()
        Thread.sleep(forTimeInterval: 0.25)
        app.buttons["customization.close"].tap()
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue((glass.value as? String ?? "").contains("自行车"))
        captureAttachment("14-player-doodle-pelican-bicycle")

        // Re-open Print tab, scroll down to 小机器 (native 1024x1536 bundled stencil) and test it.
        customizeButton.tap()
        XCTAssertTrue(printTab.waitForExistence(timeout: 4))
        printTab.tap()
        let scroll = app.scrollViews["customization.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 3))
        let machines = app.buttons["customization.doodle.littleMachines"]
        for _ in 0..<5 where !machines.exists || !machines.isHittable {
            scroll.swipeUp()
        }
        XCTAssertTrue(machines.waitForExistence(timeout: 3))
        machines.tap()
        Thread.sleep(forTimeInterval: 0.25)
        app.buttons["customization.close"].tap()
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue((glass.value as? String ?? "").contains("小机器"))
        captureAttachment("12-player-doodle-little-machines")

        // Re-open, scroll back up, toggle 全部 80 款 and verify Ants becomes visible too.
        customizeButton.tap()
        XCTAssertTrue(printTab.waitForExistence(timeout: 4))
        printTab.tap()
        for _ in 0..<5 where !app.buttons["customization.doodle.scopeToggle"].isHittable {
            scroll.swipeDown()
        }
        let toggle = app.buttons["customization.doodle.scopeToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.tap()
        Thread.sleep(forTimeInterval: 0.3)
        captureAttachment("13-doodle-all80-expanded")
        for _ in 0..<4 where !app.buttons["customization.doodle.ants"].exists {
            scroll.swipeUp()
        }
        XCTAssertTrue(app.buttons["customization.doodle.ants"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func captureAttachment(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
