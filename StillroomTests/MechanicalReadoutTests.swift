import XCTest
@testable import Stillroom

final class MechanicalReadoutTests: XCTestCase {
    func testCountersUseOneClampedPositionAndRemainingTime() {
        let readout = MechanicalPlaybackReadout(position: 65.4, duration: 180, ordinal: 2, total: 12)
        XCTAssertEqual(readout.elapsedLabel, "1:05")
        XCTAssertEqual(readout.remainingLabel, "1:54")
        XCTAssertEqual(readout.trackLabel, "02 / 12")
        XCTAssertEqual(readout.elapsed + readout.remaining, 180, accuracy: 0.0001)
        let ended = MechanicalPlaybackReadout(position: 200, duration: 180, ordinal: 99, total: 12)
        XCTAssertEqual(ended.elapsed, 180)
        XCTAssertEqual(ended.remaining, 0)
        XCTAssertEqual(ended.ordinal, 12)
    }

    func testInvalidMediaAndEmptyLibraryNeverProduceNaNOrInventAnOrdinal() {
        for value in [Double.nan, .infinity, -.infinity] {
            let readout = MechanicalPlaybackReadout(position: value, duration: value, ordinal: 1, total: 0)
            XCTAssertEqual(readout.elapsedLabel, "0:00")
            XCTAssertEqual(readout.remainingLabel, "0:00")
            XCTAssertEqual(readout.trackLabel, "00 / 00")
        }
        let negative = MechanicalPlaybackReadout(position: -12, duration: 56, ordinal: -1, total: 3)
        XCTAssertEqual(negative.elapsed, 0)
        XCTAssertEqual(negative.remaining, 56)
        XCTAssertEqual(negative.ordinal, 1)
    }
}
