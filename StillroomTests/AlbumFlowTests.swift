import XCTest
@testable import Stillroom

final class AlbumFlowTests: XCTestCase {
    func testCoverFlowClampsEdgesAndLimitsAnExtremeFlick() {
        XCTAssertEqual(AlbumFlowMotion.destination(index: 0, count: 3, translation: -180, predicted: -200, stride: 220), 1)
        XCTAssertEqual(AlbumFlowMotion.destination(index: 0, count: 100, translation: -100, predicted: -100_000, stride: 220), 2)
        XCTAssertEqual(AlbumFlowMotion.destination(index: 0, count: 3, translation: 180, predicted: 200, stride: 220), 0)
        XCTAssertEqual(AlbumFlowMotion.destination(index: 2, count: 3, translation: -180, predicted: -200, stride: 220), 2)
        XCTAssertEqual(AlbumFlowMotion.destination(index: 1, count: 3, translation: 2, predicted: -500, stride: 220), 1)
        XCTAssertEqual(AlbumFlowMotion.destination(index: 1, count: 0, translation: -200, predicted: -200, stride: 220), 0)
        XCTAssertEqual(AlbumFlowMotion.destination(index: 1, count: 3, translation: .nan, predicted: -200, stride: 220), 1)
        XCTAssertEqual(AlbumFlowMotion.drag(100, index: 0, count: 3), 24)
        XCTAssertEqual(AlbumFlowMotion.drag(-100, index: 0, count: 3), -100)
    }

    func testCoverDepthIsSymmetricAndBounded() {
        for distance in stride(from: -5.0, through: 5, by: 0.1) {
            let left = AlbumCoverPose(distance: distance)
            let right = AlbumCoverPose(distance: -distance)
            XCTAssertEqual(left.scale, right.scale)
            XCTAssertEqual(left.rotation, -right.rotation, accuracy: 0.001)
            XCTAssertTrue((0.7...1).contains(left.scale))
            XCTAssertTrue((0...1).contains(left.opacity))
        }
        XCTAssertEqual(AlbumCoverPose(distance: .nan).rotation, 0)
    }

    func testRecordGesturesKeepTonearmSeekingSeparateFromSceneNavigation() {
        func action(_ x: Double, _ y: Double, _ predicted: Double = 0, arm: Bool = false) -> QuietPlayerGesture {
            QuietPlayerGesture.resolve(x: x, y: y, predictedY: predicted, width: 402, height: 874, startsOnArm: arm)
        }
        XCTAssertEqual(action(-120, 5), .next)
        XCTAssertEqual(action(120, 5), .previous)
        XCTAssertEqual(action(0, 120), .dismiss)
        XCTAssertEqual(action(0, 40, 150), .dismiss)
        XCTAssertEqual(action(0, 120, arm: true), .none)
        XCTAssertEqual(action(0, -200), .none)
        XCTAssertEqual(action(12, 15, 500), .none)
        XCTAssertEqual(action(90, 100), .none)
        XCTAssertEqual(action(.nan, 120), .none)
    }
}
