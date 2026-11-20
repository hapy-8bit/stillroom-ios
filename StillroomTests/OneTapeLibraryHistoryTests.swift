import XCTest
@testable import Stillroom

@MainActor
final class OneTapeLibraryHistoryTests: XCTestCase {
    func testSongHistoryPersistsMRUWithoutDiscardingUnloadedRemoteIdentities() throws {
        let suite = "OneTape.history." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = PlaybackHistoryStore(defaults: defaults)
        XCTAssertEqual(try history.record("local-song"), ["local-song"])
        XCTAssertEqual(try history.record("navidrome:test:song:remote"),
                       ["navidrome:test:song:remote", "local-song"])
        XCTAssertEqual(try history.record("local-song"),
                       ["local-song", "navidrome:test:song:remote"])
        let before = defaults.data(forKey: "onetape.playback-history.v1")
        _ = try history.record("local-song")
        XCTAssertEqual(defaults.data(forKey: "onetape.playback-history.v1"), before)
        XCTAssertEqual(PlaybackHistoryStore(defaults: defaults).trackIDs,
                       ["local-song", "navidrome:test:song:remote"])
    }

    func testCorruptSongHistoryIsNotOverwrittenByANewPlay() throws {
        let suite = "OneTape.history-corrupt." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = Data("unreadable history".utf8)
        defaults.set(original, forKey: "onetape.playback-history.v1")
        let history = PlaybackHistoryStore(defaults: defaults)
        XCTAssertThrowsError(try history.record("new-song"))
        XCTAssertEqual(defaults.data(forKey: "onetape.playback-history.v1"), original)
    }

    func testOnlyActualPlaybackRecordsSelectionAndAutomaticNextSurvivesColdStart() async throws {
        let suite = "OneTape.history-engine." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let songs = Array(Track.demos.prefix(2))
        let player = PlayerStore(directory: folder, defaults: defaults, sampleTracks: songs)
        defer {
            player.pause()
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }
        await player.restore()
        player.choose(songs[0], in: songs, autoplay: false)
        XCTAssertTrue(player.recentlyPlayedTrackIDs.isEmpty, "Opening/selecting a song does not play it")
        player.play()
        try await waitForHistory(player, first: songs[0].id)
        player.skip(1, automatic: true)
        try await waitForHistory(player, first: songs[1].id)
        player.pause()
        XCTAssertEqual(player.recentlyPlayedTrackIDs, [songs[1].id, songs[0].id])
        let remote = Track(id: "navidrome:test:song:unplayable", title: "Unavailable", artist: "Artist",
            album: "Album", audioFile: "", palette: .local, duration: 30, lyrics: "", isDemo: false,
            isLyricDemo: false, remote: RemoteTrackReference(connectionID: "test", songID: "unplayable",
                                                          albumID: "album", coverArtID: nil))
        player.setRemoteTracks([remote], streamURL: nil)
        player.choose(remote, in: [remote])
        XCTAssertEqual(player.recentlyPlayedTrackIDs, [songs[1].id, songs[0].id],
                       "Failed/preparing playback must not become listening history")
        let reopened = PlayerStore(directory: folder, defaults: defaults, sampleTracks: songs)
        await reopened.restore()
        XCTAssertEqual(reopened.recentlyPlayedTrackIDs, [songs[1].id, songs[0].id])
        XCTAssertFalse(reopened.isPlaying)
    }

    func testPreviewImportDatesPersistAndDuplicatesDoNotBecomeRecentlyAdded() async throws {
        let suite = "OneTape.import-dates." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }
        let player = PlayerStore(directory: folder, defaults: defaults, emptyLibrary: true)
        await player.restore()
        let source = try XCTUnwrap(Bundle.main.url(forResource: "sea.wav", withExtension: nil))
        let before = Date()
        await player.importCoordinator.prepare(urls: [source])
        XCTAssertTrue(player.tracks.isEmpty)
        await player.importCoordinator.confirm()
        let imported = try XCTUnwrap(player.libraryTracks.first)
        let addedAt = try XCTUnwrap(imported.addedAt)
        XCTAssertGreaterThanOrEqual(addedAt, before)
        XCTAssertLessThanOrEqual(addedAt, Date())
        await player.importCoordinator.prepare(urls: [source])
        await player.importCoordinator.confirm()
        XCTAssertEqual(player.libraryTracks.first?.addedAt, addedAt)
        let restored = try await LibraryRepository(directory: folder).restore()
        XCTAssertEqual(restored.first?.addedAt, addedAt)

        // An older index has no recoverable import timestamp. Reading it must
        // neither invent today's date nor replace the user's index bytes.
        let index = folder.appendingPathComponent("library.json")
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: index)) as? [[String: Any]])
        legacy[0].removeValue(forKey: "addedAt")
        let original = try JSONSerialization.data(withJSONObject: legacy)
        try original.write(to: index)
        let older = try await LibraryRepository(directory: folder).restore()
        XCTAssertNil(older.first?.addedAt)
        XCTAssertEqual(try Data(contentsOf: index), original)
    }

    private func waitForHistory(_ player: PlayerStore, first id: String) async throws {
        for _ in 0..<100 {
            if player.isPlaying, player.recentlyPlayedTrackIDs.first == id { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("The shared engine did not start and record the expected song")
    }
}
