import XCTest
@testable import Stillroom

final class OneTapePlaybackReadoutTests: XCTestCase {
    func testReadoutProjectsSecondsAndZeroBasedQueueIndex() {
        let readout = OneTapePlaybackReadout(
            title: "太聪明", artist: "陈绮贞", positionSeconds: 65.9,
            durationSeconds: 185, isPlaying: true, isPreparing: false,
            trackIndex: 2, trackCount: 12
        )
        XCTAssertEqual(readout.positionLabel, "1:05")
        XCTAssertEqual(readout.remainingLabel, "-1:59")
        XCTAssertEqual(readout.trackLabel, "03/12")
        XCTAssertEqual(readout.fraction, 65.9 / 185, accuracy: 0.000_001)
    }

    func testTransientInvalidTimesCannotProduceInvalidProgress() {
        let readout = OneTapePlaybackReadout(
            title: "Loading", artist: "", positionSeconds: .infinity,
            durationSeconds: .nan, isPlaying: false, isPreparing: true,
            trackIndex: -3, trackCount: 1
        )
        XCTAssertEqual(readout.positionLabel, "0:00")
        XCTAssertEqual(readout.fraction, 0)
        XCTAssertEqual(readout.trackLabel, "01/01")
    }

    func testEndOfTrackAndEmptyQueueHaveBoundedDisplayValues() {
        let readout = OneTapePlaybackReadout(
            title: "End", artist: "", positionSeconds: 205,
            durationSeconds: 200, isPlaying: false, isPreparing: false,
            trackIndex: 9, trackCount: 2
        )
        XCTAssertEqual(readout.fraction, 1)
        XCTAssertEqual(readout.remainingLabel, "-0:00")
        XCTAssertEqual(readout.trackLabel, "02/02")
        XCTAssertFalse(OneTapePlaybackReadout.empty.hasTrack)
        XCTAssertEqual(OneTapePlaybackReadout.empty.trackLabel, "01/01")
    }

    func testScreenCountersTickTogetherAndClampAtTheTrackEnd() {
        let cases: [(Double, String, String)] = [
            (0, "0:00", "-4:01"),
            (4, "0:04", "-3:57"),
            (4.9, "0:04", "-3:57"),
            (5, "0:05", "-3:56"),
            (240.9, "4:00", "-0:01"),
            (241, "4:01", "-0:00"),
            (900, "4:01", "-0:00")
        ]
        for (position, elapsed, remaining) in cases {
            let value = screenReadout(position: position, duration: 241)
            XCTAssertEqual(value.screenElapsedLabel, elapsed, "position=\(position)")
            XCTAssertEqual(value.screenRemainingLabel, remaining, "position=\(position)")
            XCTAssertEqual(value.screenTimeLabel, elapsed + " " + remaining)
        }
        let fractionalDuration = screenReadout(position: 4.9, duration: 241.9)
        XCTAssertEqual(fractionalDuration.screenTimeLabel, "0:04 -3:57")
        XCTAssertEqual(fractionalDuration.positionSeconds, 4.9)
        XCTAssertEqual(fractionalDuration.durationSeconds, 241.9,
            "Display quantization must not modify authoritative media seconds")
    }

    func testScreenUnknownDurationIsDistinctFromACompletedTrack() {
        for duration in [0.0, -12.0, .nan, .infinity] {
            let value = screenReadout(position: 7.9, duration: duration)
            XCTAssertEqual(value.screenElapsedLabel, "0:07")
            XCTAssertEqual(value.screenRemainingLabel, "--:--")
            XCTAssertEqual(value.screenTimeLabel, "0:07 --:--")
        }
        XCTAssertEqual(OneTapePlaybackReadout.empty.screenTrackLabel, "曲 --/--")
        XCTAssertEqual(OneTapePlaybackReadout.empty.screenTimeLabel, "--:-- --:--")
        XCTAssertEqual(screenReadout(position: 241, duration: 241).screenRemainingLabel, "-0:00")
    }

    func testScreenSideSplitsQueueByTrackCountWithoutUsingMediaDurationOrPlaybackState() {
        let cases: [(Int, [String])] = [
            (1, ["面 A"]),
            (2, ["面 A", "面 B"]),
            (3, ["面 A", "面 B", "面 B"]),
            (4, ["面 A", "面 A", "面 B", "面 B"]),
            (5, ["面 A", "面 A", "面 B", "面 B", "面 B"])
        ]
        for (count, expected) in cases {
            for (index, side) in expected.enumerated() {
                let value = screenReadout(position: 4.9, duration: 241, index: index, count: count)
                XCTAssertEqual(value.screenSideLabel, side, "queue=\(index)/\(count)")
                let loading = OneTapePlaybackReadout(title: "Actual Track", artist: "Actual Artist",
                    positionSeconds: 99, durationSeconds: 0, isPlaying: true, isPreparing: true,
                    trackIndex: index, trackCount: count)
                XCTAssertEqual(loading.screenSideLabel, side)
                XCTAssertEqual(loading.screenState, .loading)
                XCTAssertEqual(loading.screenArtist, "Actual Artist")
            }
        }
        let last = screenReadout(position: 4, duration: 241, index: 4, count: 5)
        XCTAssertEqual(last.screenTrackLabel, "曲 05/05")
        XCTAssertEqual(last.screenSideLabel, "面 B")
        XCTAssertEqual(OneTapePlaybackReadout.empty.screenSideLabel, "面 A")
        let clamped = screenReadout(position: 4, duration: 241, index: 99, count: 5)
        XCTAssertEqual(clamped.screenTrackLabel, "曲 05/05")
        XCTAssertEqual(clamped.screenSideLabel, "面 B")
    }

    private func screenReadout(position: Double, duration: Double,
                               index: Int = 0, count: Int = 1) -> OneTapePlaybackReadout {
        OneTapePlaybackReadout(title: "Actual Track", artist: "Actual Artist",
            positionSeconds: position, durationSeconds: duration, isPlaying: false,
            isPreparing: false, trackIndex: index, trackCount: count)
    }
}
