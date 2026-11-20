import XCTest

final class OrbitSmokeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testThreeHomeViewsAndUtilityImportRemainReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--original-demo-fixture", "-reducedMotion", "YES", "-recordOpening.completed.v1", "YES"]
        app.launchArguments += ["--legacy-stillroom"]
        app.launch()
        XCTAssertTrue(app.otherElements["room.library"].waitForExistence(timeout: 8))
        app.buttons["room.navigation.player"].tap()
        XCTAssertTrue(app.otherElements["orbit.home"].waitForExistence(timeout: 8))
        revealTools(in: app)
        app.buttons["orbit.more"].tap()
        app.buttons["orbit.views"].tap()
        // UIKit's nested menu exposes the real item title but drops the SwiftUI identifier.
        let grid = app.buttons["唱片列表"]
        XCTAssertTrue(grid.waitForExistence(timeout: 3))
        grid.tap()
        XCTAssertTrue(app.otherElements["orbit.grid"].waitForExistence(timeout: 3))
        app.buttons["orbit.more"].tap()
        app.buttons["orbit.import"].tap()
        XCTAssertTrue(app.buttons["import.bundle"].waitForExistence(timeout: 4))
        app.buttons["import.close"].tap()
        app.buttons["orbit.views"].tap(); app.buttons["orbit.view.turntable"].tap()
        XCTAssertTrue(app.otherElements["orbit.turntable"].waitForExistence(timeout: 3))
        revealTools(in: app)
        app.buttons["orbit.appearance"].tap()
        XCTAssertTrue(app.buttons["orbit.style.material.split"].waitForExistence(timeout: 3))
        app.buttons["orbit.style.material.black"].tap()
        app.buttons["orbit.style.more"].tap()
        app.buttons["orbit.style.editStickers"].tap()
        XCTAssertTrue(app.buttons["orbit.stickers.cancel"].waitForExistence(timeout: 3))
        app.buttons["orbit.stickers.cancel"].tap()
        let silver = app.buttons["orbit.style.background.silver"]
        let panel = app.scrollViews["orbit.style.panel"]
        let backgrounds = app.scrollViews["orbit.style.backgrounds"]
        for _ in 0..<4 {
            if silver.exists && silver.isHittable { break }
            if backgrounds.exists && backgrounds.isHittable { backgrounds.swipeRight() }
            else { panel.swipeUp() }
        }
        silver.tap()
        XCTAssertTrue(silver.isSelected)
        let done = app.buttons["orbit.style.done"]
        for _ in 0..<3 {
            if done.isHittable { break }
            panel.swipeUp()
        }
        done.tap()
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Orbit final turntable — simulator"
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor private func revealTools(in app: XCUIApplication) {
        let reveal = app.buttons["orbit.tools.reveal"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 3))
        reveal.tap()
        XCTAssertTrue(app.buttons["orbit.rotate"].waitForExistence(timeout: 3))
    }
}
