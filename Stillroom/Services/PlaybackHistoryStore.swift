import Foundation

/// A most-recent-first list of durable song identities, independent of the
/// order local and remote catalogs restore. No media clock or signed URLs.
@MainActor
final class PlaybackHistoryStore {
    private let defaults: UserDefaults
    private let key = "onetape.playback-history.v1"
    private var readable = true
    private var history = PlaybackHistory()
    var trackIDs: [String] { history.trackIDs }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: key) else { return }
        do {
            let ids = try JSONDecoder().decode([String].self, from: data)
            history = try PlaybackHistory.restored(ids)
        } catch {
            // Preserve an unreadable record rather than overwriting it when a
            // new song starts. Playback itself remains available.
            readable = false
        }
    }

    func record(_ id: String) throws -> [String] {
        guard readable else { throw PlaybackHistoryError.invalidRecord }
        var next = history
        guard next.record(id) else { return trackIDs }
        defaults.set(try JSONEncoder().encode(next.trackIDs), forKey: key)
        history = next
        return trackIDs
    }
}
