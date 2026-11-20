import Foundation

struct SubsonicEnvelope: Decodable, Sendable {
    let response: SubsonicResponse
    enum CodingKeys: String, CodingKey { case response = "subsonic-response" }
}

struct SubsonicResponse: Decodable, Sendable {
    struct Failure: Decodable, Sendable { let code: Int }
    struct AlbumList: Decodable, Sendable { let album: [SubsonicAlbum]? }
    struct Playlists: Decodable, Sendable { let playlist: [SubsonicPlaylist]? }
    let status: String
    let error: Failure?
    let albumList2: AlbumList?
    let album: SubsonicAlbum?
    let playlists: Playlists?
    let playlist: SubsonicPlaylist?
}

struct SubsonicAlbum: Decodable, Sendable {
    let id: String
    let name: String?
    let artist: String?
    let coverArt: String?
    let year: Int?
    let duration: Double?
    let songCount: Int?
    let song: [SubsonicSong]?
    let created: String?

    func musicTracks(connectionID: String) throws -> [Track] {
        let entries = song ?? []
        if let count = songCount, count != entries.count { throw NavidromeError.invalidResponse }
        return try entries.map { try $0.track(connectionID: connectionID, album: self) }
    }

    func collection(connectionID: String, songs: [Track], fallbackCreated: String? = nil) -> MusicCollection {
        MusicCollection(id: "navidrome:\(connectionID):album:\(id)", kind: .album,
            title: name ?? "未命名专辑", subtitle: artist ?? "未知艺人", remoteID: id,
            trackIDs: songs.map(\.id), coverArtID: coverArt, year: year,
            duration: duration ?? songs.reduce(0) { $0 + $1.duration },
            addedAt: SubsonicDate.parse(created) ?? SubsonicDate.parse(fallbackCreated))
    }
}

struct SubsonicPlaylist: Decodable, Sendable {
    let id: String
    let name: String?
    let coverArt: String?
    let duration: Double?
    let songCount: Int?
    let entry: [SubsonicSong]?
    let created: String?

    func musicTracks(connectionID: String) throws -> [Track] {
        let entries = entry ?? []
        if let count = songCount, count != entries.count { throw NavidromeError.invalidResponse }
        return try entries.map { try $0.track(connectionID: connectionID) }
    }

    func collection(connectionID: String, songs: [Track], fallbackCreated: String? = nil) -> MusicCollection {
        MusicCollection(id: "navidrome:\(connectionID):playlist:\(id)", kind: .playlist,
            title: name ?? "未命名播放列表", subtitle: "\(songs.count) 首音乐", remoteID: id,
            trackIDs: songs.map(\.id), coverArtID: coverArt, year: nil,
            duration: duration ?? songs.reduce(0) { $0 + $1.duration },
            addedAt: SubsonicDate.parse(created) ?? SubsonicDate.parse(fallbackCreated))
    }
}

struct SubsonicSong: Decodable, Sendable {
    struct Artist: Decodable, Sendable { let name: String? }
    let id: String
    let title: String?
    let artist: String?
    let album: String?
    let albumId: String?
    let albumArtists: [Artist]?
    let displayAlbumArtist: String?
    let coverArt: String?
    let duration: Double?
    let track: Int?
    let discNumber: Int?
    let isDir: Bool?
    let isVideo: Bool?
    let created: String?

    func track(connectionID: String, album parent: SubsonicAlbum? = nil) throws -> Track {
        guard !id.isEmpty, isDir != true, isVideo != true else { throw NavidromeError.invalidResponse }
        var result = Track(id: "navidrome:\(connectionID):song:\(id)", title: title ?? "未命名歌曲",
            artist: artist ?? parent?.artist ?? "未知艺人", album: album ?? parent?.name ?? "未命名专辑",
            audioFile: "", artworkFile: nil, palette: .local,
            duration: duration?.isFinite == true ? max(0, duration ?? 0) : 0,
            lyrics: "", isDemo: false, isLyricDemo: false)
        result.albumArtist = displayAlbumArtist ?? albumArtists?.compactMap(\.name).first ?? parent?.artist
        result.trackNumber = track
        result.discNumber = discNumber
        result.addedAt = SubsonicDate.parse(created)
        result.remote = RemoteTrackReference(connectionID: connectionID, songID: id,
            albumID: albumId ?? parent?.id, coverArtID: coverArt ?? parent?.coverArt)
        return result
    }
}

/// OpenSubsonic dates may include fractional seconds and timezone offsets.
/// Missing/invalid metadata stays unknown; catalog refresh time is unrelated.
enum SubsonicDate {
    static func parse(_ text: String?) -> Date? {
        guard let text else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: text) { return date }
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: text)
    }
}
