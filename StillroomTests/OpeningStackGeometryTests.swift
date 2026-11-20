import XCTest
@testable import Stillroom

final class OpeningStackGeometryTests: XCTestCase {
    func testRecoveredDimensionsSeparateSourceCoverFromSelectedTarget() {
        let phone = OpeningStackGeometry(size: CGSize(width: 375, height: 812))
        XCTAssertEqual(phone.shortSideFactor, 0)
        XCTAssertEqual(phone.coverSide, 305)
        XCTAssertEqual(phone.stride, 87)
        XCTAssertEqual(phone.spineThickness, 16)
        XCTAssertEqual(phone.spineFontSize, 10)
        XCTAssertEqual(phone.openFrame.width, 295)
        XCTAssertEqual(phone.openFrame.midX, 187.5)
        XCTAssertEqual(phone.extractionX, -(295 + 375 + 10) / 2)

        let pad = OpeningStackGeometry(size: CGSize(width: 834, height: 1194), isPad: true)
        XCTAssertEqual(pad.shortSideFactor, 1)
        XCTAssertEqual(pad.coverSide, 634)
        XCTAssertEqual(pad.stride, 128)
        XCTAssertEqual(pad.spineThickness, 20)
        XCTAssertEqual(pad.spineFontSize, 14)
        XCTAssertEqual(pad.openFrame.width, 834 * 0.8, accuracy: 0.000001)
    }

    func testShortSideInterpolationAndInvalidDimensionsStayFinite() {
        let geometry = OpeningStackGeometry(size: CGSize(width: 402, height: 874))
        XCTAssertEqual(geometry.shortSideFactor, 27.0 / 459, accuracy: 0.000001)
        XCTAssertEqual(geometry.coverSide, 402 - 70 - 130 * 27.0 / 459, accuracy: 0.000001)
        XCTAssertEqual(geometry.stride, 87 + 41 * 27.0 / 459, accuracy: 0.000001)
        let invalid = OpeningStackGeometry(size: CGSize(width: .nan, height: -.infinity))
        XCTAssertEqual(invalid.coverSide, 1)
        XCTAssertTrue(invalid.openFrame.width.isFinite)
        XCTAssertTrue(invalid.extractionX.isFinite)
    }

    func testAngleUsesMeasuredRowAndGravityWithEpsilonBeforeClampAndZIndex() {
        let geometry = OpeningStackGeometry(size: CGSize(width: 375, height: 812))
        let center = geometry.pose(midpoint: 406, gravityY: 0)
        XCTAssertEqual(center.rawAngle, 0.01)
        XCTAssertEqual(center.angle, 0.01)
        XCTAssertEqual(center.zIndex, -0.01)
        let influenced = geometry.pose(midpoint: 406 + 87, gravityY: 0.5)
        XCTAssertEqual(influenced.angle, -5)
        let far = geometry.pose(midpoint: 406 + 87 * 20, gravityY: 0)
        XCTAssertEqual(far.rawAngle, 200)
        XCTAssertEqual(far.angle, 60)
        XCTAssertEqual(far.zIndex, -200)
        XCTAssertEqual(geometry.pose(midpoint: 406, gravityY: .nan).rawAngle, 0.01)
    }

