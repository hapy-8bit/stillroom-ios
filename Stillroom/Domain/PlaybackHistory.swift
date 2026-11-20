import Foundation

enum PlaybackHistoryError: Error { case invalidRecord }

/// Most-recent-first song identities. Unavailable items remain here so a
/// later local/remote catalog publication can still recover its own history.
struct PlaybackHistory {
    private(set) var trackIDs: [String] = []
    private static let limit = 20_000

    static func restored(_ ids: [String]) throws -> PlaybackHistory {
        guard ids.count <= limit, ids.allSatisfy(validID), Set(ids).count == ids.count else {
            throw PlaybackHistoryError.invalidRecord
        }
        var history = PlaybackHistory()
        history.trackIDs = ids
        return history
    }

    mutating func record(_ id: String) -> Bool {
        guard Self.validID(id), trackIDs.first != id else { return false }
        trackIDs = Array(([id] + trackIDs.filter { $0 != id }).prefix(Self.limit))
        return true
    }

    private static func validID(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= 4_096 && !id.contains("\0")
    }
}
