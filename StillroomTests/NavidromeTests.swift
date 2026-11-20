import XCTest
@testable import Stillroom

final class NavidromeTests: XCTestCase {
    private func connection() -> NavidromeConnection {
        NavidromeConnection(id: "test", baseURL: URL(string: "https://music.example.test/subpath")!,
                            username: "test user+中文", credentialID: "test-key")
    }

    func testRequestUsesEncodedTokenAuthenticationAndReverseProxyPath() throws {
        let client = NavidromeClient(connection: connection(), password: "password")
        let url = try client.url("getAlbum", parameters: ["id": "a+b&c"], salt: "salt")
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let fields = Dictionary(uniqueKeysWithValues: try XCTUnwrap(parts.queryItems).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(parts.path, "/subpath/rest/getAlbum.view")
        XCTAssertEqual(fields["u"], "test user+中文")
        XCTAssertEqual(fields["id"], "a+b&c")
        XCTAssertEqual(fields["t"], "b305cadbb3bce54f3aa59c64fec00dea")
        XCTAssertNil(fields["p"])
        XCTAssertEqual(fields["v"], "1.16.1")
        XCTAssertNotEqual(try client.streamURL(songID: "one"), try client.streamURL(songID: "one"))
        XCTAssertThrowsError(try client.url("../stream"))
    }

    func testAddressRejectsEmbeddedCredentialsQueryAndNonHTTPProtocols() throws {
        for text in ["file:///music", "https://user:password@example.test", "https://example.test/?p=secret", "https://example.test/#x", "music.example.test"] {
            XCTAssertThrowsError(try NavidromeClient.normalizedAddress(text))
        }
        XCTAssertEqual(try NavidromeClient.normalizedAddress(" https://example.test/subpath/// ").absoluteString,
                       "https://example.test/subpath")
    }

    func testOldTracksDecodeWithoutRemoteReference() throws {
        let data = try JSONEncoder().encode(Track.demos[0])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "remote")
        let decoded = try JSONDecoder().decode(Track.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.remote)
        XCTAssertEqual(decoded.id, "sea")
    }

