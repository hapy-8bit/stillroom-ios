import XCTest
@testable import Stillroom

final class OneTapeTapeGeometryTests: XCTestCase {
    func testTransferredTapePreservesCombinedSquaredPackRadius() {
        let start = OneTapeTapeGeometry.radii(progress: 0)
        let end = OneTapeTapeGeometry.radii(progress: 1)
        XCTAssertEqual(start.supply, 108.138, accuracy: 0.0001)
        XCTAssertEqual(start.takeup, 58.712, accuracy: 0.0001)
        XCTAssertEqual(end.supply, start.takeup, accuracy: 0.0001)
        XCTAssertEqual(end.takeup, start.supply, accuracy: 0.0001)
        let middle = OneTapeTapeGeometry.radii(progress: 0.5)
        XCTAssertEqual(middle.supply * middle.supply + middle.takeup * middle.takeup,
                       start.supply * start.supply + start.takeup * start.takeup, accuracy: 0.0001)
    }

    func testQueueProgressIncludesEarlierTracksAndClampsCurrentMediaTime() {
        var first = Track.demos[0]
        var second = Track.demos[1]
        first.duration = 30
        second.duration = 90
        let ids = [first.id, second.id]
        XCTAssertEqual(OneTapeTapeGeometry.progress(queueIDs: ids, tracks: [first, second],
            currentID: second.id, position: 30), 0.5, accuracy: 0.0001)
        XCTAssertEqual(OneTapeTapeGeometry.progress(queueIDs: ids, tracks: [first, second],
            currentID: second.id, position: 999), 1)
        XCTAssertEqual(OneTapeTapeGeometry.progress(queueIDs: ids, tracks: [first, second],
            currentID: nil, position: 30), 0)
    }

    func testNonfiniteInputKeepsFiniteVisualGeometry() {
        let radii = OneTapeTapeGeometry.radii(progress: .nan)
        XCTAssertTrue(radii.supply.isFinite)
        XCTAssertTrue(radii.takeup.isFinite)
        XCTAssertEqual(OneTapeTapeGeometry.progress(queueIDs: [], tracks: [],
            currentID: "missing", position: .infinity), 0)
    }
}
