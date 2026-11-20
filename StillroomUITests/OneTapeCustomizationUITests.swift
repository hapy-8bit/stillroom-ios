import XCTest

final class OneTapeCustomizationUITests: XCTestCase {
    @MainActor
    func testRestoredPrintControlsPersistAndShareTheSlidingGlassState() {
        continueAfterFailure = false
        let app = launch(reset: true)
        let glass = app.buttons["tape.glass"]
        XCTAssertTrue(glass.waitForExistence(timeout: 10))
        openPrint(app)
        let glassPicker = app.segmentedControls["customization.glass"]
        let brandPicker = app.segmentedControls["customization.brandPrint"]
        revealControl(glassPicker, in: app)
        XCTAssertTrue(glassPicker.buttons["打开"].isSelected)
        glassPicker.buttons["关闭"].tap()
        revealControl(brandPicker, in: app)
        brandPicker.buttons["关"].tap()
        XCTAssertTrue(brandPicker.buttons["关"].isSelected)
        screenshot("restored-print-controls-off")
        app.buttons["customization.close"].tap()
        expect(glass, contains: "已关闭")
        expect(glass, contains: "无品牌印字")
        screenshot("restored-print-brand-off-glass-closed")

        openPrint(app)
        let dog = app.buttons["customization.doodle.dog"]
        revealControl(dog, in: app)
        dog.tap()
        revealControl(brandPicker, in: app)
        XCTAssertTrue(brandPicker.buttons["关"].isSelected)
        XCTAssertTrue(app.staticTexts["开启品牌印字会替换当前插画。"].exists)
        app.buttons["customization.close"].tap()
        expect(glass, contains: "dog")
        expect(glass, contains: "无品牌印字")
        screenshot("restored-print-illustration-with-brand-off")

        openPrint(app)
        revealControl(brandPicker, in: app)
        brandPicker.buttons["开"].tap()
        XCTAssertTrue(brandPicker.buttons["开"].isSelected)
        XCTAssertEqual(app.buttons["customization.doodle.none"].value as? String, "已选择")
        app.buttons["customization.close"].tap()
        expect(glass, contains: "One Tape 印字")
        expect(glass, contains: "已关闭")
        screenshot("restored-print-brand-on")
        app.terminate()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        app.launch()
        expect(glass, contains: "已关闭")
        expect(glass, contains: "One Tape 印字")
        openPrint(app)
        revealControl(glassPicker, in: app)
        XCTAssertTrue(glassPicker.buttons["关闭"].isSelected)
        revealControl(brandPicker, in: app)
        XCTAssertTrue(brandPicker.buttons["开"].isSelected)
        screenshot("restored-print-controls-cold-restored")
        revealControl(glassPicker, in: app)
        glassPicker.buttons["打开"].tap()
        app.buttons["customization.close"].tap()
        expect(glass, contains: "已打开")
        let bottom = glass.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        let top = glass.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        bottom.press(forDuration: 0.1, thenDragTo: top)
        expect(glass, contains: "已关闭")
        openPrint(app)
        revealControl(glassPicker, in: app)
        XCTAssertTrue(glassPicker.buttons["关闭"].isSelected)
        screenshot("restored-print-controls-follow-glass-gesture")
        app.buttons["customization.close"].tap()
    }

