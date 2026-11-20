import XCTest
import UIKit

final class OneTapeMouldedUITests: XCTestCase {
    private let styles = [("strata", "岩层"), ("facet", "折面"), ("islands", "浮岛"),
                          ("ribs", "肋骨"), ("stream", "流线"), ("eclipse", "月蚀")]

    @MainActor
    func testRibsEdgesDuringPlaybackAndPause() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()
        choose("ribs", app: app)
        let glass = app.buttons["tape.glass"]
        if (glass.value as? String ?? "").hasPrefix("已关闭") { dragCover(app, close: false) }
        expectCover(app, state: "已打开")
        let lcd = app.buttons["tape.lcd"], play = app.buttons["tape.play"]
        XCTAssertFalse(lcd.label.contains("还没有磁带"))
        if play.label == "播放" { play.tap() }
        expectation(for: NSPredicate(format: "value CONTAINS %@", "播放中"), evaluatedWith: lcd)
        waitForExpectations(timeout: 10)
        capture("ribs-edge-playing-first")
        Thread.sleep(forTimeInterval: 0.45)
        capture("ribs-edge-playing-second")
        if ProcessInfo.processInfo.environment["ONE_TAPE_PROFILE_MOULDS"] == "1" {
            print("RIBS_EDGE_PERF_READY")
            Thread.sleep(forTimeInterval: 14)
        }
        play.tap()
        expectation(for: NSPredicate(format: "value CONTAINS %@", "已暂停"), evaluatedWith: lcd)
        waitForExpectations(timeout: 8)
        Thread.sleep(forTimeInterval: 0.4)
        let held = glass.screenshot().image
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(try changedPixels(held, glass.screenshot().image), 0)
        capture("ribs-edge-paused-open")
        dragCover(app, close: true)
        expectCover(app, state: "已关闭")
        capture("ribs-edge-paused-closed")
    }

    /// The USB phone uses its existing queue; appearance changes stay in the
    /// isolated suite so reviewing all six does not overwrite the user's style.
    @MainActor
    func testSixMatchedMouldsDuringPlayback() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()
        let lcd = app.buttons["tape.lcd"]
        XCTAssertTrue(lcd.waitForExistence(timeout: 15))
        XCTAssertFalse(lcd.label.contains("还没有磁带"))
        let play = app.buttons["tape.play"]
        if play.label == "播放" { play.tap() }
        for (key, name) in styles {
            choose(key, app: app)
            let glass = app.buttons["tape.glass"]
            if (glass.value as? String ?? "").hasPrefix("已关闭") { dragCover(app, close: false) }
            expectCover(app, state: "已打开")
            XCTAssertTrue((glass.value as? String ?? "").contains(name))
            XCTAssertTrue((lcd.value as? String ?? "").contains("播放中"))
            if !UIAccessibility.isReduceMotionEnabled {
                let first = try XCTUnwrap(glass.screenshot().image.cgImage)
                Thread.sleep(forTimeInterval: 0.32)
                let second = try XCTUnwrap(glass.screenshot().image.cgImage)
                for y in [0.19, 0.63] {
                    let rect = CGRect(x: Double(first.width) * 0.35, y: Double(first.height) * y,
                                      width: Double(first.width) * 0.3, height: Double(first.height) * 0.2)
                    let a = try XCTUnwrap(first.cropping(to: rect.integral)?.dataProvider?.data) as Data
                    let b = try XCTUnwrap(second.cropping(to: rect.integral)?.dataProvider?.data) as Data
                    XCTAssertNotEqual(a, b, "Both matched reels must move: \(key)")
                }
            }
            capture("matched-\(key)-playing-open")
            if key == "strata", ProcessInfo.processInfo.environment["ONE_TAPE_PROFILE_MOULDS"] == "1" {
                print("MATCHED_MOULD_PERF_READY")
                Thread.sleep(forTimeInterval: 14)
            }
            dragCover(app, close: true)
            expectCover(app, state: "已关闭")
            capture("matched-\(key)-playing-closed")
        }
        play.tap()
        expectation(for: NSPredicate(format: "value CONTAINS %@", "已暂停"), evaluatedWith: lcd)
        waitForExpectations(timeout: 8)
        Thread.sleep(forTimeInterval: 0.4)
        let held = app.buttons["tape.glass"].screenshot().image
        let first = XCTAttachment(image: held)
        first.name = "matched-eclipse-paused-first"
        first.lifetime = .keepAlways
        add(first)
        Thread.sleep(forTimeInterval: 0.6)
        let later = app.buttons["tape.glass"].screenshot().image
        let second = XCTAttachment(image: later)
        second.name = "matched-eclipse-paused-second"
        second.lifetime = .keepAlways
        add(second)
        XCTAssertEqual(try changedPixels(held, later), 0)
        capture("matched-eclipse-paused")
    }

    private func changedPixels(_ first: UIImage, _ second: UIImage) throws -> Int {
        let a = try normalizedPixels(first), b = try normalizedPixels(second)
        XCTAssertEqual(a.count, b.count)
        // Screenshot providers can contain row padding and GPU rounding. Check
        // actual RGBA pixels; a moving hub changes edges well beyond 3 levels.
        return stride(from: 0, to: min(a.count, b.count), by: 4).filter { offset in
            (0..<3).contains { abs(Int(a[offset + $0]) - Int(b[offset + $0])) > 3 }
        }.count
    }

    private func normalizedPixels(_ image: UIImage) throws -> [UInt8] {
        let source = try XCTUnwrap(image.cgImage)
        var result = [UInt8](repeating: 0, count: source.width * source.height * 4)
        try result.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: source.width,
                height: source.height, bitsPerComponent: 8, bytesPerRow: source.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        }
        return result
    }

    @MainActor
    func testAllTwelveCassettesKeepTheirPlayerFrame() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture",
                               "--reset-one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.glass"].waitForExistence(timeout: 10))
        let original = app.buttons["tape.glass"].frame
        let keys = ["classic", "graphite", "clear", "window", "memphis", "bronze"]
            + styles.map(\.0)
        for key in keys {
            choose(key, app: app)
            let frame = app.buttons["tape.glass"].frame
            XCTAssertEqual(frame.minX, original.minX, accuracy: 0.5, key)
            XCTAssertEqual(frame.minY, original.minY, accuracy: 0.5, key)
            XCTAssertEqual(frame.width, original.width, accuracy: 0.5, key)
            XCTAssertEqual(frame.height, original.height, accuracy: 0.5, key)
            capture("placement-\(key)-open")
            if ["classic", "bronze", "strata"].contains(key) {
                dragCover(app, close: true)
                expectCover(app, state: "已关闭")
                capture("placement-\(key)-closed")
                dragCover(app, close: false)
                expectCover(app, state: "已打开")
            }
        }
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["tape.glass"].waitForExistence(timeout: 10))
        capture("placement-normal-preserved-appearance")
        app.terminate()
    }

    @MainActor
    func testSixMouldsSelectCoverAndRestoreInIsolatedAppearance() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture",
                               "--reset-one-tape-appearance-fixture"]
        app.launch()
        for (key, name) in styles {
            choose(key, app: app)
            let glass = app.buttons["tape.glass"]
            XCTAssertTrue((glass.value as? String ?? "").contains(name))
            XCTAssertTrue((glass.value as? String ?? "").contains("空白磁带"))
            XCTAssertEqual(app.buttons["tape.play"].label, "播放")
            capture("mould-\(key)-open")
            dragCover(app, close: true)
            expectCover(app, state: "已关闭")
            capture("mould-\(key)-closed")
            dragCover(app, close: false)
            expectCover(app, state: "已打开")
        }
        app.terminate()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.glass"].waitForExistence(timeout: 8))
        XCTAssertTrue((app.buttons["tape.glass"].value as? String ?? "").contains("月蚀"))
        capture("mould-eclipse-cold-restored")
    }

    /// Invoked only for the explicitly requested phone preview. The regular
    /// library is retained; this selects one of the six new shells for the user.
    @MainActor
    func testPhonePreviewLeavesStrataSelected() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = []
        app.launch()
        choose("strata", app: app)
        showUnprintedShell(app)
        if (app.buttons["tape.glass"].value as? String ?? "").hasPrefix("已关闭") {
            dragCover(app, close: false)
        }
        XCTAssertTrue((app.buttons["tape.glass"].value as? String ?? "").contains("岩层"))
        capture("mould-phone-normal-strata")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["tape.glass"].waitForExistence(timeout: 8))
        XCTAssertTrue((app.buttons["tape.glass"].value as? String ?? "").contains("岩层"))
        capture("mould-phone-normal-cold-strata")
    }

    @MainActor
    private func showUnprintedShell(_ app: XCUIApplication) {
        if !app.buttons["nav.customize"].exists { app.buttons["tape.glass"].tap() }
        app.buttons["nav.customize"].tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 5))
        app.buttons["customization.tab.print"].tap()
        Thread.sleep(forTimeInterval: 0.45)
        let plain = app.buttons["customization.doodle.none"]
        XCTAssertTrue(plain.waitForExistence(timeout: 4))
        plain.tap()
        app.buttons["customization.close"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["customization.close"])
        waitForExpectations(timeout: 4)
        // AX removes the dismissed sheet before its final presentation frame.
        Thread.sleep(forTimeInterval: 0.65)
    }

    @MainActor
    private func choose(_ key: String, app: XCUIApplication) {
        XCTAssertTrue(app.buttons["tape.glass"].waitForExistence(timeout: 8))
        let navigation = app.buttons["nav.customize"]
        // Refresh the transient HUD before looking up its target; an existence
        // query can otherwise land at the end of its automatic fade timeout.
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
        app.buttons["customization.tab.tape"].tap()
        // The panel's AX destination is published before its slide finishes.
        Thread.sleep(forTimeInterval: 0.45)
        let tile = app.buttons["customization.tape.\(key)"]
        reveal(tile, app: app)
        tile.tap()
        XCTAssertEqual(tile.value as? String, "已选择")
        capture("mould-\(key)-picker")
        app.buttons["customization.close"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["customization.close"])
        waitForExpectations(timeout: 4)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        let scroll = app.scrollViews["customization.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 4))
        for _ in 0..<8 {
            let top = max(scroll.frame.minY, app.buttons["customization.tab.tape"].frame.maxY) + 12
            let bottom = min(scroll.frame.maxY, app.buttons["nav.customize"].frame.minY) - 12
            guard bottom > top else { XCTFail("No visible style picker area"); return }
            // Lazy rows have no frame until scrolling creates their AX node.
            let exists = element.exists
            let center = exists ? element.frame.midY : bottom + 1
            if exists, element.isHittable, center >= top, center <= bottom { return }
            let down = exists && center < top
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.width / 2, dy: down ? top + 8 : bottom - 8))
                .press(forDuration: 0.05, thenDragTo:
                    origin.withOffset(CGVector(dx: app.frame.width / 2, dy: down ? bottom - 8 : top + 8)))
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func dragCover(_ app: XCUIApplication, close: Bool) {
        let glass = app.buttons["tape.glass"]
        let top = glass.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        let bottom = glass.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        (close ? bottom : top).press(forDuration: 0.1, thenDragTo: close ? top : bottom)
    }

    @MainActor
    private func expectCover(_ app: XCUIApplication, state: String) {
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", state), evaluatedWith: app.buttons["tape.glass"])
        waitForExpectations(timeout: 4)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
