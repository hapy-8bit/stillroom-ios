import XCTest
@testable import Stillroom

final class MechanicalMotionTests: XCTestCase {
    func testPaperWheelMovesBetweenSamplesAndKeepsItsPhaseAtTheNextSample() {
        var wheel = MechanicalWheelMotion(rate: -6)
        wheel.observe(seconds: 10, running: true, remaining: 20, at: 100)
        XCTAssertEqual(wheel.angle(at: 100), -60, accuracy: 0.001)
        XCTAssertEqual(wheel.angle(at: 100.125), -60.75, accuracy: 0.001)
        let before = wheel.angle(at: 100.25)
        wheel.observe(seconds: 10.25, running: true, remaining: 19.75, at: 100.25)
        XCTAssertEqual(wheel.angle(at: 100.25), before, accuracy: 0.001)
        XCTAssertEqual(wheel.angle(at: 100.375), -62.25, accuracy: 0.001)
    }

    func testPauseFreezesTheWheelAndMissingSnapshotsCannotKeepItSpinning() {
        var wheel = MechanicalWheelMotion(rate: -6)
        wheel.observe(seconds: 0, running: true, remaining: 56, at: 100)
        XCTAssertEqual(wheel.angle(at: 100.8), -2.4, accuracy: 0.001)
        XCTAssertEqual(wheel.angle(at: 110), -2.4, accuracy: 0.001)
        wheel.observe(seconds: 0.2, running: false, remaining: 55.8, at: 100.2)
        XCTAssertEqual(wheel.angle(at: 101), -1.2, accuracy: 0.001)
        XCTAssertEqual(wheel.angle(at: 105), -1.2, accuracy: 0.001)
        wheel.observe(seconds: 55.9, running: true, remaining: 0.1, at: 106, reset: true)
        XCTAssertEqual(wheel.angle(at: 108), wheel.angle(at: 109), accuracy: 0.001)
    }

    func testSongResetUsesTheShortArcAcrossTheZeroSeam() {
        var wheel = MechanicalWheelMotion(rate: -6)
        wheel.observe(seconds: 59, running: false, remaining: 0, at: 100)
        wheel.observe(seconds: 0, running: false, remaining: 56, at: 101, reset: true)
        XCTAssertEqual(wheel.angle(at: 101), -354, accuracy: 0.001)
        XCTAssertEqual(wheel.angle(at: 102), -360, accuracy: 0.001)
        XCTAssertEqual(MechanicalWheelMotion.shortestTurn(from: 359, to: 1), 2)
        XCTAssertEqual(MechanicalWheelMotion.shortestTurn(from: 1, to: 359), -2)
    }

    func testRemainingWheelRunsInTheOppositeDirectionAndRejectsInvalidSamples() {
        var wheel = MechanicalWheelMotion(rate: 6)
        wheel.observe(seconds: 56, running: true, remaining: 56, at: 100)
        XCTAssertEqual(wheel.angle(at: 100.2), -334.8, accuracy: 0.001)
        wheel.observe(seconds: .nan, running: false, remaining: 0, at: 100.2)
        wheel.observe(seconds: .greatestFiniteMagnitude, running: false, remaining: 0, at: 100.2)
        XCTAssertEqual(wheel.angle(at: 100.2), -334.8, accuracy: 0.001)
        XCTAssertTrue(wheel.angle(at: .infinity).isFinite)
    }

    func testDigitCarryUsesTenForOnesAndSixForSecondsTens() {
        XCTAssertEqual(MechanicalDigitMotion.target(from: 9, digit: 0, radix: 10, increasing: true, jump: false), 10)
        XCTAssertEqual(MechanicalDigitMotion.target(from: 5, digit: 0, radix: 6, increasing: true, jump: false), 6)
        XCTAssertEqual(MechanicalDigitMotion.target(from: 0, digit: 9, radix: 10, increasing: false, jump: false), -1)
        XCTAssertEqual(MechanicalDigitMotion.target(from: 0, digit: 5, radix: 6, increasing: false, jump: false), -1)
        XCTAssertEqual(MechanicalDigitMotion.target(from: 20, digit: 0, radix: 10, increasing: true, jump: false), 20)
    }

    func testDigitJumpTakesAShortRouteInsteadOfScrollingThroughTheWholeTrack() {
        XCTAssertEqual(MechanicalDigitMotion.target(from: 1, digit: 8, radix: 10, increasing: true, jump: true), -2)
        XCTAssertEqual(MechanicalDigitMotion.target(from: 9, digit: 1, radix: 10, increasing: false, jump: true), 11)
        XCTAssertEqual(MechanicalDigitMotion.target(from: .nan, digit: 1, radix: 10, increasing: true, jump: false), 0)
    }

    func testFingerReleaseCoastsOnlyALittleAndSettlesOnAnUnwrappedDetent() {
        let target = MechanicalWheelMotion.detent(from: 348, drag: 20, predicted: 200, reducedMotion: false)
        XCTAssertEqual(target, 384)
        XCTAssertEqual(target.truncatingRemainder(dividingBy: 6), 0)
        XCTAssertLessThan(target - (348 + 20), 20)
        XCTAssertEqual(MechanicalWheelMotion.detent(from: 348, drag: 20, predicted: 200, reducedMotion: true), 366)
        XCTAssertEqual(MechanicalWheelMotion.detent(from: 0, drag: -15, predicted: .nan, reducedMotion: false), -18)
    }
}
