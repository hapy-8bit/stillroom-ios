import Foundation

enum RoomLibrarySort: String, CaseIterable, Identifiable, Hashable {
    case album, artist
    var id: String { rawValue }
    var title: String { self == .album ? "专辑名称" : "艺人名称" }
}

struct RoomLibraryAlbum: Identifiable, Equatable {
    let id: String
    let representative: Track
    let tracks: [Track]
    let matchingTrackIDs: Set<String>
}

enum RoomSmartPlaylistKind: String, CaseIterable, Identifiable, Hashable {
    case favorites, imported, originals
    var id: String { rawValue }
    var title: String {
        switch self {
        case .favorites: return "我喜欢的"
        case .imported: return "本机导入"
        case .originals: return "随附音乐"
        }
    }
    var symbol: String {
        switch self {
        case .favorites: return "heart"
        case .imported: return "arrow.down.doc"
        case .originals: return "opticaldisc"
        }
    }
    var detail: String {
        switch self {
        case .favorites: return "根据歌曲的喜欢状态自动整理"
        case .imported: return "已导入本机的音乐自动汇集在这里"
        case .originals: return "随应用提供的参考音乐"
        }
    }
}

struct RoomSmartPlaylist: Identifiable, Equatable {
    let kind: RoomSmartPlaylistKind
    let tracks: [Track]
    var id: RoomSmartPlaylistKind { kind }
    var title: String { kind.title }
    var detail: String { kind.detail }
}

/// Pure projections of the supplied library. No history, playlist membership or dates are invented.
enum RoomLibraryCatalog {
    /// Search finds whole albums, even when only one song title matches. `matchingTrackIDs`
    /// identifies matching songs for a separate search section; playback keeps the real album.
    /// Favorites are song IDs: that filter intentionally produces albums of liked songs only.
    static func albums(tracks: [Track], favorites: Set<String>, query: String = "",
                       favoritesOnly: Bool = false, sort: RoomLibrarySort = .album) -> [RoomLibraryAlbum] {
        let source = uniqueTracks(tracks).filter { !favoritesOnly || favorites.contains($0.id) }
        var grouped: [String: [Track]] = [:]
        var keys: [String] = []
        for track in source {
            if grouped[track.albumKey] == nil { keys.append(track.albumKey) }
            grouped[track.albumKey, default: []].append(track)
        }
        let search = normalized(query)
        let result = keys.compactMap { key -> RoomLibraryAlbum? in
            guard let members = grouped[key], let first = members.first else { return nil }
            let matching = Set(members.filter { matches($0, normalizedQuery: search) }.map(\.id))
            guard search.isEmpty || !matching.isEmpty else { return nil }
            return RoomLibraryAlbum(id: key, representative: first,
                                    tracks: orderedTracks(members), matchingTrackIDs: matching)
        }
        return result.enumerated().sorted { lhs, rhs in
            let left = lhs.element.representative
            let right = rhs.element.representative
            let primary = compare(sort == .album ? left.album : albumArtist(left),
                                  sort == .album ? right.album : albumArtist(right))
            if primary != .orderedSame { return primary == .orderedAscending }
            let secondary = compare(sort == .album ? albumArtist(left) : left.album,
                                    sort == .album ? albumArtist(right) : right.album)
            return secondary == .orderedSame ? lhs.offset < rhs.offset : secondary == .orderedAscending
        }.map(\.element)
    }

    /// Empty search has no result section. Matching keeps original library order and identity.
    static func matchingTracks(tracks: [Track], query: String) -> [Track] {
        let search = normalized(query)
        guard !search.isEmpty else { return [] }
        return uniqueTracks(tracks).filter { matches($0, normalizedQuery: search) }
    }

    static func playlists(tracks: [Track], favorites: Set<String>) -> [RoomSmartPlaylist] {
        let source = uniqueTracks(tracks)
        return RoomSmartPlaylistKind.allCases.map { kind in
            let members = source.filter { track in
                switch kind {
                case .favorites: return favorites.contains(track.id)
                case .imported: return !track.isDemo
                case .originals: return track.isDemo
                }
            }
            return RoomSmartPlaylist(kind: kind, tracks: members)
        }
    }

    /// Only slots with a usable disc/track tuple are reordered; tracks without track numbers
    /// stay in their original positions. A missing disc number is the conventional first disc
    /// for sorting only, and never changes or fabricates stored metadata or displayed labels.
    static func orderedTracks(_ tracks: [Track]) -> [Track] {
        let source = uniqueTracks(tracks)
        let numbered = source.enumerated().filter { ($0.element.trackNumber ?? 0) > 0 }
            .sorted { lhs, rhs in
                let leftDisc = max(1, lhs.element.discNumber ?? 1)
                let rightDisc = max(1, rhs.element.discNumber ?? 1)
                if leftDisc != rightDisc { return leftDisc < rightDisc }
                let leftNumber = lhs.element.trackNumber ?? 0
                let rightNumber = rhs.element.trackNumber ?? 0
                return leftNumber == rightNumber ? lhs.offset < rhs.offset : leftNumber < rightNumber
            }.map(\.element)
        var next = numbered.makeIterator()
        return source.map { track in
            (track.trackNumber ?? 0) > 0 ? (next.next() ?? track) : track
        }
    }

    private static func uniqueTracks(_ tracks: [Track]) -> [Track] {
        var seen = Set<String>()
        return tracks.filter { seen.insert($0.id).inserted }
    }

    private static func normalized(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func albumArtist(_ track: Track) -> String {
        track.albumArtist?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ?
            (track.albumArtist ?? track.artist) : track.artist
    }

    private static func matches(_ track: Track, normalizedQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else { return false }
        return [track.title, track.album, track.artist, track.albumArtist ?? ""]
            .contains { normalized($0).contains(normalizedQuery) }
    }

    private static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        normalized(lhs).localizedStandardCompare(normalized(rhs))
    }
}
