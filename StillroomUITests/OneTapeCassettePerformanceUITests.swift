import XCTest
import UIKit

/// Same real phone, selected queue, screen and timed workload before/after.
/// CPU/memory and hitch metrics are evidence, not a guessed nominal FPS.
final class OneTapeCassettePerformanceUITests: XCTestCase {
    @MainActor
    func testSculptedSteadyPlayback() { measurePlayback(style: "strata") }

    @MainActor
    func testClassicSteadyPlayback() { measurePlayback(style: "classic") }

    @MainActor
    func testNormalAppearancePlaybackAndPause() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = []
        app.launch()
        let lcd = app.buttons["tape.lcd"]
        XCTAssertTrue(lcd.waitForExistence(timeout: 15))
        wait { !lcd.label.contains("还没有磁带") }
        let play = app.buttons["tape.play"]
        if play.label == "播放" { play.tap() }
        wait { (lcd.value as? String ?? "").contains("播放中") }
        if ProcessInfo.processInfo.environment["ONE_TAPE_PROFILE_NORMAL"] == "1" {
            print("CASSETTE_NORMAL_PERF_READY")
            Thread.sleep(forTimeInterval: 14)
        } else {
            Thread.sleep(forTimeInterval: 1)
        }
        let playing = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        playing.name = "normal61-playing"
        playing.lifetime = .keepAlways
        add(playing)
        play.tap()
        wait { (lcd.value as? String ?? "").contains("已暂停") }
        Thread.sleep(forTimeInterval: 0.35)
        let frozen = pixels(lcd.screenshot().image)
        XCTAssertNotNil(frozen)
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(pixels(lcd.screenshot().image), frozen)
        let paused = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        paused.name = "normal61-paused"
        paused.lifetime = .keepAlways
        add(paused)
    }

    @MainActor
    private func measurePlayback(style: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--one-tape-appearance-fixture", "--reset-one-tape-appearance-fixture"]
        app.launch()
        let lcd = app.buttons["tape.lcd"]
        XCTAssertTrue(lcd.waitForExistence(timeout: 15))
        wait { !lcd.label.contains("还没有磁带") }
        if !app.buttons["nav.customize"].exists { app.buttons["tape.glass"].tap() }
        app.buttons["nav.customize"].tap()
        XCTAssertTrue(app.buttons["customization.close"].waitForExistence(timeout: 5))
        app.buttons["customization.tab.tape"].tap()
        let tile = app.buttons["customization.tape.\(style)"]
        let scroll = app.scrollViews["customization.scroll"]
        for _ in 0..<5 {
            if tile.isHittable { break }
            scroll.swipeUp()
        }
        wait { tile.isHittable }
        tile.tap()
        app.buttons["customization.tab.screen"].tap()
        let screen = app.buttons["customization.screen.trails"]
        for _ in 0..<5 {
            if screen.isHittable { break }
            scroll.swipeUp()
        }
        wait { screen.isHittable }
        screen.tap()
        app.buttons["customization.close"].tap()
        wait { !app.buttons["customization.close"].exists }
        if app.buttons["nav.customize"].exists { app.buttons["tape.glass"].tap() }
        let play = app.buttons["tape.play"]
        if play.label == "播放" { play.tap() }
        wait { (lcd.value as? String ?? "").contains("播放中") }
        Thread.sleep(forTimeInterval: 3)
        print("CASSETTE_PERF_READY \(style)")
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        var metrics: [XCTMetric] = [XCTClockMetric(), XCTCPUMetric(application: app),
                                     XCTMemoryMetric(application: app)]
        if #available(iOS 26, *) { metrics.append(XCTHitchMetric(application: app)) }
        measure(metrics: metrics, options: options) {
            Thread.sleep(forTimeInterval: 6)
        }
        XCTAssertTrue((lcd.value as? String ?? "").contains("播放中"))
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "performance-\(style)-playing"
        image.lifetime = .keepAlways
        add(image)
        play.tap()
        wait { (lcd.value as? String ?? "").contains("已暂停") }
        Thread.sleep(forTimeInterval: 0.35)
        let frozen = pixels(lcd.screenshot().image)
        XCTAssertNotNil(frozen)
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(pixels(lcd.screenshot().image), frozen,
            "A completed background frame must not move the paused screen")
    }

    @MainActor
    private func wait(_ condition: @escaping () -> Bool) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 20), .completed)
    }

    private func pixels(_ image: UIImage) -> Data? {
        guard let data = image.cgImage?.dataProvider?.data else { return nil }
        return data as Data
    }
}
