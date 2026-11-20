import XCTest
@testable import Stillroom

final class OpeningGravityProjectionTests: XCTestCase {
    func testFirstSampleIsAnOrientationBaseline() {
        var projection = OpeningGravityProjection()
        XCTAssertNil(projection.ingest(rawY: -1))
        XCTAssertEqual(projection.value, 0)
        XCTAssertEqual(projection.ingest(rawY: -0.5), 0.5)
    }

    func testDeltaFoldsAtBothGravityExtremes() {
        var positive = OpeningGravityProjection()
        _ = positive.ingest(rawY: -1)
        XCTAssertEqual(positive.ingest(rawY: 0.5), 0.5)
        var negative = OpeningGravityProjection()
        _ = negative.ingest(rawY: 1)
        XCTAssertEqual(negative.ingest(rawY: -0.5), -0.5)
    }

    func testDeadbandUsesLastPublishedValue() {
        var projection = OpeningGravityProjection()
        _ = projection.ingest(rawY: 0)
        XCTAssertNil(projection.ingest(rawY: 0.01))
        XCTAssertNil(projection.ingest(rawY: 0.015))
        XCTAssertEqual(projection.ingest(rawY: 0.02), 0.02)
        XCTAssertNil(projection.ingest(rawY: 0.03))
        XCTAssertEqual(projection.ingest(rawY: 0.04), 0.04)
    }

    func testRestartRebaselinesAndRejectsInvalidSamples() {
        var projection = OpeningGravityProjection()
        XCTAssertNil(projection.ingest(rawY: .nan))
        _ = projection.ingest(rawY: 0)
        _ = projection.ingest(rawY: 0.5)
        projection.beginRun()
        XCTAssertNil(projection.ingest(rawY: .infinity))
        XCTAssertEqual(projection.value, 0.5)
        XCTAssertEqual(projection.ingest(rawY: -1), 0)
        XCTAssertEqual(projection.ingest(rawY: -0.75), 0.25)
    }
}
