import XCTest
@testable import Stillroom

final class CollectionFoldTests: XCTestCase {
    func testProjectedFacesStayJoinedAndUnfoldMonotonically() {
        var previousHeight = -1.0
        for step in 0...100 {
            let pose = CollectionFoldPose(Double(step) / 100)
            XCTAssertTrue((0...90).contains(pose.angle))
            XCTAssertEqual(pose.projectedHeight(56), 56 * cos(pose.angle * .pi / 180), accuracy: 0.00001)
            let pairHeight = pose.projectedHeight(56) * 2
            XCTAssertGreaterThan(pairHeight, previousHeight)
            XCTAssertLessThanOrEqual(pairHeight, 112)
            previousHeight = pairHeight
        }
        XCTAssertEqual(CollectionFoldPose(0).projectedHeight(56), 0)
        XCTAssertEqual(CollectionFoldPose(1).projectedHeight(56), 56)
        XCTAssertEqual(CollectionFoldPose(-2).progress, 0)
        XCTAssertEqual(CollectionFoldPose(.nan).progress, 0)
        XCTAssertEqual(CollectionFoldPose(.infinity).progress, 0)
        XCTAssertEqual(CollectionFoldPose(1).projectedHeight(-20), 0)
    }

    func testDragUsesDownToExpandUpToCollapseAndBoundsOverscroll() {
        XCTAssertEqual(CollectionFoldPose.dragged(base: 0, translation: 56, travel: 112), 0.5)
        XCTAssertEqual(CollectionFoldPose.dragged(base: 1, translation: -56, travel: 112), 0.5)
        XCTAssertEqual(CollectionFoldPose.dragged(base: 0, translation: -200, travel: 112), 0)
        XCTAssertEqual(CollectionFoldPose.dragged(base: 1, translation: 200, travel: 112), 1)
        XCTAssertEqual(CollectionFoldPose.dragged(base: 1, translation: .nan, travel: 112), 1)
        XCTAssertEqual(CollectionFoldPose.dragged(base: 0.5, translation: 200, travel: 0), 0.5)
    }

    func testReleaseHandlesFlickTinyMovementAndInvalidPrediction() {
        XCTAssertEqual(CollectionFoldPose.settled(base: 0, translation: 4, predicted: 200, travel: 112), 0)
        XCTAssertEqual(CollectionFoldPose.settled(base: 1, translation: -4, predicted: -200, travel: 112), 1)
        XCTAssertEqual(CollectionFoldPose.settled(base: 0, translation: 70, predicted: 100, travel: 112), 1)
        XCTAssertEqual(CollectionFoldPose.settled(base: 1, translation: -70, predicted: -100, travel: 112), 0)
        XCTAssertEqual(CollectionFoldPose.settled(base: 0, translation: 70, predicted: .nan, travel: 112), 1)
    }
}
