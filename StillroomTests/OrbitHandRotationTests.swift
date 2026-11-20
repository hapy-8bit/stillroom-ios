import XCTest
@testable import Stillroom

final class OrbitHandRotationTests: XCTestCase {
    func testReleasePreservesTheVisibleAngleAndCommitsOnlyOnce() throws {
        var hand = OrbitHandRotation()
        hand.update(owner: "song-a", startAngle: 0, angle: 90, position: 20, duration: 120)
        let before = hand.degrees
        XCTAssertEqual(try XCTUnwrap(hand.finish(owner: "song-a", active: true)), 50, accuracy: 0.001)
        XCTAssertEqual(hand.degrees, before)
        XCTAssertEqual(hand.restingDegrees, 90)
        XCTAssertEqual(hand.dragDegrees, 0)
        XCTAssertNil(hand.finish(owner: "song-a", active: true))
    }

    func testNextGestureUsesOnlyItsOwnTurnForMediaSeconds() throws {
        var hand = OrbitHandRotation()
        hand.update(owner: "song-a", startAngle: 0, angle: 90, position: 20, duration: 120)
        _ = hand.finish(owner: "song-a", active: true)
        hand.update(owner: "song-a", startAngle: 10, angle: 40, position: 50, duration: 120)
        XCTAssertEqual(hand.degrees, 120)
        XCTAssertEqual(try XCTUnwrap(hand.finish(owner: "song-a", active: true)), 60, accuracy: 0.001)
        XCTAssertEqual(hand.degrees, 120)
    }

    func testPolarSeamAndInnerGapCannotInventAFullRevolution() throws {
        var hand = OrbitHandRotation()
        hand.update(owner: "song-a", startAngle: 170, angle: -170, position: 0, duration: 360)
        XCTAssertEqual(hand.dragDegrees, 20)
        hand.update(owner: "song-a", startAngle: 170, angle: nil, position: 0, duration: 360)
        hand.update(owner: "song-a", startAngle: 170, angle: 80, position: 0, duration: 360)
        XCTAssertEqual(hand.dragDegrees, 20)
        hand.update(owner: "song-a", startAngle: 170, angle: 90, position: 0, duration: 360)
        XCTAssertEqual(try XCTUnwrap(hand.finish(owner: "song-a", active: true)), 30, accuracy: 0.001)
    }

    func testInterruptedFingerCannotReacquireTheNewTrackBeforeRelease() throws {
        var hand = OrbitHandRotation()
        hand.update(owner: "old", startAngle: 0, angle: 45, position: 10, duration: 360)
        hand.cancel(blockUntilRelease: true)
        hand.update(owner: "new", startAngle: 0, angle: 90, position: 100, duration: 360)
        XCTAssertEqual(hand.degrees, 0)
        XCTAssertNil(hand.finish(owner: "new", active: true))
        hand.update(owner: "new", startAngle: 0, angle: 10, position: 100, duration: 360)
        XCTAssertEqual(try XCTUnwrap(hand.finish(owner: "new", active: true)), 110, accuracy: 0.001)
    }

    func testOwnerMismatchAndHiddenReleaseDiscardOnlyUncommittedMotion() {
        var hand = OrbitHandRotation()
        hand.update(owner: "a", startAngle: 0, angle: 90, position: 0, duration: 360)
        _ = hand.finish(owner: "a", active: true)
        hand.update(owner: "a", startAngle: 0, angle: 40, position: 90, duration: 360)
        hand.update(owner: "b", startAngle: 0, angle: 50, position: 200, duration: 360)
        XCTAssertNil(hand.finish(owner: "b", active: true))
        XCTAssertEqual(hand.degrees, 90)
        hand.update(owner: "a", startAngle: 0, angle: -20, position: 90, duration: 360)
        XCTAssertNil(hand.finish(owner: "a", active: false))
        XCTAssertEqual(hand.degrees, 90)
    }

    func testInvalidMediaCanKeepVisualMotionButNeverReturnsInvalidSeek() {
        var hand = OrbitHandRotation()
        for duration in [0, -1, Double.nan, .infinity] {
            hand.update(owner: "a", startAngle: 0, angle: 90, position: 0, duration: duration)
            XCTAssertNil(hand.finish(owner: "a", active: true))
            XCTAssertTrue(hand.degrees.isFinite)
        }
        hand.resetRecord()
        XCTAssertEqual(hand.degrees, 0)
        hand.update(owner: "a", startAngle: nil, angle: 90, position: 1, duration: 360)
        hand.update(owner: "a", startAngle: 0, angle: 90, position: 1, duration: 360)
        XCTAssertNil(hand.finish(owner: "a", active: true))
    }
}
