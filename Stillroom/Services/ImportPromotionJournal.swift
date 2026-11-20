import Foundation

/// A bounded journal covers only preview promotion → index replacement, not restoration of an entire batch.
/// LibraryRepository must call recover only after validating the complete existing index.
enum ImportPromotionJournal {
    private struct Record: Codable {
        let version: Int
        let trackID: String
        let files: [String]
    }

    static func begin(directory: URL, track: Track) throws {
        let record = Record(version: 1, trackID: track.id,
                            files: [track.audioFile, track.artworkFile].compactMap { $0 })
        guard valid(record) else { throw LibraryError.invalidPath }
        let folder = directory.appendingPathComponent(".import-commits", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(track.id + ".json")
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw LibraryError.invalidPath }
        try JSONEncoder().encode(record).write(to: destination, options: .atomic)
    }

    static func complete(directory: URL, trackID: String) throws {
        guard UUID(uuidString: trackID) != nil else { throw LibraryError.invalidPath }
        let path = directory.appendingPathComponent(".import-commits").appendingPathComponent(trackID + ".json")
        if FileManager.default.fileExists(atPath: path.path) { try FileManager.default.removeItem(at: path) }
    }

    static func recover(directory: URL, committedIDs: Set<String>) throws {
        let folder = directory.appendingPathComponent(".import-commits", isDirectory: true)
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        for path in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey]) {
            guard path.pathExtension == "json", UUID(uuidString: path.deletingPathExtension().lastPathComponent) != nil else { continue }
            guard let size = try path.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 4096 else { throw LibraryError.corruptIndex }
            let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: path))
            guard valid(record), path.lastPathComponent == record.trackID + ".json" else { throw LibraryError.corruptIndex }
            if !committedIDs.contains(record.trackID) {
                for name in record.files {
                    let asset = directory.appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath: asset.path) { try FileManager.default.removeItem(at: asset) }
                }
            }
            try FileManager.default.removeItem(at: path)
        }
    }

    private static func valid(_ record: Record) -> Bool {
        record.version == 1 && UUID(uuidString: record.trackID) != nil &&
            !record.files.isEmpty && record.files.count <= 2 && Set(record.files).count == record.files.count &&
            record.files.allSatisfy { LibraryRepository.isSafeBasename($0) && $0.hasPrefix(record.trackID + ".") }
    }
}
