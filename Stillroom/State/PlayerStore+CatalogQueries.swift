import Foundation

extension PlayerStore {
    func albums(matching query: String = "") -> [Track] {
        var keys = Set<String>()
        return filteredTracks(query).filter { keys.insert($0.albumKey).inserted }
    }
    func albumTracks(_ track: Track) -> [Track] {
        let items = tracks.filter { $0.albumKey == track.albumKey }
        return items.enumerated().sorted { left, right in
            let ld = left.element.discNumber ?? 1, rd = right.element.discNumber ?? 1
            let ln = left.element.trackNumber ?? Int.max, rn = right.element.trackNumber ?? Int.max
            return ld != rd ? ld < rd : ln != rn ? ln < rn : left.offset < right.offset
        }.map(\.element)
    }

    func libraryAlbumQueue() -> [Track] { albums().flatMap(albumTracks) }

    func filteredTracks(_ query: String) -> [Track] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return libraryTracks }
        return libraryTracks.filter { "\($0.title) \($0.album) \($0.artist)".localizedStandardContains(term) }
    }
}
