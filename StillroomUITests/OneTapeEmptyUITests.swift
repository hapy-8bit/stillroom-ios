import XCTest
import UIKit

final class OneTapeEmptyUITests: XCTestCase {
    @MainActor
    func testPlayingExpandsOnlyTheLeftMusicMenu() throws {
        guard ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == "C8881DC0-F0FA-4D58-A3A5-402C53D5325D" else {
            throw XCTSkip("Playback uses only this task's isolated simulator and generated silent audio.")
        }
        let app = XCUIApplication()
        // Prepare this simulator's generated, never-played fixture before the
        // test. Playback and expansion still use the real shared engine.
        app.launchArguments = ["--one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.glass"].waitForExistence(timeout: 10))
        app.buttons["tape.glass"].tap()
        let player = app.buttons["nav.nowPlaying"]
        let library = app.buttons["nav.library"]
        let insights = app.buttons["nav.insights"]
        XCTAssertTrue(player.waitForExistence(timeout: 3))
        let compact = player.frame
        let libraryWidth = library.frame.width
        let insightsWidth = insights.frame.width
        let action = app.buttons["nav.customize"].frame
        XCTAssertEqual(compact.width, libraryWidth, accuracy: 0.5)
        screenshot("music-menu-before-first-play")
        app.buttons["tape.play"].tap()
        let expanded = NSPredicate { _, _ in player.frame.width > compact.width + 20 }
        expectation(for: expanded, evaluatedWith: player)
        waitForExpectations(timeout: 4)
        XCTAssertEqual(player.frame.minX, compact.minX, accuracy: 0.5)
        XCTAssertEqual(player.frame.height, compact.height, accuracy: 0.5)
        XCTAssertEqual(library.frame.width, libraryWidth, accuracy: 0.5)
        XCTAssertEqual(insights.frame.width, insightsWidth, accuracy: 0.5)
        XCTAssertEqual(app.buttons["nav.customize"].frame, action)
        XCTAssertTrue(player.label.hasPrefix("播放器："))
        screenshot("music-menu-expanded-after-playing")
        app.buttons["tape.play"].tap()
        XCTAssertEqual(app.buttons["tape.play"].label, "播放")
    }

    @MainActor
    func testExpandedMusicKeepsItsOwnLeftMenuSurfaceOnLibrary() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["tape.glass"].waitForExistence(timeout: 10))
        app.buttons["tape.glass"].tap()
        let player = app.buttons["nav.nowPlaying"]
        let restored = NSPredicate(format: "label BEGINSWITH %@", "播放器：")
        expectation(for: restored, evaluatedWith: player)
        waitForExpectations(timeout: 4)
        let title = player.label
        app.buttons["nav.library"].tap()
        XCTAssertTrue(app.buttons["nav.import"].waitForExistence(timeout: 3))
        XCTAssertFalse(player.isSelected)
        let frame = player.frame
        let screenshot = app.screenshot()
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let scale = CGFloat(image.width) / app.frame.width
        // Sample the lower clear strip, away from the icon and both text lines.
        // The adjacent strip is still inside the outer dock, below this item.
        let inside = try navigationBrightness(image, point: CGPoint(x: frame.midX, y: frame.maxY - 5), scale: scale)
        let outside = try navigationBrightness(image, point: CGPoint(x: frame.midX, y: frame.maxY + 2), scale: scale)
        let pixels = XCTAttachment(string: "left-item=\(frame); surface=\(inside); surrounding-dock=\(outside)")
        pixels.name = "expanded-left-menu-surface"
        pixels.lifetime = .keepAlways
        add(pixels)
        self.screenshot("expanded-left-menu-on-library")
        XCTAssertGreaterThan(inside, outside + 6,
                             "The expanded music item lost its own surface when another menu was selected")
        player.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["nav.customize"].waitForExistence(timeout: 3))
        XCTAssertTrue(player.isSelected)
        XCTAssertEqual(player.label, title)
    }

    private func navigationBrightness(_ image: CGImage, point: CGPoint, scale: CGFloat) throws -> Double {
        let rect = CGRect(x: point.x * scale - 3, y: point.y * scale - 3, width: 6, height: 6).integral
        let crop = try XCTUnwrap(image.cropping(to: rect))
        var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: crop.width, height: crop.height,
            bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        let total = stride(from: 0, to: pixels.count, by: 4).reduce(0.0) { sum, index in
            sum + Double(pixels[index]) + Double(pixels[index + 1]) + Double(pixels[index + 2])
        }
        return total / Double(crop.width * crop.height * 3)
    }

    @MainActor
    func testBottomNavigationKeepsItsPositionWhenSwitchingPages() {
        checkNavigationMargins(launch())
    }

    @MainActor
    func testRestoredBottomNavigationKeepsItsPositionWhenSwitchingPages() {
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture"]
        app.launch()
        checkNavigationMargins(app)
    }

    @MainActor
    private func checkNavigationMargins(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["tape.glass"].waitForExistence(timeout: 10))
        app.buttons["tape.glass"].tap()
        let player = app.buttons["nav.nowPlaying"]
        let library = app.buttons["nav.library"]
        let insights = app.buttons["nav.insights"]
        XCTAssertTrue(library.waitForExistence(timeout: 3))
        let capsule = app.otherElements["nav.destinations"]
        XCTAssertTrue(capsule.exists)
        let original = [capsule.frame, player.frame, library.frame, insights.frame,
                        app.buttons["nav.customize"].frame]
        screenshot("navigation-player-before-switch")
        // The portrait iPhones used here reserve 34 logical points for the
        // home gesture. The complete dock must stay above it on either page.
        XCTAssertLessThanOrEqual(original[4].maxY, app.frame.maxY - 34,
                                 "The bottom action extends into the home-gesture safe area")
        // The accessibility group encloses its buttons, excluding the glass
        // surface's padding. Compare it across pages rather than to that edge.
        XCTAssertGreaterThanOrEqual(original[0].minX, app.frame.minX + 16)
        XCTAssertEqual(original[4].maxX, app.frame.maxX - 16, accuracy: 0.5)
        XCTAssertEqual(original[0].midY, original[4].midY, accuracy: 0.5)
        library.tap()
        XCTAssertTrue(app.buttons["library.albums"].waitForExistence(timeout: 5))
        screenshot("navigation-library-after-switch")
        assertNavigationFrames([capsule.frame, player.frame, library.frame, insights.frame,
                                app.buttons["nav.import"].frame], equalTo: original)
        for _ in 0..<2 {
            player.tap()
            XCTAssertTrue(app.buttons["nav.customize"].waitForExistence(timeout: 3))
            assertNavigationFrames([capsule.frame, player.frame, library.frame, insights.frame,
                                    app.buttons["nav.customize"].frame], equalTo: original)
            library.tap()
            XCTAssertTrue(app.buttons["nav.import"].waitForExistence(timeout: 3))
            assertNavigationFrames([capsule.frame, player.frame, library.frame, insights.frame,
                                    app.buttons["nav.import"].frame], equalTo: original)
        }
    }

    @MainActor
    private func assertNavigationFrames(_ actual: [CGRect], equalTo expected: [CGRect],
                                        file: StaticString = #filePath, line: UInt = #line) {
        for (frame, original) in zip(actual, expected) {
            XCTAssertEqual(frame.minX, original.minX, accuracy: 0.5, file: file, line: line)
            XCTAssertEqual(frame.minY, original.minY, accuracy: 0.5, file: file, line: line)
            XCTAssertEqual(frame.width, original.width, accuracy: 0.5, file: file, line: line)
            XCTAssertEqual(frame.height, original.height, accuracy: 0.5, file: file, line: line)
        }
    }

    @MainActor
    func testEmptyTransportAndStudioReturnToSameBlankTape() {
        let app = launch()
        let play = app.buttons["tape.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        screenshot("01-one-tape-default-empty")
        play.tap()
        XCTAssertEqual(play.label, "播放")
        app.buttons["tape.previous"].press(forDuration: 0.8)
        app.buttons["tape.next"].tap()
        XCTAssertEqual(play.label, "播放")
        app.buttons["tape.lcd"].tap()
        XCTAssertTrue(app.buttons["studio.close"].waitForExistence(timeout: 5))
        screenshot("02-one-tape-studio")
        app.buttons["studio.close"].tap()
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertEqual(play.label, "播放")
        app.buttons["tape.glass"].tap()
        XCTAssertTrue(app.buttons["nav.library"].waitForExistence(timeout: 3))
        screenshot("03-one-tape-floating-navigation")
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["nav.library"])
        waitForExpectations(timeout: 9)
        app.buttons["tape.glass"].tap()
        XCTAssertTrue(app.buttons["nav.library"].waitForExistence(timeout: 3))
        app.buttons["tape.glass"].tap()
        XCTAssertFalse(app.buttons["nav.library"].exists)
    }

    @MainActor
    func testEmptyLibrarySegmentsSearchAndSettings() {
        let app = launch()
        XCTAssertTrue(app.buttons["tape.glass"].waitForExistence(timeout: 10))
        app.buttons["tape.glass"].tap()
        app.buttons["nav.library"].tap()
        XCTAssertTrue(app.buttons["library.playlists"].waitForExistence(timeout: 5))
        screenshot("04-one-tape-empty-albums")
        app.buttons["library.playlists"].tap()
        XCTAssertTrue(app.staticTexts["无播放列表"].waitForExistence(timeout: 3))
        app.buttons["library.albums"].tap()
        app.buttons["library.search"].tap()
        let search = app.textFields["library.searchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.typeText("tape")
        XCTAssertTrue(app.staticTexts["无匹配结果"].waitForExistence(timeout: 3))
        screenshot("05-one-tape-library-search")
        app.buttons["library.closeSearch"].tap()
        XCTAssertFalse(search.exists)
        XCTAssertEqual(app.keyboards.count, 0)
        app.buttons["library.filter"].tap()
        let settings = app.buttons["library.openSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        settings.tap()
        XCTAssertTrue(app.staticTexts["小组件"].waitForExistence(timeout: 5))
        screenshot("06-one-tape-settings-medium")
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.52))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97))
        top.press(forDuration: 0.1, thenDragTo: bottom)
        app.buttons["nav.nowPlaying"].tap()
        XCTAssertTrue(app.buttons["tape.play"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMusicSourceEntryCanBeDismissedWithoutChangingLibrary() {
        let app = launch()
        XCTAssertTrue(app.buttons["tape.play"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["tape.source"].exists)
        screenshot("source-switch-removed-player")
        openOneTapeMusicSources(app)
        XCTAssertTrue(app.buttons["source.local"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["source.navidrome"].exists)
        app.buttons["sources.close"].tap()
        XCTAssertTrue(app.buttons["tape.play"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["tape.play"].label, "播放")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-empty"]
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