    func testTwoFiniteAlbumsRemainTwoDistinctRowsAndFocusOnlyMovesTheOrigin() {
        let geometry = OpeningStackGeometry(size: CGSize(width: 375, height: 812))
        let rows = (0..<2).map { geometry.rowMidpoint(index: $0, count: 2, scrollOffset: 0) }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1] - rows[0], geometry.stride)
        XCTAssertEqual((rows[0] + rows[1]) / 2, geometry.axisLength / 2)
        let focus = geometry.centeredScrollOffset(index: 0, count: 2)
        XCTAssertEqual(geometry.rowMidpoint(index: 0, count: 2, scrollOffset: focus), 406)
    }

    func testSeparateCoverAndSpineHingesMatchBothAngleSigns() {
        let positive = OpeningStackPose(rawAngle: 20, angle: 20)
            .surfaces(progress: 0, coverSide: 305, spineThickness: 16, portrait: true)
        XCTAssertEqual(positive.coverDegrees, 110)
        XCTAssertEqual(positive.spineDegrees, 20)
        XCTAssertEqual(positive.mirrorScaleX, -1)
        XCTAssertEqual(positive.spineAnchorY, 0)
        XCTAssertEqual(positive.coverOffsetY, (305 - 16) / 2.0)
        XCTAssertEqual(positive.innerHeight, 0)

        let negative = OpeningStackPose(rawAngle: -20, angle: -20)
            .surfaces(progress: 0, coverSide: 305, spineThickness: 16, portrait: true)
        XCTAssertEqual(negative.coverDegrees, 70)
        XCTAssertEqual(negative.spineDegrees, -20)
        XCTAssertEqual(negative.mirrorScaleX, 1)
        XCTAssertEqual(negative.spineAnchorY, 1)
        XCTAssertEqual(negative.coverOffsetY, (305 + 16) / 2.0)
    }

    func testFrontTransformHasZeroCoverRotationAndCorrectNestedFrame() {
        let pose = OpeningStackPose(rawAngle: 25, angle: 25)
        let front = pose.surfaces(progress: 1, coverSide: 305, spineThickness: 16, portrait: true)
        XCTAssertEqual(front.coverDegrees, 0)
        XCTAssertEqual(front.spineDegrees, -90)
        XCTAssertEqual(front.mirrorScaleX, 1)
        XCTAssertEqual(front.innerOffsetY, -8)
        XCTAssertEqual(front.innerHeight, 305)
        XCTAssertEqual(front.innerZDegrees, -90)
        XCTAssertEqual(front.wrapperZDegrees, 0)
        let wide = pose.surfaces(progress: 1, coverSide: 305, spineThickness: 16, portrait: false)
        XCTAssertEqual(wide.innerZDegrees, 0)
        XCTAssertEqual(wide.wrapperZDegrees, -90)
    }

    func testMirrorChangesAtEdgeOnAndNeverCollapsesTheFaceToScaleZero() {
        let pose = OpeningStackPose(rawAngle: 20, angle: 20)
        let crossing = 20.0 / 110
        let before = pose.surfaces(progress: crossing - 0.000001, coverSide: 305, spineThickness: 16, portrait: true)
        let after = pose.surfaces(progress: crossing + 0.000001, coverSide: 305, spineThickness: 16, portrait: true)
        XCTAssertEqual(before.mirrorScaleX, -1)
        XCTAssertEqual(after.mirrorScaleX, 1)
        XCTAssertEqual(before.coverDegrees, 90, accuracy: 0.001)
        XCTAssertEqual(after.coverDegrees, 90, accuracy: 0.001)
        for step in 0...100 {
            let surfaces = pose.surfaces(progress: Double(step) / 100, coverSide: 305, spineThickness: 16, portrait: true)
            XCTAssertEqual(abs(surfaces.mirrorScaleX), 1)
        }
    }

    func testNeighborsRetireInOppositeDirectionsWithoutMovingSelectedIdentity() {
        let geometry = OpeningStackGeometry(size: CGSize(width: 375, height: 812))
        let above = geometry.retirement(index: 0, selectedIndex: 1, midpoint: 100)
        let selected = geometry.retirement(index: 1, selectedIndex: 1, midpoint: 406)
        let below = geometry.retirement(index: 2, selectedIndex: 1, midpoint: 712)
        XCTAssertEqual(above.offset, -(812 + 87))
        XCTAssertEqual(below.offset, 812 + 87)
        XCTAssertEqual(above.blur, 20)
        XCTAssertEqual(below.blur, 20)
        XCTAssertEqual(above.delay, 0.03)
        XCTAssertEqual(below.delay, 0.03)
        XCTAssertEqual(selected, OpeningStackRetirement(offset: 0, blur: 0, delay: 0))
        XCTAssertEqual(geometry.retirement(index: 0, selectedIndex: nil, midpoint: 100), selected)
    }
}
