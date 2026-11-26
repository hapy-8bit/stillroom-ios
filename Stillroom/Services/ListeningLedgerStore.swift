import Foundation

/// Persists real in-app listening sessions in an isolated atomic JSON ledger.
/// Corrupted files are preserved untouched on disk rather than overwritten so
/// playback remains unaffected and historical data can never be silently lost.
@MainActor
final class ListeningLedgerStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var readable = true
    private(set) var ledger = ListeningLedger()

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Stillroom", isDirectory: true)
            self.fileURL = root.appendingPathComponent("listening-ledger.json")
        }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        restore()
    }

    static func defaultURL(for arguments: [String]) -> URL? {
        guard arguments.contains("--one-tape-appearance-fixture") else { return nil }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("stillroom-insights-fixture-ledger.json")
    }

    private func restore() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let events = try decoder.decode([ListeningSessionEvent].self, from: data)
            ledger = try ListeningLedger.restored(events)
        } catch {
            // Preserve unreadable archive on disk without overwriting.
            readable = false
        }
    }

    @discardableResult
    func upsert(_ event: ListeningSessionEvent) throws -> ListeningLedger {
        guard readable else { throw ListeningLedgerError.corruptedArchive }
        var next = ledger
        guard next.upsert(event) else { return ledger }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(next.events)
        try data.write(to: fileURL, options: .atomic)
        ledger = next
        return ledger
    }
}
