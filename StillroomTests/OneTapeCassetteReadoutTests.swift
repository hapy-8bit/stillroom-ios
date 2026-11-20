import XCTest
@testable import Stillroom

final class OneTapeCassetteReadoutTests: XCTestCase {
    func testCompleteLocalAndRemoteQueueUsesTheWholeDuration() {
        let times: [Double] = [204,216,220,195,238,211,207,224,219,203,242,229]
        var songs = times.enumerated().map { song("\($0.offset)", $0.element) }
        songs[4].remote = RemoteTrackReference(connectionID: "test", songID: "4", albumID: nil, coverArtID: nil)
        let result = OneTapeCassetteReadout(queueIDs: songs.map(\.id), tracks: songs)
        XCTAssertEqual(result.trackCount, 12)
        XCTAssertEqual(result.durationSeconds, 2608)
        XCTAssertEqual(result.durationLabel, "43:28")
    }

    func testLongQueueIncludesHoursRatherThanInventingACassetteCapacity() {
        let songs = [song("long", 7425.8)]
        let result = OneTapeCassetteReadout(queueIDs: ["long"], tracks: songs)
        XCTAssertEqual(result.durationLabel, "2:03:45")
        XCTAssertEqual(result.trackCount, 1)
    }

    func testMissingUnknownAndInvalidDurationsNeverBecomePartialTotals() {
        for value in [0, -1, Double.nan, .infinity] {
            let result = OneTapeCassetteReadout(queueIDs: ["known", "unknown"],
                tracks: [song("known", 120), song("unknown", value)])
            XCTAssertNil(result.durationSeconds)
            XCTAssertEqual(result.durationLabel, "--:--")
            XCTAssertEqual(result.trackCount, 2)
        }
        let missing = OneTapeCassetteReadout(queueIDs: ["known", "absent"], tracks: [song("known", 120)])
        XCTAssertNil(missing.durationSeconds)
        XCTAssertTrue(missing.accessibilitySummary.contains("未知"))
    }

    func testOverflowIsUnknownAndEmptyQueueIsExplicit() {
        let result = OneTapeCassetteReadout(queueIDs: ["huge", "huge"],
            tracks: [song("huge", .greatestFiniteMagnitude)])
        XCTAssertNil(result.durationSeconds)
        XCTAssertNil(OneTapeCassetteReadout(queueIDs: ["huge"],
            tracks: [song("huge", .greatestFiniteMagnitude)]).durationSeconds)
        XCTAssertEqual(OneTapeCassetteReadout.empty.durationLabel, "--:--")
        XCTAssertEqual(OneTapeCassetteReadout.empty.trackCount, 0)
        XCTAssertEqual(OneTapeCassetteReadout.empty.accessibilitySummary, "空白磁带")
    }

    func testRepeatedPlaylistEntriesRemainPartOfTheTotal() {
        let result = OneTapeCassetteReadout(queueIDs: ["a", "b", "a"],
            tracks: [song("a", 120), song("b", 180), song("unselected", 999)])
        XCTAssertEqual(result.durationLabel, "7:00")
        XCTAssertEqual(result.trackCount, 3)
    }

    private func song(_ id: String, _ duration: Double) -> Track {
        Track(id: id, title: id, artist: "Test", album: "Queue", audioFile: "\(id).wav",
              palette: .local, duration: duration, lyrics: "", isDemo: false, isLyricDemo: false)
    }
}
