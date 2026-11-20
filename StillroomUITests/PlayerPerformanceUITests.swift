import XCTest

/// Keep the workload identical before/after rendering changes. These simulator samples
/// compare application CPU/memory; they are not physical-device frame-rate acceptance.
final class PlayerPerformanceUITests: XCTestCase {
    @MainActor
    func testSteadyPlaybackRenderingCost() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        app.buttons["listen.record"].tap()
        let record = quietRecord(app)
        XCTAssertTrue(record.label.hasPrefix("暂停"))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        var metrics: [XCTMetric] = [XCTCPUMetric(application: app), XCTMemoryMetric(application: app)]
        if #available(iOS 26.0, *) { metrics.append(XCTHitchMetric(application: app)) }
        measure(metrics: metrics, options: options) {
            // The runner sleeps, while the separate application process keeps playing/rendering.
            Thread.sleep(forTimeInterval: 4)
        }
        record.tap()
    }
}