    func testPagingHandlesServerPageLimitsAndPlaylistsShareTrackIdentities() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NavidromeTestProtocol.self]
        NavidromeTestProtocol.respond = { request in
            let parts = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let fields = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            let endpoint = parts.path.components(separatedBy: "/").last!
            let payload: [String: Any]
            switch endpoint {
            case "getAlbumList2.view":
                XCTAssertEqual(fields["type"], "newest")
                let ids = fields["offset"] == "0" ? ["a"] : fields["offset"] == "1" ? ["b"] : []
                payload = ["albumList2": ["album": ids.map { ["id": $0, "created": "2026-01-02T03:04:05Z"] }]]
            case "getAlbum.view":
                let id = fields["id"]!
                payload = ["album": ["id": id, "name": "Album " + id, "songCount": 1,
                    "song": [["id": id, "title": "Song " + id, "duration": 30]]]]
            case "getPlaylists.view":
                payload = ["playlists": ["playlist": [["id": "p", "created": "2026-02-03T04:05:06+08:00"]]]]
            case "getPlaylist.view":
                payload = ["playlist": ["id": "p", "name": "Selection", "songCount": 2,
                    "entry": [["id": "a", "title": "Song a"], ["id": "c", "title": "Song c"]]]]
            default: payload = [:]
            }
            return (200, try JSONSerialization.data(withJSONObject: ["subsonic-response": payload.merging(["status": "ok"]) { a, _ in a }]))
        }
        defer { NavidromeTestProtocol.respond = nil }
        let client = NavidromeClient(connection: connection(), password: "test", session: URLSession(configuration: configuration))
        let result = try await client.fetchCatalog()
        XCTAssertEqual(result.albums.map(\.remoteID), ["a", "b"])
        XCTAssertEqual(result.tracks.count, 3)
        XCTAssertEqual(result.playlists.first?.trackIDs, ["navidrome:test:song:a", "navidrome:test:song:c"])
        XCTAssertTrue(result.tracks.allSatisfy { $0.audioFile.isEmpty && $0.remote != nil })
        XCTAssertEqual(result.albums.first?.addedAt, SubsonicDate.parse("2026-01-02T03:04:05Z"))
        XCTAssertEqual(result.playlists.first?.addedAt, SubsonicDate.parse("2026-02-03T04:05:06+08:00"))
    }

    func testServerCreationDatesKeepFractionalSecondsAndNeverInventMissingValues() throws {
        let payload = Data(#"{"id":"album","created":"2023-03-10T02:19:35.784818075Z","song":[]}"#.utf8)
        let album = try JSONDecoder().decode(SubsonicAlbum.self, from: payload)
        let date = try XCTUnwrap(album.collection(connectionID: "test", songs: []).addedAt)
        XCTAssertEqual(date.timeIntervalSince1970, 1_678_414_775.784818, accuracy: 0.001)
        XCTAssertNil(SubsonicDate.parse(nil))
        XCTAssertNil(SubsonicDate.parse("not a date"))
        let missing = try JSONDecoder().decode(SubsonicAlbum.self, from: Data(#"{"id":"old"}"#.utf8))
        XCTAssertNil(missing.collection(connectionID: "test", songs: []).addedAt)
        let playlist = try JSONDecoder().decode(SubsonicPlaylist.self,
            from: Data(#"{"id":"p","created":"2026-01-01T00:00:00Z","changed":"2026-11-01T00:00:00Z"}"#.utf8))
        XCTAssertEqual(playlist.collection(connectionID: "test", songs: []).addedAt,
                       SubsonicDate.parse("2026-01-01T00:00:00Z"), "Editing a playlist is not adding it")
    }

    func testServerErrorNeverIncludesSignedRequestInMessage() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NavidromeTestProtocol.self]
        NavidromeTestProtocol.respond = { _ in
            (200, Data(#"{"subsonic-response":{"status":"failed","error":{"code":40,"message":"secret-token-url"}}}"#.utf8))
        }
        defer { NavidromeTestProtocol.respond = nil }
        let client = NavidromeClient(connection: connection(), password: "test", session: URLSession(configuration: configuration))
        do { try await client.ping(); XCTFail("Expected authentication failure") }
        catch {
            XCTAssertTrue(error is NavidromeError)
            XCTAssertFalse(error.localizedDescription.contains("secret-token-url"))
        }
    }

    func testCatalogRoundTripAndCorruptIndexBlocksOverwrite() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = NavidromeCatalogRepository(directory: folder)
        let track = remoteTrack()
        let album = MusicCollection(id: "album", kind: .album, title: "Album", subtitle: "Artist", remoteID: "album",
                                    trackIDs: [track.id], coverArtID: nil, year: nil, duration: 20)
        let catalog = NavidromeCatalog(connection: connection(), tracks: [track], albums: [album], playlists: [], updatedAt: Date(timeIntervalSince1970: 0))
        try await repository.save(catalog)
        let restored = try await repository.load()
        XCTAssertEqual(restored, catalog)
        try await repository.save(nil)
        let disconnected = try await repository.load()
        XCTAssertNil(disconnected)
        let file = folder.appendingPathComponent("catalog.json"), corrupt = Data("damaged".utf8)
        try corrupt.write(to: file)
        let unreadable = NavidromeCatalogRepository(directory: folder)
        do { try await unreadable.save(catalog); XCTFail("Corrupt index must not be overwritten") } catch {}
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }

    func testLocalRepositoryNeverPersistsCloudTracks() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LibraryRepository(directory: folder)
        try await repository.save([remoteTrack()])
        let restored = try await repository.restore()
        XCTAssertTrue(restored.isEmpty)
        let file = folder.appendingPathComponent("library.json")
        try JSONEncoder().encode([remoteTrack()]).write(to: file)
        do { _ = try await repository.restore(); XCTFail("Mixed cloud index must be retained as unreadable") } catch {}
        let bytes = try Data(contentsOf: file)
        do { try await repository.save([]); XCTFail("Do not overwrite corrupt index") } catch {}
        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }

    @MainActor
    func testEmptyPlayerDoesNotExposeDemoOrPrepareAudioAndCloudRemovalIsSafe() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "OneTape.empty." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: folder); defaults.removePersistentDomain(forName: suite) }
        let player = PlayerStore(directory: folder, defaults: defaults, emptyLibrary: true)
        await player.restore()
        XCTAssertTrue(player.tracks.isEmpty)
        XCTAssertNil(player.currentTrack)
        player.play(); player.seek(10); player.skip(1)
        XCTAssertEqual(player.snapshot, PlaybackSnapshot())
        let track = remoteTrack()
        player.setRemoteTracks([track], streamURL: { _ in URL(string: "https://music.example.test/stream")! })
        player.choose(track, in: [track], autoplay: false)
        XCTAssertEqual(player.currentTrack?.id, track.id)
        player.setRemoteTracks([], streamURL: nil)
        XCTAssertNil(player.currentTrack)
        XCTAssertTrue(player.queue.ids.isEmpty)
        XCTAssertFalse(player.isPlaying)
    }

    private func remoteTrack() -> Track {
        var track = Track(id: "navidrome:test:song:one", title: "Song", artist: "Artist", album: "Album",
                          audioFile: "", palette: .local, duration: 20, lyrics: "", isDemo: false, isLyricDemo: false)
        track.remote = RemoteTrackReference(connectionID: "test", songID: "one", albumID: "album", coverArtID: nil)
        return track
    }

    @MainActor
    func testLocalImportPreservesCloudSelectionAndCloudBookmarkRestoresPaused() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "OneTape.coexist." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: folder); defaults.removePersistentDomain(forName: suite) }
        let player = PlayerStore(directory: folder, defaults: defaults, emptyLibrary: true)
        await player.restore()
        let track = remoteTrack()
        player.setRemoteTracks([track], streamURL: nil)
        player.choose(track, in: [track], autoplay: false)
        let source = try XCTUnwrap(Bundle.main.url(forResource: "sea.wav", withExtension: nil))
        await player.importCoordinator.prepare(urls: [source])
        await player.importCoordinator.confirm()
        XCTAssertEqual(player.currentTrack?.id, track.id)
        XCTAssertEqual(player.queue.ids, [track.id])
        XCTAssertEqual(player.tracks.count, 2)
        let local = try await LibraryRepository(directory: folder).restore()
        XCTAssertEqual(local.count, 1)
        XCTAssertNil(local.first?.remote)
        try PlaybackBookmarkStore(defaults: defaults).save(PlaybackBookmark(trackID: track.id,
            queueIDs: [track.id], originalIDs: [track.id], shuffled: false, repeatMode: .off, position: 8.5))
        let reopened = PlayerStore(directory: folder, defaults: defaults, emptyLibrary: true)
        await reopened.restore()
        reopened.setRemoteTracks([track], streamURL: nil, restorePlayback: true)
        XCTAssertEqual(reopened.currentTrack?.id, track.id)
        XCTAssertEqual(reopened.position, 8.5)
        XCTAssertFalse(reopened.isPlaying)
        XCTAssertFalse(reopened.snapshot.isPreparing)
        reopened.setRemoteTracks([], streamURL: nil)
        XCTAssertNotNil(reopened.currentTrack)
        XCTAssertNil(reopened.currentTrack?.remote)
        XCTAssertEqual(reopened.tracks.count, 1)
    }

    @MainActor
    func testCorruptLocalIndexDoesNotPreventRemoteQueueAndPositionColdRestore() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let index = folder.appendingPathComponent("library.json")
        let corrupt = Data("original unreadable local index".utf8)
        try corrupt.write(to: index)
        let suite = "OneTape.remote-resume." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let player = PlayerStore(directory: folder, defaults: defaults, emptyLibrary: true)
        var reopened: PlayerStore?
        defer {
            player.pause(); reopened?.pause()
            try? FileManager.default.removeItem(at: folder)
            defaults.removePersistentDomain(forName: suite)
        }
        await player.restore()
        XCTAssertFalse(player.libraryReady, "Do not pretend the damaged local index is ready")
        let first = remoteTrack()
        let second = Track(id: "navidrome:test:song:two", title: "Second song", artist: "Artist", album: "Album",
            audioFile: "", palette: .local, duration: 56, lyrics: "", isDemo: false, isLyricDemo: false,
            remote: RemoteTrackReference(connectionID: "test", songID: "two", albumID: "album", coverArtID: nil))
        let outside = Track(id: "navidrome:test:song:outside", title: "Other album", artist: "Artist", album: "Outside",
            audioFile: "", palette: .local, duration: 56, lyrics: "", isDemo: false, isLyricDemo: false,
            remote: RemoteTrackReference(connectionID: "test", songID: "outside", albumID: "outside", coverArtID: nil))
        let catalog = [outside, first, second]
        let sample = try XCTUnwrap(Bundle.main.url(forResource: "sea.wav", withExtension: nil))
        // Resolve remote identities to a bundled file only inside this test, so
        // the real engine completes a seek without a network dependency.
        player.setRemoteTracks(catalog, streamURL: { _ in sample })
        player.choose(first, in: [first, second], autoplay: false)
        player.skip(1)
        XCTAssertEqual(player.currentTrack?.id, second.id)
        player.seek(8.5)
        var completed = false
        for _ in 0..<100 {
            if abs(player.position - 8.5) < 0.1 { completed = true; break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(completed, "Persist the engine's completed media seek")
        player.pause()
        let saved = try XCTUnwrap(PlaybackBookmarkStore(defaults: defaults).restore(available: Set(catalog.map(\.id))))
        XCTAssertEqual(saved.trackID, second.id)
        XCTAssertEqual(saved.queueIDs, [first.id, second.id])
        XCTAssertEqual(saved.position, 8.5, accuracy: 0.1)
        let restored = PlayerStore(directory: folder, defaults: defaults, emptyLibrary: true)
        reopened = restored
        await restored.restore()
        restored.setRemoteTracks(catalog, streamURL: nil, restorePlayback: true)
        XCTAssertFalse(restored.libraryReady)
        XCTAssertEqual(restored.currentTrack?.id, second.id)
        XCTAssertEqual(restored.queue.ids, [first.id, second.id])
        XCTAssertEqual(restored.queueTitle, saved.queueTitle)
        XCTAssertEqual(restored.position, 8.5, accuracy: 0.1)
        XCTAssertFalse(restored.snapshot.isPlaying)
        XCTAssertFalse(restored.snapshot.isPreparing)
        restored.pause()
        restored.pause()
        XCTAssertEqual(restored.position, 8.5, accuracy: 0.1, "Pausing an unloaded restored session is idempotent")
        let savedAgain = try XCTUnwrap(PlaybackBookmarkStore(defaults: defaults).restore(available: Set(catalog.map(\.id))))
        XCTAssertEqual(savedAgain.trackID, second.id)
        XCTAssertEqual(savedAgain.queueIDs, [first.id, second.id])
        XCTAssertEqual(savedAgain.position, 8.5, accuracy: 0.1)
        XCTAssertEqual(try Data(contentsOf: index), corrupt)
    }
}

private final class NavidromeTestProtocol: URLProtocol {
    static var respond: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.respond!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
