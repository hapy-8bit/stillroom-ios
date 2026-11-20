import XCTest
@testable import Stillroom

@MainActor
final class OneTapeSourcesTests: XCTestCase {
    func testMixedLibrarySummaryCountsOnlyConnectedCatalogAndDisconnectKeepsLocal() async throws {
        let env = try await environment()
        XCTAssertEqual(env.store.sourceAlbumCount, 1)
        XCTAssertEqual(env.store.sourceTrackCount, 2, "Playlist-only songs belong to the remote catalog too")
        XCTAssertEqual(env.store.albums.count, 2)
        XCTAssertEqual(env.player.libraryTracks.count, 3)
        env.player.choose(env.local, in: [env.local], autoplay: false)
        let localBytes = try Data(contentsOf: env.localIndex)

        let disconnected = await env.store.disconnect()

        XCTAssertTrue(disconnected)
        XCTAssertFalse(env.store.isLoading)
        XCTAssertNil(env.store.connection)
        XCTAssertEqual(env.store.sourceAlbumCount, 0)
        XCTAssertEqual(env.store.sourceTrackCount, 0)
        XCTAssertEqual(env.player.libraryTracks.map(\.id), [env.local.id])
        XCTAssertEqual(env.player.currentTrack?.id, env.local.id)
        XCTAssertEqual(env.store.albums.map(\.remoteID), [""])
        XCTAssertTrue(env.store.playlists.isEmpty)
        XCTAssertEqual(try Data(contentsOf: env.localIndex), localBytes)
        let saved = try await env.repository.load()
        let password = try await env.credentials.read(env.catalog.connection.credentialID)
        XCTAssertNil(saved)
        XCTAssertNil(password)
    }

    func testFailedDisconnectCommitKeepsConnectedCatalogAndLocalIndex() async throws {
        let env = try await environment()
        let file = env.remoteDirectory.appendingPathComponent("catalog.json")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let blocker = file.appendingPathComponent("unrelated-file")
        let original = Data("keep this file".utf8)
        try original.write(to: blocker)
        let localBytes = try Data(contentsOf: env.localIndex)

        let disconnected = await env.store.disconnect()

        XCTAssertFalse(disconnected)
        XCTAssertFalse(env.store.isLoading)
        assertOriginalCatalog(env)
        XCTAssertNotNil(env.store.message)
        XCTAssertEqual(try Data(contentsOf: blocker), original)
        XCTAssertEqual(try Data(contentsOf: env.localIndex), localBytes)
        let password = try await env.credentials.read(env.catalog.connection.credentialID)
        XCTAssertNotNil(password, "A failed catalog commit must retain its live credential")
    }

    func testRefreshWithoutCredentialPreservesCachedCatalogAndLocalIndex() async throws {
        let env = try await environment(saveCredential: false)
        let remoteBytes = try Data(contentsOf: env.remoteDirectory.appendingPathComponent("catalog.json"))
        let localBytes = try Data(contentsOf: env.localIndex)

        let refreshed = await env.store.refresh()

        XCTAssertFalse(refreshed)
        assertOriginalCatalog(env)
        XCTAssertEqual(env.store.message, NavidromeError.credentials.localizedDescription)
        XCTAssertEqual(try Data(contentsOf: env.remoteDirectory.appendingPathComponent("catalog.json")), remoteBytes)
        XCTAssertEqual(try Data(contentsOf: env.localIndex), localBytes)
    }

    func testRejectedRefreshPreservesConnectedCatalogAndSanitizesFailure() async throws {
        try await assertFailedRefresh(.response(403, Data("private-server-detail".utf8)))
    }

