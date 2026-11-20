import XCTest
@testable import Stillroom

@MainActor
final class OneTapeFavoritesTests: XCTestCase {
    func testMixedFavoritesSurviveLocalThenRemoteCatalogColdRestore() async throws {
        let environment = try environment()
        defer { environment.cleanup() }
        let local = localTrack(), remote = remoteTrack()
        try await LibraryRepository(directory: environment.directory).save([local])
        let catalog = NavidromeCatalog(connection: connection(), tracks: [remote],
            albums: [album(remote, id: "remote-album")], playlists: [], updatedAt: Date())
        try await NavidromeCatalogRepository(directory: environment.remoteDirectory).save(catalog)
        environment.defaults.set([local.id, remote.id], forKey: "favorites")

        // This is the production cold-start order: local PlayerStore restoration
        // finishes before OneTapeMusicStore reads its separate remote catalog.
        let player = PlayerStore(directory: environment.directory, defaults: environment.defaults, emptyLibrary: true)
        let music = OneTapeMusicStore(player: player,
            repository: NavidromeCatalogRepository(directory: environment.remoteDirectory))
        await music.restore()
        XCTAssertTrue(player.libraryReady)
        XCTAssertEqual(Set(player.libraryTracks.map(\.id)), [local.id, remote.id])
        XCTAssertEqual(player.favorites, [local.id, remote.id])
        XCTAssertEqual(Set(favourites(music.albums, player: player).flatMap(\.trackIDs)), [local.id, remote.id])
        XCTAssertFalse(player.isPlaying)
    }

    func testToggleUpdatesMixedLibraryFilterAndPersistsCancellation() async throws {
        let environment = try environment()
        defer { environment.cleanup() }
        let local = localTrack(), remote = remoteTrack()
        try await LibraryRepository(directory: environment.directory).save([local])
        let player = PlayerStore(directory: environment.directory, defaults: environment.defaults, emptyLibrary: true)
        await player.restore()
        player.setRemoteTracks([remote], streamURL: nil)
        let albums = [album(local, id: "local-album"), album(remote, id: "remote-album")]
        XCTAssertTrue(favourites(albums, player: player).isEmpty)
        player.toggleFavorite(local)
        player.toggleFavorite(remote)
        XCTAssertEqual(favourites(albums, player: player).map(\.id), ["local-album", "remote-album"])
        player.toggleFavorite(remote)
        XCTAssertEqual(favourites(albums, player: player).map(\.id), ["local-album"])

        let restored = PlayerStore(directory: environment.directory, defaults: environment.defaults, emptyLibrary: true)
        await restored.restore()
        restored.setRemoteTracks([remote], streamURL: nil)
        XCTAssertEqual(restored.favorites, [local.id])
        XCTAssertEqual(favourites(albums, player: restored).map(\.id), ["local-album"])
    }

    func testUnavailableRemoteFavoritesRemainPreferencesAcrossDisconnectAndLocalToggle() async throws {
        let environment = try environment()
        defer { environment.cleanup() }
        let local = localTrack(), remote = remoteTrack()
        try await LibraryRepository(directory: environment.directory).save([local])
        environment.defaults.set([remote.id], forKey: "favorites")
        let player = PlayerStore(directory: environment.directory, defaults: environment.defaults, emptyLibrary: true)
        await player.restore()
        XCTAssertEqual(player.favorites, [remote.id])
        player.toggleFavorite(local)
        player.setRemoteTracks([remote], streamURL: nil)
        player.setRemoteTracks([], streamURL: nil)
        XCTAssertEqual(player.favorites, [local.id, remote.id])

        let restored = PlayerStore(directory: environment.directory, defaults: environment.defaults, emptyLibrary: true)
        await restored.restore()
        restored.setRemoteTracks([remote], streamURL: nil)
        XCTAssertEqual(restored.favorites, [local.id, remote.id])
        XCTAssertEqual(Set(favourites([album(local, id: "local-album"), album(remote, id: "remote-album")],
                                       player: restored).flatMap(\.trackIDs)), [local.id, remote.id])
    }

    private func favourites(_ albums: [MusicCollection], player: PlayerStore) -> [MusicCollection] {
        OneTapeLibraryQuery.collections(albums, tracks: player.libraryTracks, query: "", source: .favourites,
            sort: .albumAscending, favourites: player.favorites, recentlyPlayed: [])
    }

    private func connection() -> NavidromeConnection {
        NavidromeConnection(id: "favorite-test", baseURL: URL(string: "https://music.example.test")!,
                            username: "test", credentialID: "missing-favorite-test-" + UUID().uuidString)
    }

    private func localTrack() -> Track {
        Track(id: "local-favorite", title: "Local", artist: "Artist", album: "Local Album", audioFile: "local.wav",
              palette: .local, duration: 20, lyrics: "", isDemo: false, isLyricDemo: false)
    }

    private func remoteTrack() -> Track {
        Track(id: "navidrome:favorite-test:song:remote", title: "Remote", artist: "Artist", album: "Remote Album",
            audioFile: "", palette: .local, duration: 20, lyrics: "", isDemo: false, isLyricDemo: false,
            remote: RemoteTrackReference(connectionID: "favorite-test", songID: "remote", albumID: "album", coverArtID: nil))
    }

    private func album(_ track: Track, id: String) -> MusicCollection {
        MusicCollection(id: id, kind: .album, title: track.album, subtitle: track.artist,
            remoteID: track.remote == nil ? "" : "album", trackIDs: [track.id], coverArtID: nil, year: nil, duration: track.duration)
    }

    private func environment() throws -> FavoritesEnvironment {
        let suite = "OneTape.favorites." + UUID().uuidString
        return FavoritesEnvironment(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
                                    defaults: try XCTUnwrap(UserDefaults(suiteName: suite)), suite: suite)
    }
}

private struct FavoritesEnvironment {
    let directory: URL
    let defaults: UserDefaults
    let suite: String
    var remoteDirectory: URL { directory.appendingPathComponent("remote-catalog") }

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suite)
    }
}
