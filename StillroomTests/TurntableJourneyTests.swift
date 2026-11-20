import XCTest
@testable import Stillroom

final class TurntableJourneyTests: XCTestCase {
    let container = CGRect(x: 12, y: 24, width: 402, height: 874)
    var origin: SleeveFlightOrigin { SleeveFlightOrigin(viewport: CGRect(x: 12, y: 86, width: 402, height: 730), artworkTop: 108) }

    func pose(_ progress: Double, reduced: Bool = false, fromSleeve: Bool = true) -> TurntableJourneyPose {
        TurntableJourneyPose(progress: progress, origin: fromSleeve ? origin : nil, container: container, reducedMotion: reduced)
    }

    func testFlightStartsAtTheMeasuredSleeveWithoutAFrameJump() {
        let start = pose(0)
        let measured = origin.localLayout(in: container)
        XCTAssertEqual(start.record, measured.record)
        XCTAssertEqual(start.sleeve, measured.sleeve)
        XCTAssertEqual(start.record.minY, 62 + 108 + 402 * 0.09, accuracy: 0.001)
        XCTAssertEqual(start.sleeveAngle, -8)
        XCTAssertEqual(start.sleeveOpacity, 1)
        XCTAssertEqual(start.backdrop, 0)
        XCTAssertEqual(start.armOpacity, 0)
    }

    func testRimClearsTheSleeveBeforeCarryAndNeedleWaitsUntilPlaced() {
        let extracted = pose(0.36)
        XCTAssertGreaterThan(extracted.record.minX, extracted.sleeve.maxX + 16)
        XCTAssertEqual(extracted.sleeveOpacity, 1)
        XCTAssertEqual(extracted.needle, 0)
        let placed = pose(0.76)
        let target = PlayerStageGeometry(size: container.size).record
        XCTAssertEqual(placed.record.minX, target.minX, accuracy: 0.001)
        XCTAssertEqual(placed.record.minY, target.minY, accuracy: 0.001)
        XCTAssertEqual(placed.record.width, target.width, accuracy: 0.001)
        XCTAssertEqual(placed.needle, 0)
        XCTAssertEqual(placed.controls, 0)
        XCTAssertEqual(pose(0.8).needle, 0)
        XCTAssertGreaterThan(pose(0.9).needle, 0)
        XCTAssertEqual(pose(1).needle, 1)
        XCTAssertEqual(pose(1).controls, 1)
        XCTAssertEqual(pose(1).sleeveOpacity, 0)
    }

    func testStageBoundariesAreContinuousAndReducedMotionDoesNotMoveArtwork() {
        for boundary in [0.36, 0.76, 0.8] {
            let a = pose(boundary - 0.00001).record
            let b = pose(boundary + 0.00001).record
            XCTAssertEqual(a.midX, b.midX, accuracy: 0.01)
            XCTAssertEqual(a.midY, b.midY, accuracy: 0.01)
            XCTAssertEqual(a.width, b.width, accuracy: 0.01)
        }
        XCTAssertEqual(pose(0, reduced: true).record, pose(1, reduced: true).record)
        XCTAssertEqual(pose(0.2, reduced: true).sleeveOpacity, 0)
        XCTAssertEqual(pose(0.5, fromSleeve: false).sleeveOpacity, 0)
        XCTAssertEqual(pose(-1).record, pose(0).record)
        XCTAssertEqual(pose(.nan).record, pose(0).record)
        XCTAssertEqual(pose(2).record, pose(1).record)
    }
}
