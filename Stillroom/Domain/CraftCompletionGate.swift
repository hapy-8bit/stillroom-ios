import Foundation

/// Claims at most one automatic completion write for each most recently attempted edition.
/// A failed commit stays claimed so the archive's busy→idle notification cannot loop forever;
/// explicit collection remains a separate, retryable operation.
struct CraftCompletionGate {
    private var attemptedEditions: [String: CraftedRecord] = [:]

    mutating func claim(session: CraftListeningSession?, records: [CraftedRecord]) -> String? {
        guard let session, session.phase == .finished, session.allReachedEnd,
              let latest = records.first(where: { $0.id == session.record.id }),
              latest.hasSameEdition(as: session.record), latest.completedAt == nil,
              attemptedEditions[session.record.id]?.hasSameEdition(as: session.record) != true else { return nil }
        attemptedEditions[session.record.id] = session.record
        return session.record.id
    }
}
