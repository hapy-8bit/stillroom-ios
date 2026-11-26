import XCTest
@testable import Stillroom

final class ListeningLedgerTests: XCTestCase {
    private func sampleTrack(id: String = "t1", title: String = "Night Drive",
                             artist: String = "Echo", album: String = "Tape One",
                             duration: Double = 240, remote: Bool = false) -> Track {
        var track = Track(
            id: id, title: title, artist: artist, album: album,
            audioFile: remote ? "" : "\(id).m4a", artworkFile: nil,
            palette: .local, duration: duration, lyrics: "",
            isDemo: false, isLyricDemo: false
        )
        if remote {
            track.remote = RemoteTrackReference(connectionID: "c1", songID: id, albumID: "a1", coverArtID: nil)
        }
        return track
    }

    func testTrackerAccumulatesContinuousPlaybackAndIgnoresSeeks() {
        var tracker = ListeningSessionTracker()
        let track = sampleTrack(duration: 200)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        // Start playback at position 0.
        XCTAssertTrue(tracker.observe(track: track, position: 0, duration: 200,
                                      isPlaying: true, isWinding: false, at: start).isEmpty)

        // Advance continuously by 1s steps for 12s -> triggers checkpoint after 10s (>= 5s).
        var persisted: [ListeningSessionEvent] = []
        for step in 1...12 {
            let now = start.addingTimeInterval(Double(step))
            persisted += tracker.observe(track: track, position: Double(step), duration: 200,
                                         isPlaying: true, isWinding: false, at: now)
        }
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted[0].listenedSeconds, 10.0, accuracy: 0.2)

        // User seeks forward to 150s -> should NOT credit the 138s jump!
        tracker.noteSeek()
        _ = tracker.observe(track: track, position: 150, duration: 200,
                            isPlaying: true, isWinding: false, at: start.addingTimeInterval(13))
        XCTAssertEqual(tracker.activeEvent?.listenedSeconds ?? 0, 12.0, accuracy: 0.2)

        // Pause and resume on the SAME track preserves the same session UUID (no duplicate plays).
        let sessionID = tracker.activeEvent?.id
        let flushedOnPause = tracker.flushPreservingSession()
        XCTAssertEqual(flushedOnPause?.id, sessionID)

        _ = tracker.observe(track: track, position: 150, duration: 200,
                            isPlaying: true, isWinding: false, at: start.addingTimeInterval(25))
        _ = tracker.observe(track: track, position: 151, duration: 200,
                            isPlaying: true, isWinding: false, at: start.addingTimeInterval(26))
        XCTAssertEqual(tracker.activeEvent?.id, sessionID)
        XCTAssertEqual(tracker.activeEvent?.listenedSeconds ?? 0, 13.0, accuracy: 0.2)

