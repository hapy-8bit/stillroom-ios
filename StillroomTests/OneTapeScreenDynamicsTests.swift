import XCTest
@testable import Stillroom

final class OneTapeScreenDynamicsTests: XCTestCase {
    func testUnsupportedAudioCannotAdvanceOrDrawFakeSound() {
        var dynamics = OneTapeScreenDynamics()
        let frame = dynamics.consume(rms: 0.8, peak: 1, bands: [1], waveform: [1, -1],
                                     active: false, elapsed: 0.05)
        XCTAssertEqual(frame, .silent)
    }

    func testSilentPCMRemainsStationaryAndWaveformUsesMeasuredSamples() {
        var dynamics = OneTapeScreenDynamics()
        let silent = dynamics.consume(rms: 0, peak: 0, bands: [], waveform: [],
                                      active: true, elapsed: 0.05)
        XCTAssertEqual(silent.motionTime, 0)
        let frame = dynamics.consume(rms: 0.25, peak: 0.8, bands: [0.4],
                                     waveform: [0.7, -0.3, .nan], active: true, elapsed: 0.05)
        XCTAssertEqual(frame.waveform[0], 0.7, accuracy: 0.000_001)
        XCTAssertEqual(frame.waveform[1], -0.3, accuracy: 0.000_001)
        XCTAssertEqual(frame.waveform[2], 0)
        XCTAssertGreaterThan(frame.motionTime, 0)
    }

    func testAllTwentyFourBandsContributeToSixteenDisplayColumns() {
        let source = (0..<24).map { Float($0 % 3 == 1 ? 1 : 0) }
        let columns = OneTapeScreenDynamics.resample(source, count: 16)
        XCTAssertEqual(columns.count, 16)
        XCTAssertTrue(columns.allSatisfy { abs($0 - 1.0 / 3) < 0.000_001 })
    }

    func testMeterPeaksHoldThenDecayAndPauseClearsThem() {
        var dynamics = OneTapeScreenDynamics()
        _ = dynamics.consume(rms: 0.2, peak: 1, bands: [1], waveform: [],
                             active: true, elapsed: 0.05)
        var frame = dynamics.consume(rms: 0, peak: 0, bands: [0], waveform: [],
                                     active: true, elapsed: 0.1)
        XCTAssertEqual(frame.heldPeaks.first, 1)
        for _ in 0..<10 {
            frame = dynamics.consume(rms: 0, peak: 0, bands: [0], waveform: [],
                                     active: true, elapsed: 0.1)
        }
        XCTAssertLessThan(frame.heldPeaks[0], 1)
        frame = dynamics.consume(rms: 0, peak: 0, bands: [], waveform: [],
                                 active: false, elapsed: 0.1)
        XCTAssertTrue(frame.heldPeaks.allSatisfy { $0 == 0 })
        XCTAssertTrue(frame.waveform.allSatisfy { $0 == 0 })
    }
}
