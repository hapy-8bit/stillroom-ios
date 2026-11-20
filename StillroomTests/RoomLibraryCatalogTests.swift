import XCTest
@testable import Stillroom

final class RoomLibraryCatalogTests: XCTestCase {
    func testSameAlbumTitleDoesNotMergeDifferentAlbumArtists() {
        let first = track("a", artist: "One", album: "Shared")
        let second = track("b", artist: "Two", album: "Shared")
        let albums = RoomLibraryCatalog.albums(tracks: [first, second], favorites: [])
        XCTAssertEqual(albums.count, 2)
        XCTAssertEqual(Set(albums.map(\.id)), Set([first.albumKey, second.albumKey]))
    }

    func testCompilationUsesExistingAlbumArtistIdentityAndKeepsOriginalRepresentative() {
        var first = track("a", artist: "Singer A", album: "Compilation")
        first.albumArtist = "Various"
        first.trackNumber = 2
        var second = track("b", artist: "Singer B", album: "Compilation")
        second.albumArtist = "Various"
        second.trackNumber = 1
        let albums = RoomLibraryCatalog.albums(tracks: [first, second], favorites: [])
        XCTAssertEqual(albums.count, 1)
        XCTAssertEqual(albums[0].representative.id, "a")
        XCTAssertEqual(albums[0].tracks.map(\.id), ["b", "a"])
    }

    func testSongTitleSearchFindsWholeAlbumAndSeparatelyReportsOnlyMatchingSongs() {
        let first = track("a", title: "Quiet Street", album: "Evening")
        let second = track("b", title: "By the Sea", album: "Evening")
        let other = track("c", title: "Daylight", album: "Morning")
        let source = [first, second, other]
        let albums = RoomLibraryCatalog.albums(tracks: source, favorites: [], query: " quiet   STREET ")
        XCTAssertEqual(albums.map(\.id), [first.albumKey])
        XCTAssertEqual(albums[0].tracks.map(\.id), ["a", "b"])
        XCTAssertEqual(albums[0].matchingTrackIDs, ["a"])
        XCTAssertEqual(RoomLibraryCatalog.matchingTracks(tracks: source, query: "QUIET street").map(\.id), ["a"])
        XCTAssertTrue(RoomLibraryCatalog.matchingTracks(tracks: source, query: "  \n ").isEmpty)
    }

    func testArtistAndDiacriticSearchUseRealMetadataWithoutChangingAlbumIdentity() {
        var song = track("a", title: "Café Door", artist: "Someone", album: "Album")
        song.albumArtist = "The Ensemble"
        XCTAssertEqual(RoomLibraryCatalog.matchingTracks(tracks: [song], query: "cafe").map(\.id), ["a"])
        XCTAssertEqual(RoomLibraryCatalog.albums(tracks: [song], favorites: [], query: "ensemble").first?.id,
                       song.albumKey)
        XCTAssertEqual(song.title, "Café Door")
    }

    func testFavoritesFilteringUsesOnlyExistingLikedSongIDs() {
        let source = [track("a", album: "One"), track("b", album: "One"), track("c", album: "Two")]
        let albums = RoomLibraryCatalog.albums(tracks: source, favorites: ["b", "missing"], favoritesOnly: true)
        XCTAssertEqual(albums.count, 1)
        XCTAssertEqual(albums[0].tracks.map(\.id), ["b"])
        XCTAssertTrue(RoomLibraryCatalog.albums(tracks: source, favorites: ["missing"], favoritesOnly: true).isEmpty)
    }

    func testNumberedSlotsSortByDiscThenTrackWhileUnknownPositionsStayStable() {
        var discTwo = track("d2")
        discTwo.discNumber = 2; discTwo.trackNumber = 1
        let unknownFirst = track("u1")
        var trackTwo = track("t2")
        trackTwo.trackNumber = 2
        let unknownSecond = track("u2")
        var trackOne = track("t1")
        trackOne.discNumber = 1; trackOne.trackNumber = 1
        let result = RoomLibraryCatalog.orderedTracks([discTwo, unknownFirst, trackTwo, unknownSecond, trackOne])
        XCTAssertEqual(result.map(\.id), ["t1", "u1", "t2", "u2", "d2"])
        XCTAssertNil(result[1].trackNumber)
        XCTAssertNil(result[2].discNumber)
        XCTAssertEqual(result[1].id, unknownFirst.id)
        XCTAssertEqual(result[3].id, unknownSecond.id)
    }

    func testTiedAndInvalidTrackNumbersKeepStablePositions() {
        var a = track("a"); a.trackNumber = 1
        var b = track("b"); b.trackNumber = 1
        var invalid = track("invalid"); invalid.trackNumber = 0
        XCTAssertEqual(RoomLibraryCatalog.orderedTracks([b, invalid, a]).map(\.id), ["b", "invalid", "a"])
    }

    func testSmartPlaylistsAreDynamicRealCollectionsAndNeverInventMembership() {
        let imported = track("local", demo: false)
        let original = track("demo", demo: true)
        let source = [imported, original, imported]
        let playlists = RoomLibraryCatalog.playlists(tracks: source, favorites: ["local", "missing"])
        XCTAssertEqual(playlists.map(\.id), [.favorites, .imported, .originals])
        XCTAssertEqual(playlists[0].tracks.map(\.id), ["local"])
        XCTAssertEqual(playlists[1].tracks.map(\.id), ["local"])
        XCTAssertEqual(playlists[2].tracks.map(\.id), ["demo"])
        XCTAssertTrue(RoomLibraryCatalog.playlists(tracks: [], favorites: ["missing"]).allSatisfy { $0.tracks.isEmpty })
    }

    func testSortingSupportsActualAlbumAndArtistNamesWithDeterministicTies() {
        let source = [track("b", artist: "Alpha", album: "Berry"),
                      track("a", artist: "Zulu", album: "Apple")]
        XCTAssertEqual(RoomLibraryCatalog.albums(tracks: source, favorites: [], sort: .album)
            .map(\.representative.id), ["a", "b"])
        XCTAssertEqual(RoomLibraryCatalog.albums(tracks: source, favorites: [], sort: .artist)
            .map(\.representative.id), ["b", "a"])
    }

    private func track(_ id: String, title: String = "Song", artist: String = "Artist",
                       album: String = "Album", demo: Bool = false) -> Track {
        Track(id: id, title: title, artist: artist, album: album, audioFile: id + ".wav",
              palette: .local, duration: 30, lyrics: "", isDemo: demo, isLyricDemo: false)
    }
}