        // Completing the track seals the session so a replay creates a brand-new UUID.
        let finished = tracker.markTrackFinished(at: start.addingTimeInterval(27))
        XCTAssertEqual(finished?.id, sessionID)
        XCTAssertEqual(finished?.reachedEnd, true)
        XCTAssertEqual(finished?.isCompleted, true)
        XCTAssertNil(tracker.activeEvent)
    }

    @MainActor
    func testLedgerStoreRoundTripsAndPreservesCorruptedFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ListeningLedgerTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("listening-ledger.json")
        let store = ListeningLedgerStore(fileURL: fileURL)
        let now = Date(timeIntervalSince1970: 1_700_100_000)
        let event = ListeningSessionEvent(
            id: UUID(), trackID: "t1", title: "Night Drive", artist: "Echo",
            album: "Tape One", albumKey: "Tape One\u{001F}Echo",
            trackDuration: 180, startedAt: now, lastUpdatedAt: now.addingTimeInterval(90),
            listenedSeconds: 90, reachedEnd: false, source: .navidrome
        )
        try store.upsert(event)

        let reloaded = ListeningLedgerStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.ledger.events.count, 1)
        XCTAssertEqual(reloaded.ledger.events[0].id, event.id)
        XCTAssertEqual(reloaded.ledger.events[0].listenedSeconds, 90, accuracy: 0.01)

        // Corrupt the ledger file and verify it is NOT overwritten on subsequent writes.
        let corruptBytes = Data("{ invalid-json".utf8)
        try corruptBytes.write(to: fileURL, options: .atomic)
        let damagedStore = ListeningLedgerStore(fileURL: fileURL)
        XCTAssertThrowsError(try damagedStore.upsert(event)) { error in
            XCTAssertEqual(error as? ListeningLedgerError, .corruptedArchive)
        }
        XCTAssertEqual(try Data(contentsOf: fileURL), corruptBytes)
    }

    func testInsightsSnapshotComputesCassettePhysicsRhythmRankingsAndArchive() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 23, minute: 0))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let oldDate = calendar.date(byAdding: .day, value: -40, to: now)!

        var ledger = ListeningLedger()
        // 3600s = 1.0 C60 cassette = 171.45 meters across two events today & yesterday.
        let e1 = ListeningSessionEvent(
            id: UUID(), trackID: "t1", title: "Sad Robot", artist: "Pornophonique",
            album: "8-Bit Lagerfeuer", albumKey: "8-Bit Lagerfeuer\u{001F}Pornophonique",
            trackDuration: 2000, startedAt: now.addingTimeInterval(-1800), lastUpdatedAt: now,
            listenedSeconds: 1800, reachedEnd: true, source: .navidrome
        )
        let e2 = ListeningSessionEvent(
            id: UUID(), trackID: "t2", title: "Space Invaders", artist: "Pornophonique",
            album: "8-Bit Lagerfeuer", albumKey: "8-Bit Lagerfeuer\u{001F}Pornophonique",
            trackDuration: 3000, startedAt: yesterday, lastUpdatedAt: yesterday.addingTimeInterval(1800),
            listenedSeconds: 1800, reachedEnd: false, source: .local
        )
        let eOld = ListeningSessionEvent(
            id: UUID(), trackID: "t3", title: "Ancient Echo", artist: "Old Band",
            album: "Classic 90s", albumKey: "Classic 90s\u{001F}Old Band",
            trackDuration: 300, startedAt: oldDate, lastUpdatedAt: oldDate.addingTimeInterval(300),
            listenedSeconds: 300, reachedEnd: true, source: .local
        )
        ledger.upsert(e1)
        ledger.upsert(e2)
        ledger.upsert(eOld)

        let tracks = [
            sampleTrack(id: "t1", title: "Sad Robot", artist: "Pornophonique", album: "8-Bit Lagerfeuer", duration: 2000, remote: true),
            sampleTrack(id: "t2", title: "Space Invaders", artist: "Pornophonique", album: "8-Bit Lagerfeuer", duration: 3000, remote: false),
            sampleTrack(id: "t3", title: "Ancient Echo", artist: "Old Band", album: "Classic 90s", duration: 300, remote: false)
        ]
        let albums = [
            MusicCollection(id: "a1", kind: .album, title: "8-Bit Lagerfeuer", subtitle: "Pornophonique",
                            remoteID: "r1", trackIDs: ["t1", "t2"], coverArtID: nil, year: 2007, duration: 5000, addedAt: nil),
            MusicCollection(id: "a2", kind: .album, title: "Classic 90s", subtitle: "Old Band",
                            remoteID: "", trackIDs: ["t3"], coverArtID: nil, year: 1994, duration: 300, addedAt: nil)
        ]

        let week = ListeningInsightsSnapshot.build(
            ledger: ledger, liveEvent: nil, range: .week,
            tracks: tracks, albums: albums, favorites: ["t1"],
            now: now, calendar: calendar
        )
        XCTAssertEqual(week.totalSeconds, 3600, accuracy: 0.01)
        XCTAssertEqual(week.c60TapeCount, 1.0, accuracy: 0.001)
        XCTAssertEqual(week.tapeMeters, 171.45, accuracy: 0.01)
        XCTAssertEqual(week.countedPlays, 2)
        XCTAssertEqual(week.completedPlays, 1)
        XCTAssertEqual(week.completionRate ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(week.activeDays, 2)
        XCTAssertEqual(week.currentStreakDays, 2)
        XCTAssertEqual(week.topAlbums.first?.title, "8-Bit Lagerfeuer")
        XCTAssertEqual(week.library.localTrackCount, 2)
        XCTAssertEqual(week.library.navidromeTrackCount, 1)
        XCTAssertEqual(week.library.favoriteCount, 1)
        XCTAssertEqual(week.library.decades.map(\.label), ["90s", "00s"])

        let all = ListeningInsightsSnapshot.build(
            ledger: ledger, liveEvent: nil, range: .all,
            tracks: tracks, albums: albums, favorites: ["t1"],
            now: now, calendar: calendar
        )
        XCTAssertEqual(all.totalSeconds, 3900, accuracy: 0.01)
        XCTAssertEqual(all.countedPlays, 3)
        XCTAssertEqual(all.topArtists.count, 2)
    }
}
