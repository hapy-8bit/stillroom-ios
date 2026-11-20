import XCTest
@testable import Stillroom

final class TrackChangeMotionTests: XCTestCase {
    func testNeedleLiftsBeforeRecordsMoveAndLandsOnlyAfterIncomingSettles() {
        func pose(_ p: Double) -> TrackChangeMotion { TrackChangeMotion(progress: p, direction: 1, reducedMotion: false) }
        XCTAssertEqual(pose(0).outgoingOpacity, 1)
        XCTAssertEqual(pose(0).incomingOpacity, 0)
        XCTAssertEqual(pose(0.16).needle, 0)
        XCTAssertEqual(pose(0.16).outgoingX, 0)
        XCTAssertEqual(pose(0.5).needle, 0)
        XCTAssertEqual(pose(0.78).incomingX, 0)
        XCTAssertEqual(pose(0.78).incomingScale, 1)
        XCTAssertEqual(pose(0.78).needle, 0)
        XCTAssertEqual(pose(1).needle, 1)
        XCTAssertEqual(pose(1).incomingOpacity, 1)
        XCTAssertEqual(pose(1).outgoingOpacity, 0)
    }

    func testDirectionMirrorsMovementAndInvalidProgressIsBounded() {
        for p in stride(from: 0.0, through: 1, by: 0.025) {
            let next = TrackChangeMotion(progress: p, direction: 1, reducedMotion: false)
            let previous = TrackChangeMotion(progress: p, direction: -1, reducedMotion: false)
            XCTAssertEqual(next.incomingX, -previous.incomingX)
            XCTAssertEqual(next.outgoingX, -previous.outgoingX)
            XCTAssertTrue((0...1).contains(next.needle))
            XCTAssertTrue((0...1).contains(next.incomingOpacity))
            XCTAssertTrue((0...1).contains(next.outgoingOpacity))
        }
        XCTAssertEqual(TrackChangeMotion(progress: .nan, direction: 1, reducedMotion: false).needle, 1)
        XCTAssertEqual(TrackChangeMotion(progress: 2, direction: 1, reducedMotion: false).incomingOpacity, 1)
    }

    func testReducedMotionCrossfadesWithoutMovingOrLiftingTheArm() {
        let pose = TrackChangeMotion(progress: 0.4, direction: -1, reducedMotion: true)
        XCTAssertEqual(pose.incomingX, 0)
        XCTAssertEqual(pose.outgoingX, 0)
        XCTAssertEqual(pose.incomingScale, 1)
        XCTAssertEqual(pose.needle, 1)
        XCTAssertEqual(pose.incomingOpacity + pose.outgoingOpacity, 1)
    }
}
