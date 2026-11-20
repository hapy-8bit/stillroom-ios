import XCTest
@testable import Stillroom

final class OneTapeLibraryQueryTests: XCTestCase {
    func testSearchFindsTrackTitleInsideAlbumAndPreservesOriginalSongOrder() {
        let songs = [track("a1", title: "Unusual Song", artist: "Performer", remote: false),
                     track("a2", title: "Another", artist: "Performer", remote: false)]
        let album = collection("a", title: "An Album", ids: ["a2", "a1"])
        let found = query([album], tracks: songs, text: "unusual")
        XCTAssertEqual(found.map(\.id), ["a"])
        XCTAssertEqual(found.first?.trackIDs, ["a2", "a1"])
        XCTAssertTrue(query([album], tracks: songs, text: "no matching song").isEmpty)
    }

    func testSourceAndFavouritesUseSongIdentitiesRatherThanNames() {
        let local = track("local", title: "Same", artist: "Artist", remote: false)
        let remote = track("remote", title: "Same", artist: "Artist", remote: true)
        let localAlbum = collection("local-album", title: "Same", ids: [local.id])
        let remoteAlbum = collection("remote-album", title: "Same", ids: [remote.id])
        let albums = [localAlbum, remoteAlbum]
        XCTAssertEqual(query(albums, tracks: [local, remote], source: .navidrome).map(\.id), [remoteAlbum.id])
        XCTAssertEqual(query(albums, tracks: [local, remote], source: .local).map(\.id), [localAlbum.id])
        XCTAssertEqual(query(albums, tracks: [local, remote], source: .favourites,
                             favourites: [remote.id]).map(\.id), [remoteAlbum.id])
    }

    func testRecentlyPlayedMovesKnownCollectionsAheadWithoutReorderingUntouchedAlbums() {
        let a = collection("a", title: "One", ids: ["song-a"])
        let b = collection("b", title: "Two", ids: ["song-b"])
        let c = collection("c", title: "Three", ids: ["song-c"])
        XCTAssertEqual(query([a, b, c], tracks: [], sort: .recentlyPlayed,
                             recent: ["song-b", "removed", "song-b"]).map(\.id), ["b", "a", "c"])
    }

    func testRecentlyAddedUsesRealDatesAndRetainsUndatedLegacyOrder() {
        let old = collection("old", title: "Zulu", ids: [])
        let unknown = collection("unknown", title: "Apple", ids: [])
        var earlier = collection("earlier", title: "Zebra", ids: [])
        var later = collection("later", title: "Apricot", ids: [])
        earlier.addedAt = Date(timeIntervalSince1970: 100)
        later.addedAt = Date(timeIntervalSince1970: 200)
        XCTAssertEqual(query([old, earlier, unknown, later], tracks: []).map(\.id),
                       ["later", "earlier", "old", "unknown"])
    }

    func testRecentlyPlayedRanksAlbumAndPlaylistByTheMostRecentlyStartedMember() {
        let album = collection("album", title: "Album", ids: ["old", "new"])
        let playlist = collection("playlist", title: "Playlist", ids: ["middle", "old"])
        let untouched = collection("untouched", title: "Untouched", ids: ["never"])
        XCTAssertEqual(query([untouched, playlist, album], tracks: [], sort: .recentlyPlayed,
                             recent: ["new", "middle", "old"]).map(\.id),
                       ["album", "playlist", "untouched"])
    }

    func testTitleAndArtistSortingUseIndependentCatalogFields() {
        let a = collection("a", title: "Zebra", subtitle: "Alpha", ids: [])
        let b = collection("b", title: "Apple", subtitle: "Zulu", ids: [])
        XCTAssertEqual(query([a, b], tracks: [], sort: .albumAscending).map(\.id), ["b", "a"])
        XCTAssertEqual(query([a, b], tracks: [], sort: .albumDescending).map(\.id), ["a", "b"])
        XCTAssertEqual(query([a, b], tracks: [], sort: .artistAscending).map(\.id), ["a", "b"])
        XCTAssertEqual(query([a, b], tracks: [], sort: .artistDescending).map(\.id), ["b", "a"])
    }

    private func query(_ collections: [MusicCollection], tracks: [Track], text: String = "",
                       source: OneTapeLibrarySource = .all, sort: OneTapeLibrarySort = .recentlyAdded,
                       favourites: Set<String> = [], recent: [String] = []) -> [MusicCollection] {
        OneTapeLibraryQuery.collections(collections, tracks: tracks, query: text, source: source,
                                        sort: sort, favourites: favourites, recentlyPlayed: recent)
    }

    private func collection(_ id: String, title: String, subtitle: String = "Artist",
                            ids: [String]) -> MusicCollection {
        MusicCollection(id: id, kind: .album, title: title, subtitle: subtitle, remoteID: id,
                        trackIDs: ids, coverArtID: nil, year: nil, duration: 120)
    }

    private func track(_ id: String, title: String, artist: String, remote: Bool) -> Track {
        Track(id: id, title: title, artist: artist, album: "Album", audioFile: remote ? "" : id + ".wav",
              palette: .local, duration: 60, lyrics: "", isDemo: false, isLyricDemo: false,
              remote: remote ? RemoteTrackReference(connectionID: "server", songID: id,
                                                     albumID: "album", coverArtID: nil) : nil)
    }
}
