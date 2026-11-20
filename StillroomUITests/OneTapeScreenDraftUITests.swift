import XCTest
import CoreGraphics
import UIKit

/// Requires prepare-screen-draft-qa.py on the dedicated art QA simulator. The
/// generated local PCM is played by the real engine; no network or fake clock.
final class OneTapeScreenDraftUITests: XCTestCase {
    @MainActor
    func testApprovedScreensPlayPauseAndRestoreTheRealQARecording() throws {
        try requirePhotoQASimulator()
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()
        let lcd = app.buttons["tape.lcd"]
        XCTAssertTrue(lcd.waitForExistence(timeout: 15))
        app.buttons["tape.glass"].tap()
        app.buttons["nav.library"].tap()
        XCTAssertTrue(app.buttons["crate.album.0"].waitForExistence(timeout: 10))
        app.buttons["crate.album.0"].tap()
        let song = app.buttons["album.song.0"]
        XCTAssertTrue(song.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "hittable == true AND enabled == true"), evaluatedWith: song)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(song.label.contains("夜航信号"), "Prepare the generated art QA fixture first.")
        song.tap()
        expectation(for: NSPredicate(format: "label == %@", "暂停"), evaluatedWith: app.buttons["album.play"])
        waitForExpectations(timeout: 15)
        app.buttons["nav.nowPlaying"].tap()
        expectation(for: NSPredicate { _, _ in self.position(lcd) >= 1 }, evaluatedWith: lcd)
        waitForExpectations(timeout: 15)

        for style in ["rain", "trails", "name", "meters", "fluid"] {
            select(style, app: app)
            XCTAssertTrue(lcd.label.contains("夜航信号"))
            XCTAssertTrue(lcd.label.contains("合成测试音"))
            XCTAssertTrue((lcd.value as? String ?? "").contains("播放中"))
            assertAccurateReadout(lcd)
            let started = position(lcd)
            expectation(for: NSPredicate { _, _ in self.position(lcd) >= started + 1 }, evaluatedWith: lcd)
            waitForExpectations(timeout: 6)
            // The full screenshot is the evidence for text placement over the
            // photography; AX metadata alone cannot prove a legible composition.
            capture("photo-\(style)-playing", app: app)
            app.buttons["tape.play"].tap()
            expectation(for: NSPredicate(format: "value CONTAINS %@", "已暂停"), evaluatedWith: lcd)
            waitForExpectations(timeout: 5)
            let paused = position(lcd)
            Thread.sleep(forTimeInterval: 0.25)
            let heldPixels = try pixels(lcd.screenshot().image)
            Thread.sleep(forTimeInterval: 1.2)
            XCTAssertEqual(position(lcd), paused, accuracy: 0.1)
            let laterPixels = try pixels(lcd.screenshot().image)
            XCTAssertEqual(zip(heldPixels, laterPixels).filter { $0 != $1 }.count, 0,
                           "Paused \(style) artwork must hold its actual screen pixels")
            assertAccurateReadout(lcd)
            capture("photo-\(style)-paused", app: app)
            if style != "fluid" {
                app.buttons["tape.play"].tap()
                expectation(for: NSPredicate(format: "value CONTAINS %@", "播放中"), evaluatedWith: lcd)
                waitForExpectations(timeout: 5)
            }
        }
        let savedPosition = position(lcd)
        app.terminate()
        app.launchArguments = ["--one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(lcd.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "fluid；已暂停"), evaluatedWith: lcd)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(lcd.label.contains("夜航信号"))
        XCTAssertEqual(position(lcd), savedPosition, accuracy: 1.1)
        capture("photo-fluid-cold-restored", app: app)
    }

    @MainActor
    func testApprovedScreensKeepEmptyPlaybackStopped() throws {
        try requirePhotoQASimulator()
        try exerciseEmptyScreens()
    }

