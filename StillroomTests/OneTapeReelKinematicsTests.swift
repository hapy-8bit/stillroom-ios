import XCTest
@testable import Stillroom

final class OneTapeReelKinematicsTests: XCTestCase {
    func testMatchedReelsKeepEqualConstantSpeedAcrossProgressAndWinding() {
        for rate in [1.0, 14, -14] {
            var expected: Double?
            for progress in [0.0, 0.3, 0.5, 1.0] {
                var motion = OneTapeReelKinematics()
                motion.update(rate: rate, progress: progress, at: 0, layout: .matched)
                let frame = motion.frame(at: 0.05)
                XCTAssertEqual(frame.supplyRadians, frame.takeupRadians, accuracy: 0.000001)
                if let expected { XCTAssertEqual(frame.supplyRadians, expected, accuracy: 0.000001) }
                expected = frame.supplyRadians
            }
        }
    }

    func testChangingLayoutAndProgressPreservesPhaseAndMatchedPauseFreezes() {
        var motion = settled(progress: 0.1)
        motion.update(rate: 1, progress: 0.1, at: 0)
        let before = motion.frame(at: 0.1)
        motion.update(rate: 1, progress: 0.9, at: 0.1, layout: .matched)
        XCTAssertEqual(motion.frame(at: 0.1), before)
        let later = motion.frame(at: 0.2)
        XCTAssertEqual(forwardDelta(before.supplyRadians, later.supplyRadians),
                       forwardDelta(before.takeupRadians, later.takeupRadians), accuracy: 0.000001)
        motion.update(rate: 0, progress: 0.9, at: 0.2, layout: .matched)
        let stopped = motion.frame(at: 0.2)
        XCTAssertEqual(motion.frame(at: 1000), stopped)
        motion.update(rate: -14, progress: 0.1, at: 1000, layout: .matched)
        let reverse = motion.frame(at: 1000.01)
        XCTAssertEqual(forwardDelta(reverse.supplyRadians, stopped.supplyRadians),
                       forwardDelta(reverse.takeupRadians, stopped.takeupRadians), accuracy: 0.000001)
    }

    func testConstantTapeSpeedMakesFullPackSlowerAndExchangesAcrossTheSide() {
        for progress in [0.0, 0.5, 1.0] {
            var motion = settled(progress: progress)
            motion.update(rate: 1, progress: progress, at: 0)
            let frame = motion.frame(at: 0.1)
            let radii = OneTapeTapeGeometry.radii(progress: progress)
            XCTAssertEqual(frame.supplyRadians * radii.supply,
                           OneTapeReelKinematics.linearSpeed * 0.1, accuracy: 0.000001)
            XCTAssertEqual(frame.takeupRadians * radii.takeup,
                           OneTapeReelKinematics.linearSpeed * 0.1, accuracy: 0.000001)
            if progress < 0.5 { XCTAssertLessThan(frame.supplyRadians, frame.takeupRadians) }
            if progress == 0.5 { XCTAssertEqual(frame.supplyRadians, frame.takeupRadians, accuracy: 0.000001) }
            if progress > 0.5 { XCTAssertGreaterThan(frame.supplyRadians, frame.takeupRadians) }
            XCTAssertEqual(frame.exposureDegrees, 0)
        }
    }

    func testProgressChangeCannotRecalculateThePreviousThousandSecondsOfRotation() {
        var motion = settled(progress: 0.01)
        motion.update(rate: 1, progress: 0.01, at: 0)
        let before = motion.frame(at: 1000.123)
        motion.update(rate: 1, progress: 0.97, at: 1000.123)
        let after = motion.frame(at: 1000.123)
        XCTAssertEqual(before.supplyRadians, after.supplyRadians, accuracy: 0.000001)
        XCTAssertEqual(before.takeupRadians, after.takeupRadians, accuracy: 0.000001)
        XCTAssertEqual(before.progress, after.progress, accuracy: 0.000001)
        let running = motion.frame(at: 1000.143)
        XCTAssertGreaterThan(forwardDelta(after.supplyRadians, running.supplyRadians), 0)
        XCTAssertLessThan(forwardDelta(after.supplyRadians, running.supplyRadians), 0.1)
        XCTAssertGreaterThan(forwardDelta(after.takeupRadians, running.takeupRadians), 0)
    }

