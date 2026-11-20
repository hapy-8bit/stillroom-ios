import XCTest
import UIKit

/// Runs the normal signed app against its existing queue. Only appearance uses
/// a separate preference suite; no music fixture or device data is imported.
final class OneTapeBodyControlsUITests: XCTestCase {
    @MainActor
    func testReferenceBodyPickerAndSelectionRemainUsable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture",
                               "--reset-one-tape-appearance-fixture"]
        app.launch()
        wait("The empty fixture player opens") { app.buttons["tape.play"].exists }
        openPicker(app)
        tap(app.buttons["customization.tab.body"])
        for style in ["black", "graphite", "adaptive", "cover"] {
            let choice = app.buttons["customization.body.\(style)"]
            tap(choice)
            XCTAssertEqual(choice.value as? String, "已选择")
            for candidate in ["black", "graphite", "adaptive", "cover"] {
                XCTAssertTrue(app.buttons["customization.body.\(candidate)"].isHittable)
            }
            capture("reference-picker-\(style)")
        }
        tap(app.buttons["customization.close"])
        wait("Closing the drawer returns its controls") {
            !app.buttons["customization.close"].exists && app.buttons["tape.play"].isHittable
        }
        XCTAssertEqual(app.buttons["tape.play"].label, "播放")
        capture("reference-picker-closed")
    }

    @MainActor
    func testAppliedMaterialsAndRealPlaybackKeepTheSameKeyOutline() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()
        let lcd = app.buttons["tape.lcd"]
        let play = app.buttons["tape.play"]
        wait("The user's existing queue restores") {
            lcd.exists && !lcd.label.contains("还没有磁带")
        }
        if play.label == "暂停" { play.tap() }
        openPicker(app)
        tap(app.buttons["customization.tab.screen"])
        tap(app.buttons["customization.screen.lcd"])
        tap(app.buttons["customization.close"])

        for style in ["black", "graphite", "adaptive", "cover"] {
            openPicker(app)
            tap(app.buttons["customization.tab.body"])
            if style == "graphite" {
                tap(app.buttons["customization.bodyColor.cognac"])
            }
            tap(app.buttons["customization.body.\(style)"])
            XCTAssertEqual(app.buttons["customization.bodyColor.black"].value as? String, "已选择")
            capture("controls-\(style)-picker")
            tap(app.buttons["customization.close"])
            if app.buttons["nav.customize"].exists { tapGlass(app) }
            wait("The player is unobstructed and paused") {
                !app.buttons["nav.customize"].exists && play.label == "播放"
            }
            Thread.sleep(forTimeInterval: 0.5)
            let beforeFrame = play.frame
            let before = play.screenshot()
            capture("controls-\(style)-paused")
            play.press(forDuration: 0.6)
            wait("The same real engine plays and illuminates its cap") {
                (lcd.value as? String ?? "").contains("播放中") && play.value as? String == "亮起"
            }
            Thread.sleep(forTimeInterval: 0.5)
            XCTAssertEqual(play.frame, beforeFrame)
            let after = play.screenshot()
            try assertRimUnchanged(before, after, name: style)
            capture("controls-\(style)-playing")
            tap(play)
            wait("Pausing releases the lamp") { play.label == "播放" && play.value as? String == "未亮起" }
            Thread.sleep(forTimeInterval: 0.4)
            try assertRimUnchanged(before, play.screenshot(), name: style + "-paused-again")
        }
        // A cold fixture restore keeps the selected material. The USB wrapper
        // follows this test with an ordinary launch using the user's preferences.
        app.terminate()
        app.launchArguments = ["--one-tape-appearance-fixture"]
        app.launch()
        wait("The player restores after a cold launch") { play.exists && lcd.exists }
        openPicker(app)
        tap(app.buttons["customization.tab.body"])
        XCTAssertEqual(app.buttons["customization.body.cover"].value as? String, "已选择")
        tap(app.buttons["customization.close"])
        capture("controls-cover-cold-restore")
    }

    private func assertRimUnchanged(_ before: XCUIScreenshot, _ after: XCUIScreenshot, name: String) throws {
        let a = try XCTUnwrap(before.image.cgImage)
        let b = try XCTUnwrap(after.image.cgImage)
        XCTAssertEqual(a.width, b.width)
        XCTAssertEqual(a.height, b.height)
        let old = try bytes(a)
        let new = try bytes(b)
        let center = Double(a.width) / 2
        var changed = 0
        var samples = 0
        for y in 0..<a.height {
            for x in 0..<a.width {
                let radius = hypot(Double(x) + 0.5 - center, Double(y) + 0.5 - center) / Double(a.width)
                guard radius >= 0.46, radius <= 0.495 else { continue }
                let index = (y * a.width + x) * 4
                if (0..<3).contains(where: { abs(Int(old[index + $0]) - Int(new[index + $0])) > 3 }) {
                    changed += 1
                }
                samples += 1
            }
        }
        XCTAssertGreaterThan(samples, 100)
        XCTAssertEqual(changed, 0, "Playback changed the rim or outer size: \(name)")
        for (suffix, screenshot) in [("before", before), ("after", after)] {
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "key-rim-\(name)-\(suffix)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func bytes(_ image: CGImage) throws -> [UInt8] {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drew = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(drew)
        return data
    }

    @MainActor
    private func openPicker(_ app: XCUIApplication) {
        if !app.buttons["nav.customize"].exists { tapGlass(app) }
        tap(app.buttons["nav.customize"])
        wait("The customization drawer opens") { app.buttons["customization.close"].isHittable }
    }

    @MainActor
    private func tapGlass(_ app: XCUIApplication) {
        let glass = app.buttons["tape.glass"]
        wait("The glass is present and enabled") { glass.exists && glass.isEnabled }
        // The transparent cover's automatically chosen hit point can become
        // unavailable after a drawer transition. Touch its unobstructed upper
        // area using the runtime frame, as an actual finger does.
        glass.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
    }

    @MainActor
    private func tap(_ element: XCUIElement) {
        wait("The requested control is reachable") { element.exists && element.isHittable }
        element.tap()
    }

    @MainActor
    private func wait(_ description: String, condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 35), .completed, description)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