    @MainActor
    private func openPrint(_ app: XCUIApplication) {
        let navigation = app.buttons["nav.customize"]
        // A visible HUD may be just about to expire after the glass gesture.
        // Normalize it through a fresh toggle so AX lookup cannot race its
        // six-second timeout between an existence query and the actual tap.
        app.buttons["tape.glass"].tap()
        Thread.sleep(forTimeInterval: 0.45)
        if !navigation.exists || !navigation.isHittable {
            app.buttons["tape.glass"].tap()
            Thread.sleep(forTimeInterval: 0.45)
        }
        XCTAssertTrue(navigation.exists)
        XCTAssertTrue(navigation.isHittable)
        navigation.tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.45)
        app.buttons["customization.tab.print"].tap()
    }

    @MainActor
    private func revealControl(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews["customization.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 4))
        for _ in 0..<8 {
            let top = scroll.frame.minY + 16
            let hud = app.buttons["nav.customize"].frame.minY
            let bottom = min(scroll.frame.maxY, hud) - 20
            if element.exists, element.isHittable,
               element.frame.midY > top, element.frame.maxY < bottom { return }
            let down = element.exists && element.frame.midY < top
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: app.frame.width / 2,
                dy: (down ? top + 12 : bottom - 12) - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: app.frame.width / 2,
                dy: (down ? bottom - 12 : top + 12) - app.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("Restored print control is not reachable above the navigation")
    }

    @MainActor
    private func expect(_ element: XCUIElement, contains text: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value CONTAINS %@", text), evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testObservedPrintsApplyPersistAndKeepTheScreenUnchanged() {
        let app = launch(reset: true)
        let glass = app.buttons["tape.glass"]
        XCTAssertTrue(glass.waitForExistence(timeout: 10))
        glass.tap()
        app.buttons["nav.customize"].tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.45)
        app.buttons["customization.tab.print"].tap()
        let dog = app.buttons["customization.doodle.dog"]
        XCTAssertTrue(dog.waitForExistence(timeout: 3))
        screenshot("print-01-observed-page")
        XCTAssertTrue(app.segmentedControls["customization.glass"].exists)
        XCTAssertTrue(app.segmentedControls["customization.brandPrint"].exists)
        for tool in ["draw", "halftone", "getPaper", "importDrawing"] {
            app.buttons["customization.\(tool)"].tap()
            XCTAssertTrue(app.alerts["绘画与网点照片"].waitForExistence(timeout: 3))
            app.alerts.buttons["知道了"].tap()
            XCTAssertFalse(app.buttons["studio.close"].exists)
        }
        for style in ["dog", "caterpillar", "seesaw", "city", "wild"] {
            let choice = app.buttons["customization.doodle.\(style)"]
            for _ in 0..<3 where !choice.isHittable { app.swipeUp() }
            XCTAssertTrue(choice.isHittable)
            choice.tap()
            XCTAssertEqual(choice.value as? String, "已选择")
            app.buttons["customization.close"].tap()
            XCTAssertTrue((glass.value as? String ?? "").contains(style))
            XCTAssertTrue((glass.value as? String ?? "").contains("无品牌印字"))
            XCTAssertEqual(app.buttons["tape.lcd"].value as? String, "lcd")
            XCTAssertEqual(app.buttons["tape.play"].label, "播放")
            Thread.sleep(forTimeInterval: 0.45)
            screenshot("print-applied-\(style)")
            app.buttons["nav.customize"].tap()
            XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 3))
            Thread.sleep(forTimeInterval: 0.45)
        }
        app.buttons["customization.close"].tap()
        app.terminate()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(glass.waitForExistence(timeout: 10))
        XCTAssertTrue((glass.value as? String ?? "").contains("wild"))
        XCTAssertTrue((glass.value as? String ?? "").contains("无品牌印字"))
        XCTAssertEqual(app.buttons["tape.lcd"].value as? String, "lcd")
        glass.tap()
        app.buttons["nav.customize"].tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.45)
        app.buttons["customization.tab.print"].tap()
        app.buttons["customization.doodle.none"].tap()
        app.buttons["customization.close"].tap()
        XCTAssertTrue((glass.value as? String ?? "").contains("One Tape 印字"))
        screenshot("print-removed-brand-restored")
    }

    @MainActor
    func testFourTabsApplyStylesAndSurviveCloseAndColdLaunch() {
        let app = launch(reset: true)
        let glass = app.buttons["tape.glass"]
        XCTAssertTrue(glass.waitForExistence(timeout: 10))
        XCTAssertTrue((glass.value as? String ?? "").contains("One Tape 印字"))
        screenshot("01-one-tape-brand-print")
        glass.tap()
        app.buttons["nav.customize"].tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["studio.close"].exists)
        screenshot("02-customize-tape")
        let clear = app.buttons["customization.tape.clear"]
        let scroll = app.scrollViews["customization.scroll"]
        for _ in 0..<4 where !clear.isHittable { scroll.swipeUp() }
        XCTAssertTrue(clear.waitForExistence(timeout: 3))
        screenshot("02b-customize-tape-scrolled")
        clear.tap()
        XCTAssertEqual(clear.value as? String, "已选择")
        app.buttons["customization.tab.print"].tap()
        let dog = app.buttons["customization.doodle.dog"]
        if !dog.isHittable { app.swipeUp() }
        XCTAssertTrue(dog.waitForExistence(timeout: 3))
        dog.tap()
        XCTAssertEqual(dog.value as? String, "已选择")
        screenshot("03-customize-print")
        app.buttons["customization.tab.body"].tap()
        app.buttons["customization.body.graphite"].tap()
        app.buttons["customization.bodyColor.green"].tap()
        screenshot("04-customize-body")
        app.buttons["customization.tab.screen"].tap()
        let water = app.buttons["customization.screen.water"]
        for _ in 0..<4 where !water.isHittable { app.swipeUp() }
        XCTAssertTrue(water.isHittable)
        water.tap()
        screenshot("05-customize-screen")
        app.buttons["customization.close"].tap()
        XCTAssertTrue(glass.waitForExistence(timeout: 3))
        XCTAssertTrue((glass.value as? String ?? "").contains("透明"))
        XCTAssertTrue((glass.value as? String ?? "").contains("dog"))
        XCTAssertEqual(app.buttons["tape.lcd"].value as? String, "water")
        XCTAssertEqual(app.buttons["tape.play"].label, "播放")
        screenshot("06-applied-customization")
        app.terminate()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(glass.waitForExistence(timeout: 10))
        XCTAssertTrue((glass.value as? String ?? "").contains("透明"))
        XCTAssertTrue((glass.value as? String ?? "").contains("dog"))
        XCTAssertEqual(app.buttons["tape.lcd"].value as? String, "water")
        XCTAssertEqual(app.buttons["tape.play"].label, "播放")
    }

    @MainActor
    func testStudioClosesBackToCustomizationAndNavigationStillWorks() {
        let app = launch(reset: true)
        XCTAssertTrue(app.buttons["tape.glass"].waitForExistence(timeout: 10))
        app.buttons["tape.glass"].tap()
        app.buttons["nav.customize"].tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 5))
        // AX can expose the destination frame before the 0.4-second drawer
        // move finishes. Let that visible transition settle before touch input.
        Thread.sleep(forTimeInterval: 0.45)
        app.buttons["customization.tab.screen"].tap()
        XCTAssertTrue(app.buttons["customization.screen.lcd"].waitForExistence(timeout: 3))
        let studio = app.buttons["customization.studio"]
        for _ in 0..<4 where !studio.isHittable { app.swipeUp() }
        studio.tap()
        XCTAssertTrue(app.buttons["studio.close"].waitForExistence(timeout: 5))
        screenshot("07-corrected-studio-montage")
        app.buttons["studio.close"].tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["customization.screen.lcd"].exists)
        XCTAssertEqual(app.buttons["customization.tab.screen"].value as? String, "已选择")
        app.buttons["nav.library"].tap()
        XCTAssertTrue(app.buttons["library.search"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["customization.close"].exists)
    }

    @MainActor
    private func launch(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        if reset { app.launchArguments.append("--reset-one-tape-appearance-fixture") }
        app.launch()
        return app
    }

    @MainActor
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
