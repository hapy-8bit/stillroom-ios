import XCTest
import UIKit
import Combine
@testable import Stillroom

@MainActor
final class OneTapeLocalArtworkTests: XCTestCase {
    func testReplacingCoverPublishesOnlyCompleteArtworkSnapshots() async throws {
        let env = try environment()
        defer { env.cleanup() }
        let first = track("first", artwork: "automatic.jpg"), second = track("second", artwork: "automatic.jpg")
        try LocalCoverFixtures.image(.red).write(to: env.folder.appendingPathComponent("automatic.jpg"))
        try await LibraryRepository(directory: env.folder).save([first, second])
        let player = PlayerStore(directory: env.folder, defaults: env.defaults, emptyLibrary: true)
        await player.restore()
        var songSnapshots: [Set<String>] = [], albumSnapshots: [Set<String>] = []
        let songs = player.$artworks.dropFirst().sink { songSnapshots.append(Set($0.keys)) }
        let albums = player.$albumArtworks.dropFirst().sink { albumSnapshots.append(Set($0.keys)) }
        defer { songs.cancel(); albums.cancel() }
        let cover = env.folder.appendingPathComponent("new-album.jpg")
        try LocalCoverFixtures.image(.blue).write(to: cover)
        try await player.setImportedCover(second.id, url: cover, album: true)
        XCTAssertEqual(songSnapshots, [Set([first.id, second.id])])
        XCTAssertEqual(albumSnapshots, [Set([first.id, second.id])],
                       "Album consumers must not observe an empty or partial library while a cover is replaced")
    }

    func testAlbumFindsAutomaticArtworkOnLaterSongAndSharesCompilationArtist() async throws {
        let env = try environment()
        defer { env.cleanup() }
        var first = track("first", artist: "One singer")
        var second = track("second", artist: "Another singer", artwork: "automatic.jpg")
        first.albumArtist = "Various Artists"; second.albumArtist = "Various Artists"
        try LocalCoverFixtures.image(.red).write(to: env.folder.appendingPathComponent("automatic.jpg"))
        try await LibraryRepository(directory: env.folder).save([first, second])
        let player = PlayerStore(directory: env.folder, defaults: env.defaults, emptyLibrary: true)
        await player.restore()
        let store = music(player, env: env)
        XCTAssertEqual(store.albums.count, 1)
        let album = try XCTUnwrap(store.albums.first)
        await store.loadArtwork(for: album)
        XCTAssertNotNil(store.artworks[album.id], "A missing first-track image cannot hide a later album image")
        XCTAssertEqual(store.artworks[album.id]?.pngData(), player.albumArtworks[second.id]?.pngData())
    }

    func testExplicitAlbumCoverRefreshesCachedSleeveAndPreservesSongOnlyException() async throws {
        let env = try environment()
        defer { env.cleanup() }
        let first = track("first", artwork: "automatic.jpg"), second = track("second")
        try LocalCoverFixtures.image(.red).write(to: env.folder.appendingPathComponent("automatic.jpg"))
        try await LibraryRepository(directory: env.folder).save([first, second])
        let player = PlayerStore(directory: env.folder, defaults: env.defaults, emptyLibrary: true)
        await player.restore()
        let store = music(player, env: env)
        let album = try XCTUnwrap(store.albums.first)
        await store.loadArtwork(for: album)
        let automatic = try XCTUnwrap(store.artworks[album.id]?.pngData())
        let single = env.folder.appendingPathComponent("single.jpg"), albumCover = env.folder.appendingPathComponent("album.jpg")
        try LocalCoverFixtures.image(.green).write(to: single)
        try LocalCoverFixtures.image(.blue).write(to: albumCover)
        try await player.setImportedCover(first.id, url: single, album: false)
        XCTAssertEqual(store.artworks[album.id]?.pngData(), automatic, "Song-only art is never the album sleeve")
        let singleImage = player.artworks[first.id]?.pngData()
        try await player.setImportedCover(second.id, url: albumCover, album: true)
        XCTAssertNotEqual(store.artworks[album.id]?.pngData(), automatic)
        XCTAssertEqual(store.artworks[album.id]?.pngData(), player.albumArtworks[second.id]?.pngData())
        XCTAssertEqual(player.artworks[first.id]?.pngData(), singleImage)
        let reopened = PlayerStore(directory: env.folder, defaults: env.defaults, emptyLibrary: true)
        await reopened.restore()
        let restored = music(reopened, env: env)
        XCTAssertEqual(restored.artworks[album.id]?.pngData(), store.artworks[album.id]?.pngData())
        XCTAssertEqual(reopened.artworks[first.id]?.pngData(), singleImage)
    }

    func testSongOnlyCoverDoesNotInventAlbumArtWhenNoAutomaticImageExists() async throws {
        let env = try environment()
        defer { env.cleanup() }
        let first = track("first")
        try await LibraryRepository(directory: env.folder).save([first])
        let player = PlayerStore(directory: env.folder, defaults: env.defaults, emptyLibrary: true)
        await player.restore()
        let store = music(player, env: env)
        let cover = env.folder.appendingPathComponent("single.jpg")
        try LocalCoverFixtures.image(.green).write(to: cover)
        try await player.setImportedCover(first.id, url: cover, album: false)
        let album = try XCTUnwrap(store.albums.first)
        await store.loadArtwork(for: album)
        XCTAssertNotNil(player.artworks[first.id])
        XCTAssertNil(store.artworks[album.id])
    }

    private func track(_ id: String, artist: String = "Artist", artwork: String? = nil) -> Track {
        Track(id: id, title: id, artist: artist, album: "Same Album", audioFile: id + ".wav", artworkFile: artwork,
              palette: .local, duration: 30, lyrics: "", isDemo: false, isLyricDemo: false)
    }

    private func music(_ player: PlayerStore, env: CoverEnvironment) -> OneTapeMusicStore {
        OneTapeMusicStore(player: player, repository: NavidromeCatalogRepository(directory: env.folder.appendingPathComponent("Remote")))
    }

    private func environment() throws -> CoverEnvironment {
        let suite = "OneTape.local-art." + UUID().uuidString
        return CoverEnvironment(folder: try LocalCoverFixtures.directory(), defaults: try XCTUnwrap(UserDefaults(suiteName: suite)), suite: suite)
    }
}

private struct CoverEnvironment {
    let folder: URL
    let defaults: UserDefaults
    let suite: String
    func cleanup() {
        try? FileManager.default.removeItem(at: folder)
        defaults.removePersistentDomain(forName: suite)
    }
}