    @MainActor
    func testScreenOrientationTransitionRestoresTheEmptyPanel() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture",
                               "--reset-one-tape-appearance-fixture"]
        app.launch()
        let lcd = app.buttons["tape.lcd"]
        XCTAssertTrue(lcd.waitForExistence(timeout: 15))
        for style in ["lcd", "fluid", "name"] {
            select(style, app: app)
            let originalImage = lcd.screenshot().image
            let original = try pixels(originalImage)
            for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight, .portrait] {
                XCUIDevice.shared.orientation = orientation
                // Allow the 320ms presentation turn and its Canvas commit to
                // settle before endpoint capture. Actual simulator recordings
                // separately check that intermediate poses remain continuous.
                Thread.sleep(forTimeInterval: 0.4)
                let image = lcd.screenshot().image
                XCTAssertLessThan(app.frame.width, app.frame.height)
                XCTAssertEqual(lcd.value as? String, style)
                XCTAssertTrue(lcd.label.contains("还没有磁带"))
                XCTAssertEqual(app.buttons["tape.play"].label, "播放")
                if orientation != .landscapeLeft && style != "lcd" {
                    // These empty artworks are static. Exact return pixels
                    // catch a stranded transform or stale landscape layout.
                    let restored = try pixels(image)
                    if restored != original {
                        for (name, frame) in [("baseline", originalImage), ("restored", image)] {
                            let attachment = XCTAttachment(image: frame)
                            attachment.name = "transition-\(style)-\(name)"
                            attachment.lifetime = .keepAlways
                            add(attachment)
                        }
                    }
                    XCTAssertEqual(restored.count, original.count)
                    XCTAssertEqual(zip(restored, original).filter { $0 != $1 }.count, 0,
                                   "Right landscape is blocked and must restore the portrait panel pixels")
                }
                capture("transition-\(style)-\(orientation.rawValue)", app: app)
            }
        }
    }

    @MainActor
    func testInstalledPhoneEmptyScreensAndDeferredChoices() throws {
        guard ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == nil else {
            throw XCTSkip("This smoke check is explicitly run only on the authorized connected iPhone.")
        }
        try exerciseEmptyScreens()
    }

    @MainActor
    private func exerciseEmptyScreens() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture",
                               "--reset-one-tape-appearance-fixture"]
        app.launch()
        let lcd = app.buttons["tape.lcd"]
        XCTAssertTrue(lcd.waitForExistence(timeout: 10))
        openCustomization(app)
        app.buttons["customization.tab.screen"].tap()
        for hidden in ["dunes", "iron", "ink", "water", "sand", "oscilloscope", "waterfall"] {
            XCTAssertFalse(app.buttons["customization.screen.\(hidden)"].exists)
        }
        app.buttons["customization.close"].tap()
        for style in ["rain", "trails", "name", "meters", "fluid"] {
            select(style, app: app)
            app.buttons["tape.play"].tap()
            XCTAssertEqual(app.buttons["tape.play"].label, "播放")
            XCTAssertEqual(lcd.value as? String, style)
            XCTAssertTrue(lcd.label.contains("还没有磁带"))
            capture("photo-\(style)-empty", app: app)
        }
    }

    @MainActor
    func testApprovedScreensUpdateTheRealTrackWhilePausedAndPlaying() throws {
        try requirePhotoQASimulator()
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture"]
        app.launch()
        let lcd = app.buttons["tape.lcd"]
        XCTAssertTrue(lcd.waitForExistence(timeout: 15))
        XCTAssertTrue(lcd.label.contains("夜航信号") || lcd.label.contains("微光轨迹"),
                      "This journey only operates the isolated generated PCM library.")
        for style in ["fluid", "rain", "trails", "name", "meters"] {
            select(style, app: app)
            if app.buttons["tape.play"].label == "暂停" { app.buttons["tape.play"].tap() }
            expectation(for: NSPredicate(format: "value CONTAINS %@", "已暂停"), evaluatedWith: lcd)
            waitForExpectations(timeout: 5)
            switchQARecording(app, lcd: lcd)
            XCTAssertTrue((lcd.value as? String ?? "").contains("已暂停"))
            capture("approved-\(style)-new-track-paused", app: app)
            app.buttons["tape.play"].tap()
            expectation(for: NSPredicate(format: "value CONTAINS %@", "播放中"), evaluatedWith: lcd)
            waitForExpectations(timeout: 8)
            switchQARecording(app, lcd: lcd)
            expectation(for: NSPredicate(format: "value CONTAINS %@", "播放中"), evaluatedWith: lcd)
            waitForExpectations(timeout: 8)
            capture("approved-\(style)-new-track-playing", app: app)
            app.buttons["tape.play"].tap()
        }
    }

    @MainActor
    private func switchQARecording(_ app: XCUIApplication, lcd: XCUIElement) {
        let old = lcd.label
        if old.contains("夜航信号") {
            app.buttons["tape.next"].tap()
        } else {
            app.buttons["tape.previous"].tap()
            // Previous restarts a recording after three seconds. Wait for that
            // real seek to settle before asking it to select the previous track.
            expectation(for: NSPredicate { _, _ in lcd.label != old || self.position(lcd) < 1 }, evaluatedWith: lcd)
            waitForExpectations(timeout: 6)
            if lcd.label == old { app.buttons["tape.previous"].tap() }
        }
        expectation(for: NSPredicate { _, _ in lcd.label != old }, evaluatedWith: lcd)
        waitForExpectations(timeout: 6)
        XCTAssertTrue(lcd.label.contains("合成测试音"))
        assertAccurateReadout(lcd)
    }

    @MainActor
    private func pixels(_ image: UIImage) throws -> [UInt8] {
        let cgImage = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress,
                width: cgImage.width, height: cgImage.height, bitsPerComponent: 8,
                bytesPerRow: cgImage.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            return true
        }
        XCTAssertTrue(drawn)
        return bytes
    }

    @MainActor
    func testAllScreenDraftsKeepPlaybackAndRestorePausedInBothOrientations() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()
        let lcd = app.buttons["tape.lcd"]
        XCTAssertTrue(lcd.waitForExistence(timeout: 15))
        app.buttons["tape.glass"].tap()
        app.buttons["nav.library"].tap()
        XCTAssertTrue(app.buttons["crate.album.0"].waitForExistence(timeout: 10))
        app.buttons["crate.album.0"].tap()
        let song = app.buttons["album.song.0"]
        XCTAssertTrue(song.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "hittable == true AND enabled == true"), evaluatedWith: song)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(song.label.contains("夜航信号"), "Prepare only the generated art QA fixture.")
        song.tap()
        expectation(for: NSPredicate(format: "label == %@", "暂停"), evaluatedWith: app.buttons["album.play"])
        waitForExpectations(timeout: 15)
        app.buttons["nav.nowPlaying"].tap()
        expectation(for: NSPredicate { _, _ in self.position(lcd) >= 1 }, evaluatedWith: lcd)
        waitForExpectations(timeout: 15)

        // Screen rotation does not depend on a particular tape shell. Keep
        // the fixture's shell instead of relying on a retired picker row.
        let styles = ["lcd", "fluid", "rain", "trails", "name", "meters", "fox"]
        for style in styles {
            cycle(to: style, app: app)
            if style == "name" { assertNameLettering(app) }
            XCTAssertTrue(lcd.label.contains("夜航信号"))
            XCTAssertTrue(lcd.label.contains("合成测试音"))
            XCTAssertTrue((lcd.value as? String ?? "").contains("播放中"))
            capture("draft-\(style)-playing", app: app)
        }

        cycle(to: "fluid", app: app)
        app.buttons["tape.play"].tap()
        expectation(for: NSPredicate(format: "value CONTAINS %@", "已暂停"), evaluatedWith: lcd)
        waitForExpectations(timeout: 5)
        let paused = position(lcd)
        Thread.sleep(forTimeInterval: 1.2)
        XCTAssertEqual(position(lcd), paused, accuracy: 0.1)
        capture("draft-fluid-paused", app: app)

        defer { XCUIDevice.shared.orientation = .portrait }
        for style in ["fluid", "rain", "trails", "name", "meters"] {
            cycle(to: style, app: app)
            for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
                XCUIDevice.shared.orientation = orientation
                expectation(for: NSPredicate { _, _ in
                    let previous = app.buttons["tape.previous"].frame.midY
                    let next = app.buttons["tape.next"].frame.midY
                    return previous < next
                }, evaluatedWith: app)
                waitForExpectations(timeout: 5)
                XCTAssertLessThan(app.frame.width, app.frame.height)
                XCTAssertEqual(position(lcd), paused, accuracy: 0.1)
                assertAccurateReadout(lcd)
                capture("labels-\(style)-\(orientation == .landscapeLeft ? "left" : "right-blocked")", app: app)
            }
            XCUIDevice.shared.orientation = .portrait
        }
        cycle(to: "rain", app: app)

        app.terminate()
        app.launchArguments = ["--one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(lcd.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "rain；已暂停"), evaluatedWith: lcd)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(lcd.label.contains("夜航信号"))
        XCTAssertEqual(position(lcd), paused, accuracy: 1.1)
        capture("approved-rain-cold-restored", app: app)
        cycle(to: "fluid", app: app)
        capture("draft-fluid-final-paused", app: app)
    }

    @MainActor
    private func cycle(to style: String, app: XCUIApplication) {
        let lcd = app.buttons["tape.lcd"]
        for _ in 0..<7 {
            let old = (lcd.value as? String ?? "").components(separatedBy: "；").first ?? ""
            if old == style { return }
            lcd.tap()
            expectation(for: NSPredicate { _, _ in
                (lcd.value as? String ?? "").components(separatedBy: "；").first != old
            }, evaluatedWith: lcd)
            waitForExpectations(timeout: 3)
        }
        XCTFail("Released screen ring did not reach \(style)")
    }

    @MainActor
    func testNameLetteringAppearsForRestoredMusicAndEmptyLibrary() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.lcd"].waitForExistence(timeout: 15))
        expectation(for: NSPredicate { _, _ in
            app.buttons["tape.lcd"].label.contains("夜航信号")
        }, evaluatedWith: app)
        waitForExpectations(timeout: 10)
        select("name", app: app)
        assertNameLettering(app)
        capture("draft-name-restored-lettering", app: app)
        app.terminate()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.lcd"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["tape.lcd"].value as? String, "name")
        assertNameLettering(app)
        capture("draft-name-empty-restored-lettering", app: app)
    }

    @MainActor
    func testEmptyScreenDraftDoesNotStartPlaybackAndKeepsDraftChoices() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture",
                               "--reset-one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.lcd"].waitForExistence(timeout: 10))
        for style in ["fluid", "name"] {
            select(style, app: app)
            if style == "name" { assertNameLettering(app) }
            app.buttons["tape.play"].tap()
            XCTAssertEqual(app.buttons["tape.play"].label, "播放")
            XCTAssertEqual(app.buttons["tape.lcd"].value as? String, style)
            XCTAssertTrue(app.buttons["tape.lcd"].label.contains("还没有磁带"))
            capture("draft-\(style)-empty", app: app)
        }
    }

    @MainActor
    private func assertNameLettering(_ app: XCUIApplication) {
        let lcd = app.buttons["tape.lcd"]
        expectation(for: NSPredicate { _, _ in
            guard let image = lcd.screenshot().image.cgImage else { return false }
            // Inspect only the artwork's interior, away from the header and
            // bottom notice. The dark background cannot satisfy this bright-glyph count.
            let rect = CGRect(x: CGFloat(image.width) * 0.06, y: CGFloat(image.height) * 0.33,
                width: CGFloat(image.width) * 0.88, height: CGFloat(image.height) * 0.49)
            guard let crop = image.cropping(to: rect) else { return false }
            var rgba = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
            let drew = rgba.withUnsafeMutableBytes { bytes -> Bool in
                guard let context = CGContext(data: bytes.baseAddress, width: crop.width, height: crop.height,
                    bitsPerComponent: 8, bytesPerRow: crop.width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
                context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
                return true
            }
            guard drew else { return false }
            let glyphPixels = stride(from: 0, to: rgba.count, by: 4).filter {
                min(rgba[$0], rgba[$0 + 1], rgba[$0 + 2]) > 135
            }.count
            return glyphPixels > 200
        }, evaluatedWith: lcd)
        waitForExpectations(timeout: 6)
    }

    @MainActor
    private func select(_ style: String, app: XCUIApplication) {
        openCustomization(app)
        app.buttons["customization.tab.screen"].tap()
        let choice = app.buttons["customization.screen.\(style)"]
        reveal(choice, in: app)
        choice.tap()
        XCTAssertEqual(choice.value as? String, "已选择")
        app.buttons["customization.close"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["customization.close"])
        waitForExpectations(timeout: 3)
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", style), evaluatedWith: app.buttons["tape.lcd"])
        waitForExpectations(timeout: 3)
        if app.buttons["nav.customize"].exists { app.buttons["tape.glass"].tap() }
        Thread.sleep(forTimeInterval: 0.45)
    }

    @MainActor
    private func openCustomization(_ app: XCUIApplication) {
        let navigation = app.buttons["nav.customize"]
        // The six-second HUD expiry can begin between an AX existence query
        // and the glass tap. Resolve a fading state once before opening it.
        for _ in 0..<2 {
            if navigation.exists && navigation.isHittable { break }
            app.buttons["tape.glass"].tap()
            if navigation.waitForExistence(timeout: 2) && navigation.isHittable { break }
        }
        XCTAssertTrue(navigation.waitForExistence(timeout: 3))
        XCTAssertTrue(navigation.isHittable)
        navigation.tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 4))
        Thread.sleep(forTimeInterval: 0.45)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        // The opened library stays mounted behind the player. Target this
        // drawer explicitly, and start above every overlapping HUD segment.
        let scroll = app.scrollViews["customization.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 3))
        for _ in 0..<9 {
            let top = max(scroll.frame.minY, app.buttons["customization.tab.screen"].frame.maxY) + 14
            let hudTop = ["nav.nowPlaying", "nav.library", "nav.customize"].map {
                app.buttons[$0].frame.minY
            }.min() ?? scroll.frame.maxY
            let bottom = min(scroll.frame.maxY, hudTop) - 18
            let center = element.frame.midY
            if element.isHittable, center >= top, center <= bottom { return }
            let down = element.exists && center < top
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: app.frame.width / 2,
                dy: (down ? top + 10 : bottom - 10) - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: app.frame.width / 2,
                dy: (down ? bottom - 10 : top + 10) - app.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        for (suffix, shot) in [("-player", XCUIScreen.main.screenshot()),
                               ("-panel", app.buttons["tape.lcd"].screenshot())] {
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = name + suffix
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    private func position(_ lcd: XCUIElement) -> Double {
        let fields = (lcd.value as? String ?? "").components(separatedBy: "；")
        guard fields.count >= 3 else { return 0 }
        let parts = fields[2].split(separator: ":").compactMap { Double($0) }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
    }

    @MainActor
    private func assertAccurateReadout(_ lcd: XCUIElement) {
        let fields = (lcd.value as? String ?? "").components(separatedBy: "；")
        guard fields.count >= 6 else { return XCTFail("Missing real countdown and side in LCD readout") }
        func seconds(_ value: String) -> Int? {
            let parts = value.replacingOccurrences(of: "-", with: "").split(separator: ":")
            guard parts.count == 2, let minute = Int(parts[0]), let second = Int(parts[1]) else { return nil }
            return minute * 60 + second
        }
        guard let elapsed = seconds(fields[2]), let total = seconds(fields[3]),
              let remaining = seconds(fields[4]) else { return XCTFail("Invalid measured media clock: \(fields)") }
        XCTAssertTrue(fields[4].hasPrefix("-"))
        XCTAssertEqual(elapsed + remaining, total, "Current and remaining clocks disagree")
        XCTAssertEqual(fields[5], lcd.label.contains("夜航信号") ? "面 A" : "面 B",
                       "The generated two-track queue must project its real current side")
    }

    private func requirePhotoQASimulator() throws {
        // Match the same dedicated destination enforced by the fixture tool.
        // A skip on any other destination must not be reported as a test pass.
        let expectedID = "2C650379-F02A-4D67-9C0A-3DAC0390EBAB"
        let actualID = ProcessInfo.processInfo.environment["SIMULATOR_UDID"]?.uppercased()
        guard actualID == expectedID else {
            throw XCTSkip("Photography UI checks require the One Tape Print Redraw QA simulator and prepared local PCM.")
        }
    }
}
