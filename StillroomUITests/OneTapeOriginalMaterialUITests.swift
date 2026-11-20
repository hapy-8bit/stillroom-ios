import XCTest
import UIKit

/// Only the appearance fixture is edited. Normal music, preferences and the
/// user's selected recording are restored by the final ordinary USB launch.
final class OneTapeOriginalMaterialUITests: XCTestCase {
    @MainActor
    func testFourOriginalMaterialsApplyAndColdRestore() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture",
                               "--reset-one-tape-appearance-fixture"]
        app.launch()
        wait("The player opens") { app.buttons["tape.play"].exists }
        let originalFrame = app.buttons["tape.play"].frame
        openPicker(app)
        tap(app.buttons["customization.tab.tape"])
        let facet = app.buttons["customization.tape.facet"]
        reveal(facet, in: app)
        tap(facet)
        tap(app.buttons["customization.tab.body"])
        XCTAssertFalse(app.staticTexts["原创材质"].exists, "All body choices belong to one grid")
        capture("unified-body-picker-top")
        tap(app.buttons["customization.close"])
        if app.buttons["nav.customize"].exists { glass(app) }
        let originalModule = app.buttons["tape.glass"].screenshot()
        for material in ["frostedGlass", "smokedGlass", "brushedAluminum", "darkTitanium"] {
            openPicker(app)
            let choice = app.buttons["customization.material.\(material)"]
            reveal(choice, in: app)
            tap(choice)
            XCTAssertEqual(choice.value as? String, "已选择")
            capture("original-material-\(material)-picker")
            tap(app.buttons["customization.close"])
            if app.buttons["nav.customize"].exists { glass(app) }
            wait("Only the full player remains visible") { !app.buttons["nav.customize"].exists }
            for identifier in ["tape.previous", "tape.play", "tape.next", "tape.lcd"] {
                XCTAssertTrue(app.buttons[identifier].isHittable)
            }
            XCTAssertEqual(app.buttons["tape.play"].frame, originalFrame)
            XCTAssertEqual(app.buttons["tape.play"].label, "播放")
            assertModuleUnchanged(originalModule, app.buttons["tape.glass"].screenshot())
            capture("original-material-\(material)-applied")
            if material == "brushedAluminum" {
                setGlassOpen(false, in: app)
                capture("unified-pocket-aluminum-glass-closed")
                setGlassOpen(true, in: app)
            }
        }
        app.terminate()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        app.launch()
        wait("Cold restoration opens the same player") { app.buttons["tape.play"].exists }
        openPicker(app)
        let titanium = app.buttons["customization.material.darkTitanium"]
        reveal(titanium, in: app)
        XCTAssertEqual(titanium.value as? String, "已选择")
        let restore = app.buttons["customization.body.black"]
        reveal(restore, in: app, upward: false)
        tap(restore)
        XCTAssertEqual(restore.value as? String, "已选择")
        let graphite = app.buttons["customization.body.graphite"]
        reveal(graphite, in: app, upward: false)
        tap(graphite)
        XCTAssertEqual(graphite.value as? String, "已选择")
        capture("original-material-classic-previews-preserved")
        let white = app.buttons["customization.bodyColor.white"]
        reveal(white, in: app)
        tap(white)
        capture("unified-body-colors-after-all-eight-choices")
        tap(app.buttons["customization.close"])
        if app.buttons["nav.customize"].exists { glass(app) }
        wait("The white original body is visible") { !app.buttons["nav.customize"].exists }
        capture("unified-pocket-white-original-body")
    }

    @MainActor
    private func openPicker(_ app: XCUIApplication) {
        if !app.buttons["nav.customize"].exists { glass(app) }
        tap(app.buttons["nav.customize"])
        tap(app.buttons["customization.tab.body"])
    }

    @MainActor
    private func glass(_ app: XCUIApplication) {
        let element = app.buttons["tape.glass"]
        wait("Glass accepts a touch") { element.exists && element.isEnabled }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
    }

    @MainActor
    private func setGlassOpen(_ open: Bool, in app: XCUIApplication) {
        let element = app.buttons["tape.glass"]
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: open ? 0.18 : 0.82))
        let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: open ? 0.82 : 0.18))
        start.press(forDuration: 0.1, thenDragTo: end)
        wait("The physical glass settles") {
            (element.value as? String ?? "").hasPrefix(open ? "已打开" : "已关闭")
        }
    }

    private func assertModuleUnchanged(_ before: XCUIScreenshot, _ after: XCUIScreenshot) {
        guard let a = before.image.cgImage, let b = after.image.cgImage else {
            XCTFail("The cassette frame must have native pixels")
            return
        }
        XCTAssertEqual(a.width, b.width)
        XCTAssertEqual(a.height, b.height)
        // The bounding rectangle's corners belong to the surrounding body;
        // these samples stay inside the module, including its stationary rim.
        for point in [CGPoint(x: 0.006, y: 0.5), CGPoint(x: 0.994, y: 0.5),
                      CGPoint(x: 0.5, y: 0.004), CGPoint(x: 0.5, y: 0.996),
                      CGPoint(x: 0.02, y: 0.5), CGPoint(x: 0.98, y: 0.5),
                      CGPoint(x: 0.3, y: 0.4), CGPoint(x: 0.6, y: 0.65)] {
            func pixel(_ image: CGImage) -> [UInt8] {
                let crop = image.cropping(to: CGRect(x: floor(point.x * CGFloat(image.width)),
                    y: floor(point.y * CGFloat(image.height)), width: 1, height: 1))!
                var data = [UInt8](repeating: 0, count: 4)
                data.withUnsafeMutableBytes { buffer in
                    let context = CGContext(data: buffer.baseAddress, width: 1, height: 1,
                        bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                }
                return Array(data.prefix(3))
            }
            for (old, new) in zip(pixel(a), pixel(b)) {
                XCTAssertLessThanOrEqual(abs(Int(old) - Int(new)), 3, "Body finish crossed the cassette frame")
            }
        }
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, upward: Bool = true) {
        let scroll = app.scrollViews["customization.scroll"]
        for _ in 0..<8 {
            let top = max(scroll.frame.minY, app.buttons["customization.tab.body"].frame.maxY) + 12
            let bottom = min(scroll.frame.maxY, app.buttons["nav.customize"].frame.minY) - 16
            let exists = element.exists
            let center = exists ? element.frame.midY : CGFloat.infinity
            if exists, element.isHittable, center >= top, center <= bottom { return }
            let downward = exists ? center < top : !upward
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: scroll.frame.minX + scroll.frame.width * 0.25,
                dy: (downward ? top + 18 : bottom - 18) - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: scroll.frame.minX + scroll.frame.width * 0.25,
                dy: (downward ? bottom - 18 : top + 18) - app.frame.minY))
            start.press(forDuration: 0.06, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable, "Material choice must be reachable")
    }

    @MainActor
    private func tap(_ element: XCUIElement) {
        wait("A material control is reachable") { element.exists && element.isHittable }
        element.tap()
    }

    @MainActor
    private func wait(_ description: String, condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 12), .completed, description)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