    func testTimedOutRefreshPreservesConnectedCatalogAndSanitizesFailure() async throws {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut,
            userInfo: [NSLocalizedDescriptionKey: "private-server-detail"])
        try await assertFailedRefresh(.failure(error))
    }

    func testRejectedAccountReplacementDoesNotReplaceWorkingAccountOrCredential() async throws {
        let env = try await environment()
        SourceTestProtocol.respond = { _ in .response(401, Data()) }
        let before = try Data(contentsOf: env.remoteDirectory.appendingPathComponent("catalog.json"))

        let connected = await env.store.connect(address: "https://another.example.test", username: "other", password: "test-only")

        XCTAssertFalse(connected)
        assertOriginalCatalog(env)
        XCTAssertEqual(try Data(contentsOf: env.remoteDirectory.appendingPathComponent("catalog.json")), before)
        let password = try await env.credentials.read(env.catalog.connection.credentialID)
        XCTAssertNotNil(password)
        XCTAssertFalse(env.store.message?.contains("private-server-detail") ?? true)
    }

    func testCancelledRefreshKeepsCatalogAndStopsBusyState() async throws {
        let env = try await environment()
        let entered = expectation(description: "Refresh reached its cancellable network request")
        SourceTestProtocol.respond = { _ in entered.fulfill(); return .hold }
        let before = try Data(contentsOf: env.remoteDirectory.appendingPathComponent("catalog.json"))
        let refresh = Task { await env.store.refresh() }
        await fulfillment(of: [entered], timeout: 5)

        env.store.cancel()
        let refreshed = await refresh.value

        XCTAssertFalse(refreshed)
        XCTAssertFalse(env.store.isLoading)
        XCTAssertNil(env.store.progress)
        assertOriginalCatalog(env)
        XCTAssertEqual(try Data(contentsOf: env.remoteDirectory.appendingPathComponent("catalog.json")), before)
    }

    func testDisconnectCancelsInFlightRefreshWithoutResurrectingRemoteMusic() async throws {
        let env = try await environment()
        let entered = expectation(description: "Refresh is waiting for a server response")
        SourceTestProtocol.respond = { _ in entered.fulfill(); return .hold }
        let refresh = Task { await env.store.refresh() }
        await fulfillment(of: [entered], timeout: 5)
        let localBytes = try Data(contentsOf: env.localIndex)

        let disconnected = await env.store.disconnect()
        let refreshed = await refresh.value

        XCTAssertTrue(disconnected)
        XCTAssertFalse(refreshed)
        XCTAssertNil(env.store.connection)
        XCTAssertEqual(env.store.sourceTrackCount, 0)
        XCTAssertEqual(env.player.libraryTracks.map(\.id), [env.local.id])
        XCTAssertFalse(env.store.isLoading)
        XCTAssertEqual(try Data(contentsOf: env.localIndex), localBytes)
        let saved = try await env.repository.load()
        XCTAssertNil(saved)
    }

    func testSuccessfulRefreshReplacesOnlyRemoteItemsAndKeepsLocalSelection() async throws {
        let env = try await environment()
        env.player.choose(env.local, in: [env.local], autoplay: false)
        let localBytes = try Data(contentsOf: env.localIndex)
        SourceTestProtocol.respond = { request in
            let parts = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let fields = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            let payload: [String: Any]
            switch parts.path.components(separatedBy: "/").last! {
            case "getAlbumList2.view":
                payload = ["albumList2": ["album": fields["offset"] == "0" ? [["id": "new-album"]] : []]]
            case "getAlbum.view":
                payload = ["album": ["id": "new-album", "name": "Refreshed Album", "songCount": 2,
                    "song": [["id": "one", "title": "One"], ["id": "three", "title": "Three"]]]]
            case "getPlaylists.view": payload = ["playlists": ["playlist": [["id": "p"]]]]
            case "getPlaylist.view":
                payload = ["playlist": ["id": "p", "name": "Selection", "songCount": 2,
                    "entry": [["id": "three", "title": "Three"], ["id": "four", "title": "Four"]]]]
            default: payload = [:]
            }
            let body = ["subsonic-response": payload.merging(["status": "ok"]) { old, _ in old }]
            return .response(200, try JSONSerialization.data(withJSONObject: body))
        }

        let refreshed = await env.store.refresh()

        XCTAssertTrue(refreshed)
        XCTAssertEqual(env.store.sourceAlbumCount, 1)
        XCTAssertEqual(env.store.sourceTrackCount, 3, "A playlist duplicate must not inflate the remote count")
        XCTAssertEqual(env.player.libraryTracks.count, 4)
        XCTAssertEqual(env.player.currentTrack?.id, env.local.id)
        XCTAssertEqual(env.player.queue.ids, [env.local.id])
        XCTAssertEqual(try Data(contentsOf: env.localIndex), localBytes)
        let saved = try await env.repository.load()
        XCTAssertEqual(saved?.tracks.count, 3)
        XCTAssertTrue(saved?.tracks.allSatisfy { $0.remote != nil } ?? false)
        XCTAssertFalse(saved?.tracks.contains { $0.remote?.songID == "two" } ?? true)
    }

    private func assertFailedRefresh(_ result: SourceTestProtocol.Result) async throws {
        let env = try await environment()
        SourceTestProtocol.respond = { _ in result }
        let before = try Data(contentsOf: env.remoteDirectory.appendingPathComponent("catalog.json"))
        let localBytes = try Data(contentsOf: env.localIndex)
        let refreshed = await env.store.refresh()
        XCTAssertFalse(refreshed)
        XCTAssertFalse(env.store.isLoading)
        assertOriginalCatalog(env)
        XCTAssertNotNil(env.store.message)
        XCTAssertFalse(env.store.message?.contains("private-server-detail") ?? true)
        XCTAssertFalse(env.store.message?.contains("https://") ?? true)
        XCTAssertEqual(try Data(contentsOf: env.remoteDirectory.appendingPathComponent("catalog.json")), before)
        XCTAssertEqual(try Data(contentsOf: env.localIndex), localBytes)
    }

    private func assertOriginalCatalog(_ env: SourceEnvironment, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(env.store.connection, env.catalog.connection, file: file, line: line)
        XCTAssertEqual(env.store.sourceAlbumCount, 1, file: file, line: line)
        XCTAssertEqual(env.store.sourceTrackCount, 2, file: file, line: line)
        XCTAssertEqual(Set(env.player.libraryTracks.map(\.id)), Set([env.local.id] + env.catalog.tracks.map(\.id)), file: file, line: line)
    }

    private func environment(saveCredential: Bool = true) async throws -> SourceEnvironment {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "OneTape.sources." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let localDirectory = root.appendingPathComponent("Local")
        let remoteDirectory = root.appendingPathComponent("Remote")
        let local = Track(id: "local", title: "Local", artist: "Test", album: "Local Album", audioFile: "kept.wav",
            palette: .local, duration: 20, lyrics: "", isDemo: false, isLyricDemo: false)
        try await LibraryRepository(directory: localDirectory).save([local])
        let connection = NavidromeConnection(id: UUID().uuidString, baseURL: URL(string: "https://music.example.test")!,
            username: "test-only", credentialID: UUID().uuidString)
        let tracks = ["one", "two"].map { id in
            Track(id: "navidrome:\(connection.id):song:\(id)", title: id, artist: "Test", album: "Remote Album",
                audioFile: "", palette: .local, duration: 20, lyrics: "", isDemo: false, isLyricDemo: false,
                remote: RemoteTrackReference(connectionID: connection.id, songID: id, albumID: "a", coverArtID: nil))
        }
        let album = MusicCollection(id: "remote-album", kind: .album, title: "Remote Album", subtitle: "Test",
            remoteID: "a", trackIDs: [tracks[0].id], coverArtID: nil, year: nil, duration: 20)
        let playlist = MusicCollection(id: "remote-playlist", kind: .playlist, title: "Remote Playlist", subtitle: "2 songs",
            remoteID: "p", trackIDs: tracks.map(\.id), coverArtID: nil, year: nil, duration: 40)
        let catalog = NavidromeCatalog(connection: connection, tracks: tracks, albums: [album], playlists: [playlist], updatedAt: Date())
        let repository = NavidromeCatalogRepository(directory: remoteDirectory)
        try await repository.save(catalog)
        let credentials = NavidromeCredentials()
        if saveCredential { try await credentials.save("test-only", as: connection.credentialID) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SourceTestProtocol.self]
        let session = URLSession(configuration: configuration)
        let player = PlayerStore(directory: localDirectory, defaults: defaults, emptyLibrary: true)
        let store = OneTapeMusicStore(player: player, repository: repository, credentials: credentials, session: session)
        let env = SourceEnvironment(root: root, suite: suite, defaults: defaults, remoteDirectory: remoteDirectory,
            localIndex: localDirectory.appendingPathComponent("library.json"), local: local, catalog: catalog,
            repository: repository, credentials: credentials, session: session, player: player, store: store)
        addTeardownBlock { await env.cleanup() }
        await store.restore()
        return env
    }
}

@MainActor
private struct SourceEnvironment {
    let root: URL
    let suite: String
    let defaults: UserDefaults
    let remoteDirectory: URL
    let localIndex: URL
    let local: Track
    let catalog: NavidromeCatalog
    let repository: NavidromeCatalogRepository
    let credentials: NavidromeCredentials
    let session: URLSession
    let player: PlayerStore
    let store: OneTapeMusicStore

    func cleanup() async {
        store.cancel()
        player.pause()
        session.invalidateAndCancel()
        SourceTestProtocol.respond = nil
        try? await credentials.remove(catalog.connection.credentialID)
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
}

private final class SourceTestProtocol: URLProtocol {
    enum Result {
        case response(Int, Data)
        case failure(Error)
        case hold
    }
    static var respond: ((URLRequest) throws -> Result)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let result = try Self.respond?(request) else { throw URLError(.unsupportedURL) }
            switch result {
            case let .response(status, data):
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            case .failure(let error): client?.urlProtocol(self, didFailWithError: error)
            case .hold: break
            }
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }

    override func stopLoading() {}
}
