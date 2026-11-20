import XCTest
import UIKit

/// The simulator owns two generated recordings. On the authorized USB phone,
/// this exercises the existing selected queue without importing or deleting it.
final class OneTapeReelMotionUITests: XCTestCase {
    @MainActor
    func testTrackWindThenPlaybackAndPausedReelsHoldTheirPixels() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()
        let lcd = app.buttons["tape.lcd"]
        XCTAssertTrue(lcd.waitForExistence(timeout: 15))
        wait("Restored queue has music") { !lcd.label.contains("还没有磁带") }
        selectStrata(app)
        let play = app.buttons["tape.play"]
        if play.label == "播放" { play.tap() }
        wait("Real engine begins playing") { (lcd.value as? String ?? "").contains("播放中") }
        Thread.sleep(forTimeInterval: 0.35)
        if !UIAccessibility.isReduceMotionEnabled {
            let first = app.buttons["tape.glass"].screenshot().image
            Thread.sleep(forTimeInterval: 0.4)
            let second = app.buttons["tape.glass"].screenshot().image
            for y in [0.19, 0.63] {
                XCTAssertNotEqual(try reelPixels(first, y: y), try reelPixels(second, y: y),
                    "Both visible reel regions must move while the real engine plays")
            }
        }
        capture("reels-normal-playing")

        app.buttons["tape.next"].tap()
        // AX transport values report the same controller as the engine. A
        // short stage may finish before an XCTest query arrives; attach observed
        // stages rather than extending the production delay to fit automation.
        let start = ProcessInfo.processInfo.systemUptime
        var observed: [String] = []
        repeat {
            let value = play.value as? String ?? ""
            if observed.last != value { observed.append(value) }
            if value == "亮起" && (lcd.value as? String ?? "").contains("播放中") { break }
        } while ProcessInfo.processInfo.systemUptime - start < 15
        let phases = XCTAttachment(string: observed.joined(separator: "\n"))
        phases.name = "observed-track-change-stages"
        phases.lifetime = .keepAlways
        add(phases)
        wait("Selected decoder advances after mechanical change") {
            (lcd.value as? String ?? "").contains("播放中") && self.position(lcd) >= 1
                && play.value as? String == "亮起"
        }
        capture("reels-next-resumed")
        app.buttons["tape.previous"].tap()
        wait("Previous/restart completes through the same engine") {
            (lcd.value as? String ?? "").contains("播放中") && play.value as? String == "亮起"
        }
        capture("reels-previous-resumed")

        play.tap()
        wait("Explicit pause stops the engine") { (lcd.value as? String ?? "").contains("已暂停") }
        // Once UI and cover animations settle, both reel pixels must freeze.
        Thread.sleep(forTimeInterval: 0.35)
        let glass = app.buttons["tape.glass"]
        let held = try pixels(glass.screenshot().image)
        let position = position(lcd)
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(try pixels(glass.screenshot().image), held)
        XCTAssertEqual(self.position(lcd), position)
        capture("reels-paused-frozen")

        app.buttons["tape.next"].tap()
        wait("Paused navigation remains paused") {
            play.label == "播放" && play.value as? String == "未亮起"
        }
        let paused = self.position(lcd)
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertEqual(self.position(lcd), paused)
        capture("reels-paused-next")
    }

    @MainActor
    private func selectStrata(_ app: XCUIApplication) {
        if !app.buttons["nav.customize"].exists { app.buttons["tape.glass"].tap() }
        app.buttons["nav.customize"].tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 5))
        app.buttons["customization.tab.tape"].tap()
        let tile = app.buttons["customization.tape.strata"]
        let scroll = app.scrollViews["customization.scroll"]
        for _ in 0..<4 where !tile.isHittable { scroll.swipeUp() }
        wait("Mold tile becomes reachable") { tile.isHittable }
        tile.tap()
        app.buttons["customization.close"].tap()
        wait("Customization closes") { !app.buttons["customization.close"].exists }
        if (app.buttons["tape.glass"].value as? String ?? "").hasPrefix("已关闭") {
            let glass = app.buttons["tape.glass"]
            glass.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
                .press(forDuration: 0.1, thenDragTo:
                    glass.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        }
        if app.buttons["nav.customize"].exists { app.buttons["tape.glass"].tap() }
    }

    @MainActor
    private func position(_ lcd: XCUIElement) -> Double {
        let fields = (lcd.value as? String ?? "").components(separatedBy: "；")
        guard fields.count > 2 else { return -1 }
        let parts = fields[2].split(separator: ":").compactMap { Double($0) }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : -1
    }

    @MainActor
    private func wait(_ description: String, condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 20), .completed, description)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pixels(_ image: UIImage) throws -> Data {
        let cgImage = try XCTUnwrap(image.cgImage)
        return try XCTUnwrap(cgImage.dataProvider?.data) as Data
    }

    private func reelPixels(_ image: UIImage, y: CGFloat) throws -> Data {
        let source = try XCTUnwrap(image.cgImage)
        let width = CGFloat(source.width), height = CGFloat(source.height)
        let crop = try XCTUnwrap(source.cropping(to:
            CGRect(x: width * 0.35, y: height * y, width: width * 0.3, height: height * 0.2).integral))
        return try XCTUnwrap(crop.dataProvider?.data) as Data
    }
}
