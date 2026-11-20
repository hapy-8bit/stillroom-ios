import Foundation

struct PlaybackBookmark: Codable, Equatable {
    var trackID: String
    var queueIDs: [String]
    var originalIDs: [String]
    var shuffled: Bool
    var repeatMode: RepeatMode
    var position: Double
    var queueTitle: String? = nil
    var finished: Bool? = nil
    var craftedSession: CraftListeningSession? = nil
}

/// Lightweight session metadata only. The audio engine remains the sole source of media seconds.
@MainActor
final class PlaybackBookmarkStore {
    private let defaults: UserDefaults
    private let key = "orbit.playback.v1"
    init(defaults: UserDefaults) { self.defaults = defaults }

    func restore(available: Set<String>) throws -> PlaybackBookmark? {
        guard let data = defaults.data(forKey: key) else { return nil }
        var bookmark = try JSONDecoder().decode(PlaybackBookmark.self, from: data)
        guard available.contains(bookmark.trackID), bookmark.position.isFinite, bookmark.position >= 0 else { return nil }
        bookmark.queueIDs = unique(bookmark.queueIDs.filter(available.contains))
        bookmark.originalIDs = unique(bookmark.originalIDs.filter(available.contains))
        if bookmark.queueIDs.isEmpty { bookmark.queueIDs = [bookmark.trackID] }
        if !bookmark.queueIDs.contains(bookmark.trackID) { bookmark.queueIDs.insert(bookmark.trackID, at: 0) }
        if bookmark.originalIDs.isEmpty { bookmark.originalIDs = bookmark.queueIDs }
        return bookmark
    }

    func save(_ bookmark: PlaybackBookmark) throws {
        guard !bookmark.trackID.isEmpty, bookmark.position.isFinite, bookmark.position >= 0 else { return }
        defaults.set(try JSONEncoder().encode(bookmark), forKey: key)
    }

    private func unique(_ ids: [String]) -> [String] { var seen = Set<String>(); return ids.filter { seen.insert($0).inserted } }
}