    func testChangingRadiiIntegrateTheSameTapeTravelWithoutHistoryDrift() {
        var motion = settled(progress: 0)
        motion.update(rate: 1, progress: 1, at: 0)
        let end = motion.frame(at: 0.25)
        let startRadii = OneTapeTapeGeometry.radii(progress: 0)
        let endRadii = OneTapeTapeGeometry.radii(progress: 1)
        let expected = OneTapeReelKinematics.linearSpeed * 2 * 0.25 /
            (startRadii.supply + endRadii.supply)
        XCTAssertEqual(end.supplyRadians, expected, accuracy: 0.000001)
        XCTAssertEqual(end.takeupRadians, expected, accuracy: 0.000001)
        XCTAssertEqual(end.progress, 1)
    }

    func testFastWindSweepsPackThenBrakeFreezesBeforeNormalPlayback() {
        var motion = settled(progress: 0.1)
        motion.update(rate: OneTapeTransportRules.trackChangeRate, progress: 0.8, at: 0)
        let duration = OneTapeTransportRules.trackChangeWindSeconds
        XCTAssertEqual(motion.frame(at: duration / 2).progress, 0.45, accuracy: 0.000001)
        XCTAssertGreaterThan(motion.frame(at: 0.01).exposureDegrees, 0)
        let wound = motion.frame(at: duration)
        XCTAssertEqual(wound.progress, 0.8, accuracy: 0.000001)
        motion.update(rate: 0, progress: 0.8, at: duration)
        let braked = motion.frame(at: duration + 0.14)
        XCTAssertEqual(braked.supplyRadians, wound.supplyRadians, accuracy: 0.000001)
        XCTAssertEqual(braked.takeupRadians, wound.takeupRadians, accuracy: 0.000001)
        XCTAssertEqual(braked.exposureDegrees, 0)
        motion.update(rate: 1, progress: 0.8, at: duration + 0.14)
        XCTAssertEqual(motion.frame(at: duration + 0.14), braked)
        XCTAssertGreaterThan(forwardDelta(braked.supplyRadians,
            motion.frame(at: duration + 0.15).supplyRadians), 0)
    }

    func testDirectionChangePreservesBothPhasesAndReversesOnlyFutureTravel() {
        var motion = settled(progress: 0.5)
        motion.update(rate: 14, progress: 0.5, at: 0)
        let before = motion.frame(at: 0.01)
        motion.update(rate: -14, progress: 0.5, at: 0.01)
        XCTAssertEqual(motion.frame(at: 0.01), before)
        let reversed = motion.frame(at: 0.02)
        XCTAssertEqual(reversed.supplyRadians, 0, accuracy: 0.000001)
        XCTAssertEqual(reversed.takeupRadians, 0, accuracy: 0.000001)
    }

    func testPauseAndInactiveIntervalsNeverAccumulateCatchUpMotion() {
        var motion = settled(progress: 0.4)
        motion.update(rate: 1, progress: 0.4, at: 0)
        let before = motion.frame(at: 0.4)
        motion.update(rate: 0, progress: 0.4, at: 0.4)
        XCTAssertEqual(motion.frame(at: 500), before)
        motion.update(rate: 1, progress: 0.4, at: 500)
        XCTAssertEqual(motion.frame(at: 500), before)
        let later = motion.frame(at: 500.01)
        XCTAssertLessThan(forwardDelta(before.supplyRadians, later.supplyRadians), 0.1)
    }

    func testInvalidInputsCannotPoisonPhaseOrMoveTheMonotonicAnchorBackwards() {
        var motion = settled(progress: 0.3)
        motion.update(rate: 1, progress: 0.3, at: 5)
        let before = motion.frame(at: 5)
        motion.update(rate: 14, progress: 1, at: 4)
        XCTAssertEqual(motion.frame(at: 5), before)
        motion.update(rate: .infinity, progress: .nan, at: .nan)
        XCTAssertEqual(motion.frame(at: 5), before)
        motion.update(rate: .infinity, progress: .nan, at: 5)
        let stopped = motion.frame(at: 1e12)
        XCTAssertEqual(stopped.supplyRadians, before.supplyRadians)
        XCTAssertEqual(stopped.takeupRadians, before.takeupRadians)
        XCTAssertTrue(stopped.progress.isFinite)
    }

    private func settled(progress: Double) -> OneTapeReelKinematics {
        var result = OneTapeReelKinematics()
        result.update(rate: 0, progress: progress, at: 0)
        return result
    }

    private func forwardDelta(_ first: Double, _ second: Double) -> Double {
        (second - first + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
    }
}
