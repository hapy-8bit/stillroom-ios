import XCTest
@testable import Stillroom

final class OneTapeGlassMotionTests: XCTestCase {
    func testUpwardFullHeightClosesAndDownwardFullHeightOpens() {
        let closing = OneTapeGlassMotion.resolve(isOpen: true, translationY: -554, height: 554)
        XCTAssertEqual(closing.progress, 0)
        XCTAssertFalse(closing.targetIsOpen)

        let opening = OneTapeGlassMotion.resolve(isOpen: false, translationY: 554, height: 554)
        XCTAssertEqual(opening.progress, 1)
        XCTAssertTrue(opening.targetIsOpen)
    }

    func testPredictedEndpointDeterminesSettlementIndependentlyFromLiveProgress() {
        let closing = OneTapeGlassMotion.resolve(
            isOpen: true, translationY: -20, predictedTranslationY: -400, height: 600
        )
        XCTAssertEqual(closing.progress, 1 - 20.0 / 600, accuracy: 0.000_001)
        XCTAssertFalse(closing.targetIsOpen)

        let opening = OneTapeGlassMotion.resolve(
            isOpen: false, translationY: 20, predictedTranslationY: 400, height: 600
        )
        XCTAssertEqual(opening.progress, 20.0 / 600, accuracy: 0.000_001)
        XCTAssertTrue(opening.targetIsOpen)
    }

    func testExactHalfwaySettlesClosedAndOnlyLargerProjectionOpens() {
        let halfway = OneTapeGlassMotion.resolve(isOpen: false, translationY: 300, height: 600)
        XCTAssertEqual(halfway.progress, 0.5)
        XCTAssertFalse(halfway.targetIsOpen)
        XCTAssertTrue(OneTapeGlassMotion.resolve(
            isOpen: false, translationY: 300.1, height: 600
        ).targetIsOpen)
    }

    func testOverscrollUsesOneSixthOfExcessAndKeepsClampedProgressAvailable() {
        let pastClosed = OneTapeGlassMotion.resolve(isOpen: false, translationY: -60, height: 600)
        XCTAssertEqual(pastClosed.progress, -0.1 / 6, accuracy: 0.000_001)
        XCTAssertEqual(pastClosed.clampedProgress, 0)

        let pastOpen = OneTapeGlassMotion.resolve(isOpen: true, translationY: 60, height: 600)
        XCTAssertEqual(pastOpen.progress, 1 + 0.1 / 6, accuracy: 0.000_001)
        XCTAssertEqual(pastOpen.clampedProgress, 1)
    }

    func testProportionalLocalCanvasMovementHasSameProgressAcrossRegionSizes() {
        let small = OneTapeGlassMotion.resolve(isOpen: true, translationY: -100, height: 200)
        let large = OneTapeGlassMotion.resolve(isOpen: true, translationY: -200, height: 400)
        XCTAssertEqual(small, large)
        XCTAssertEqual(small.progress, 0.5)
    }

    func testInvalidGeometryAndNonfiniteInputPreserveCommittedPosition() {
        for open in [false, true] {
            let stable = OneTapeGlassMotion.Resolution(progress: open ? 1 : 0, targetIsOpen: open)
            for height: CGFloat in [0, -1, .nan, .infinity, -.infinity] {
                XCTAssertEqual(OneTapeGlassMotion.resolve(
                    isOpen: open, translationY: 100, predictedTranslationY: 200, height: height
                ), stable)
            }
            for invalid: CGFloat in [.nan, .infinity, -.infinity] {
                XCTAssertEqual(OneTapeGlassMotion.resolve(
                    isOpen: open, translationY: invalid, height: 600
                ), stable)
                XCTAssertEqual(OneTapeGlassMotion.resolve(
                    isOpen: open, translationY: 100, predictedTranslationY: invalid, height: 600
                ), stable)
            }
        }
    }

    func testFiniteInputsWhoseDivisionOverflowsStillProduceStableFiniteResult() {
        let result = OneTapeGlassMotion.resolve(
            isOpen: true,
            translationY: .greatestFiniteMagnitude,
            predictedTranslationY: .greatestFiniteMagnitude,
            height: .leastNonzeroMagnitude
        )
        XCTAssertEqual(result.progress, 1)
        XCTAssertTrue(result.progress.isFinite)
        XCTAssertTrue(result.targetIsOpen)
    }
}
