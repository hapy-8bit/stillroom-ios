import XCTest
@testable import Stillroom

final class OrbitRecordDragTests: XCTestCase {
    func testPredictionAndStrictBoundarySelectDirection() {
        for (prediction, expected) in [(-101.0, 1), (101.0, -1), (-100.0, 0), (100.0, 0)] {
            var value = OrbitRecordDrag()
            value.update(owner: "a", x: -20, y: 2)
            XCTAssertEqual(value.finish(owner: "a", predictedX: prediction, active: true,
                                        canSkipNext: true, canSkipPrevious: true), expected == 0 ? nil : expected)
        }
    }

    func testVerticalOwnershipAndQueueAvailabilityDoNotCommit() {
        var vertical = OrbitRecordDrag()
        vertical.update(owner: "a", x: 10, y: 10)
        vertical.update(owner: "a", x: 200, y: 20)
        XCTAssertNil(vertical.finish(owner: "a", predictedX: 300, active: true,
                                     canSkipNext: true, canSkipPrevious: true))
        var unavailable = OrbitRecordDrag()
        unavailable.update(owner: "a", x: -120, y: 1)
        XCTAssertNil(unavailable.finish(owner: "a", predictedX: -300, active: true,
                                        canSkipNext: false, canSkipPrevious: true))
    }

    func testChangingSongOrVisibilityCancelsHeldFingerUntilRelease() {
        var value = OrbitRecordDrag()
        value.update(owner: "a", x: -50, y: 1)
        value.update(owner: "b", x: -150, y: 1)
        XCTAssertNil(value.finish(owner: "b", predictedX: -300, active: true,
                                  canSkipNext: true, canSkipPrevious: true))
        value.update(owner: "b", x: -50, y: 1)
        XCTAssertNil(value.finish(owner: "b", predictedX: -300, active: false,
                                  canSkipNext: true, canSkipPrevious: true))
        value.update(owner: "b", x: -50, y: 1)
        XCTAssertEqual(value.finish(owner: "b", predictedX: -300, active: true,
                                    canSkipNext: true, canSkipPrevious: true), 1)
    }
}
