import Foundation

enum OneTapeLibraryLayout: String {
    case shelf, grid
}

enum OneTapeLibrarySection: String, CaseIterable, Identifiable {
    case albums, playlists
    var id: Self { self }
    var title: String { self == .albums ? "专辑" : "播放列表" }
}

enum OneTapeLibrarySource: String, CaseIterable, Identifiable {
    case all, local, navidrome, favourites
    var id: Self { self }
    var title: String {
        switch self {
        case .all: "全部"
        case .local: "本地"
        case .navidrome: "Navidrome"
        case .favourites: "Favourites"
        }
    }
}

enum OneTapeLibrarySort: String, CaseIterable, Identifiable {
    case recentlyAdded, recentlyPlayed, albumAscending, albumDescending
    case artistAscending, artistDescending
    var id: Self { self }
    var title: String {
        switch self {
        case .recentlyAdded: "Recently added"
        case .recentlyPlayed: "Recently played"
        case .albumAscending: "Album A–Z"
        case .albumDescending: "Album Z–A"
        case .artistAscending: "Artist A–Z"
        case .artistDescending: "Artist Z–A"
        }
    }
}

/// Filtering uses durable song identities, so an album with an unexpected remote
/// title or two versions of the same song does not accidentally disappear.
enum OneTapeLibraryQuery {
    static func collections(
        _ collections: [MusicCollection], tracks: [Track], query: String,
        source: OneTapeLibrarySource, sort: OneTapeLibrarySort,
        favourites: Set<String>, recentlyPlayed: [String]
    ) -> [MusicCollection] {
        let songs = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { _, newer in newer })
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = collections.filter { collection in
            let entries = collection.trackIDs.compactMap { songs[$0] }
            let sourceMatches: Bool
            switch source {
            case .all: sourceMatches = true
            case .local: sourceMatches = entries.contains { $0.remote == nil }
            case .navidrome: sourceMatches = entries.contains { $0.remote != nil }
            case .favourites: sourceMatches = collection.trackIDs.contains { favourites.contains($0) }
            }
            guard sourceMatches else { return false }
            guard !search.isEmpty else { return true }
            let text = [collection.title, collection.subtitle] + entries.flatMap { [$0.title, $0.artist] }
            return text.contains { $0.localizedStandardContains(search) }
        }
        let ranks = Dictionary(recentlyPlayed.enumerated().map { ($0.element, $0.offset) },
                               uniquingKeysWith: { older, _ in older })
        switch sort {
        case .recentlyAdded:
            // Undated legacy items keep their relative order after known dates.
            // A refresh timestamp is never substituted for an import date.
            result = result.enumerated().sorted {
                switch ($0.element.addedAt, $1.element.addedAt) {
                case let (a?, b?) where a != b: return a > b
                case (_?, nil): return true
                case (nil, _?): return false
                default: return $0.offset < $1.offset
                }
            }.map(\.element)
        case .recentlyPlayed:
            // History belongs to songs actually started by the shared engine,
            // so album and playlist sorting also covers transport/system controls.
            result = result.enumerated().sorted {
                let lhs = $0.element.trackIDs.compactMap { ranks[$0] }.min() ?? Int.max
                let rhs = $1.element.trackIDs.compactMap { ranks[$0] }.min() ?? Int.max
                return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
            }.map(\.element)
        case .albumAscending, .albumDescending, .artistAscending, .artistDescending:
            result.sort { lhs, rhs in
                let byArtist = sort == .artistAscending || sort == .artistDescending
                let a = byArtist ? lhs.subtitle : lhs.title
                let b = byArtist ? rhs.subtitle : rhs.title
                let order = a.localizedStandardCompare(b)
                if order == .orderedSame { return lhs.id < rhs.id }
                let descending = sort == .albumDescending || sort == .artistDescending
                return order == (descending ? .orderedDescending : .orderedAscending)
            }
        }
        return result
    }
}
