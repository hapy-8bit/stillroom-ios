import Foundation

enum PlaybackDiagnosticEvent: String, Codable, Sendable {
    case launch, foreground, background, willTerminate, memoryWarning
    case load, play, pause, stop, seek, state, failure, cueFailure, analysisUnavailable
    case next, previous, diagnosticPayload
}

/// Fixed primitive fields prevent titles, file paths, servers and credentials
/// from accidentally entering the playback operation journal.
struct PlaybackDiagnosticEntry: Codable, Sendable {
    let timestamp: Double
    let session: String
    let processID: Int32
    let build: String
    let event: PlaybackDiagnosticEvent
    var position: Double?
    var playing: Bool?
    var preparing: Bool?
    var errorDomain: String?
    var errorCode: Int?
}

actor PlaybackDiagnosticArchive {
    private let directory: URL
    private let journalLimit: Int
    private let payloadLimit: Int
    private let payloadCount: Int

    init(directory: URL, journalLimit: Int = 262_144,
         payloadLimit: Int = 1_048_576, payloadCount: Int = 5) {
        self.directory = directory
        self.journalLimit = max(512, journalLimit)
        self.payloadLimit = max(512, payloadLimit)
        self.payloadCount = max(1, payloadCount)
    }

    func append(_ entry: PlaybackDiagnosticEntry) throws {
        try prepareDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(entry)
        data.append(0x0a)
        guard data.count <= journalLimit else { return }
        let file = directory.appendingPathComponent("playback.ndjson")
        let previous = directory.appendingPathComponent("playback-previous.ndjson")
        if FileManager.default.fileExists(atPath: file.path) {
            let size = (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue ?? 0
            if size + data.count > journalLimit {
                if FileManager.default.fileExists(atPath: previous.path) {
                    try FileManager.default.removeItem(at: previous)
                }
                try FileManager.default.moveItem(at: file, to: previous)
            }
        }
        if !FileManager.default.fileExists(atPath: file.path) {
            try data.write(to: file, options: .atomic)
        } else {
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        }
    }

    func storeSystemDiagnostic(_ data: Data) throws {
        guard data.count <= payloadLimit else { throw ArchiveError.payloadTooLarge }
        try prepareDirectory()
        let file = directory.appendingPathComponent("system-\(UUID().uuidString).json")
        try data.write(to: file, options: .atomic)
        let payloads = try FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.creationDateKey]).filter {
                $0.lastPathComponent.hasPrefix("system-") && $0.pathExtension == "json"
            }.sorted {
                let a = try $0.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
                let b = try $1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
                return a > b
            }
        for old in payloads.dropFirst(payloadCount) { try FileManager.default.removeItem(at: old) }
    }

    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    enum ArchiveError: Error { case payloadTooLarge }
}
