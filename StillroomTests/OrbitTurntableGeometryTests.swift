import XCTest
@testable import Stillroom

final class OrbitTurntableGeometryTests: XCTestCase {
    func testPortraitRatiosUseFullCanvasAndConvertToSafeAreaSpaceOnce() {
        let value = OrbitTurntableGeometry(size: CGSize(width: 402, height: 778), safeTop: 62, safeBottom: 34)
        XCTAssertEqual(value.record.width, 402 * 1.211, accuracy: 0.001)
        XCTAssertEqual(value.record.midX, 402 * 0.265, accuracy: 0.001)
        XCTAssertEqual(value.record.midY + 62, 874 * 0.352, accuracy: 0.001)
        XCTAssertLessThan(value.record.minX, 0)
        XCTAssertGreaterThan(value.record.maxX, 402 * 0.85)
        XCTAssertEqual(value.armPivot.y + 62, 874 * 0.136, accuracy: 0.001)
    }

    func testShortPortraitRimLeavesRoomForLowerMetadata() {
        for width in [320.0, 375, 402, 440] {
            for fullHeight in [568.0, 667, 760, 874, 956] where width / fullHeight <= 0.72 {
                let value = OrbitTurntableGeometry(size: CGSize(width: width, height: fullHeight - 96), safeTop: 62, safeBottom: 34)
                XCTAssertLessThan(value.record.minX, 0)
                XCTAssertGreaterThan(value.record.midX, 0)
                XCTAssertLessThanOrEqual(value.record.maxY + 62, fullHeight * 0.681)
                XCTAssertLessThan(value.record.maxY + 62 + 20, fullHeight * 0.74)
                let scale = value.arm.width / 120
                XCTAssertLessThanOrEqual(value.armPivot.x + 47 * scale, width - min(8, width * 0.02) + 0.001)
            }
        }
    }

    func testWideAndSplitWindowsBoundTheStageByAvailableHeight() {
        for size in [CGSize(width: 874, height: 340), CGSize(width: 744, height: 500), CGSize(width: 1_024, height: 640)] {
            let value = OrbitTurntableGeometry(size: size, safeTop: 24, safeBottom: 20)
            let fullHeight = size.height + 44
            XCTAssertLessThanOrEqual(value.record.width, fullHeight * 0.64 + 0.001)
            XCTAssertGreaterThan(value.record.minX, 0)
            XCTAssertLessThan(value.record.maxY + 24, fullHeight * 0.74)
            XCTAssertGreaterThan(value.armPivot.x, value.record.midX)
            XCTAssertLessThan(value.arm.maxX, size.width)
        }
    }

    func testInvalidSizesCannotProduceNaNOrInfiniteDrawingFrames() {
        for size in [CGSize.zero, CGSize(width: CGFloat.nan, height: CGFloat.infinity), CGSize(width: -20, height: -50)] {
            let value = OrbitTurntableGeometry(size: size, safeTop: .nan, safeBottom: .infinity)
            for number in [value.record.width, value.record.height, value.record.midX, value.record.midY,
                           value.arm.width, value.arm.height, value.armPivot.x, value.armPivot.y] {
                XCTAssertTrue(number.isFinite)
            }
            XCTAssertGreaterThan(value.record.width, 0)
            XCTAssertGreaterThan(value.arm.width, 0)
        }
    }
}
