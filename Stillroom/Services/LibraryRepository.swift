import Foundation

enum LibraryError: LocalizedError {
    case corruptIndex, invalidPath, invalidLyrics, missingAudio, duplicateAudio
    var errorDescription: String? {
        switch self {
        case .corruptIndex: return "曲库索引无法读取，原文件已保留。"
        case .invalidPath: return "音乐文件路径无效。"
        case .invalidLyrics: return "请选择不超过 1 MB、UTF-8 编码的 LRC 或 TXT 歌词。"
        case .missingAudio: return "没有找到这首音乐，请重新导入。"
        case .duplicateAudio: return "相同的音乐文件已在曲库中。"
        }
    }
}

actor LibraryRepository {
    let directory: URL
    private var indexIsReadable = true
    private var committedTracks: [Track]?

    init(directory: URL) { self.directory = directory }

    static func isSafeBasename(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." &&
            !value.contains("/") && !value.contains("\\") && !value.contains("\0")
    }

    func restore() throws -> [Track] {
        let file = directory.appendingPathComponent("library.json")
        guard FileManager.default.fileExists(atPath: file.path) else {
            // A genuinely absent index is a verified empty library, unlike an unreadable/corrupt index.
            do {
                try ImportPromotionJournal.recover(directory: directory, committedIDs: [])
                indexIsReadable = true; committedTracks = []; return []
            } catch { indexIsReadable = false; throw LibraryError.corruptIndex }
        }
        do {
            var result = try JSONDecoder().decode([Track].self, from: Data(contentsOf: file))
            guard Set(result.map(\.id)).count == result.count,
                  result.allSatisfy({ !$0.isDemo && $0.remote == nil && Self.isSafeBasename($0.audioFile) &&
                      ($0.artworkFile.map(Self.isSafeBasename) ?? true) }) else { throw LibraryError.corruptIndex }
            // Older indexes have no fingerprint. Missing audio still remains visible for recovery.
            for index in result.indices where result[index].contentHash == nil {
                result[index].contentHash = try? AudioImportAccess.fingerprint(
                    directory.appendingPathComponent(result[index].audioFile))
            }
            try ImportPromotionJournal.recover(directory: directory, committedIDs: Set(result.map(\.id)))
            indexIsReadable = true
            committedTracks = result
            return result
        } catch {
            // Never replace an unreadable index with a new empty library after an import.
            indexIsReadable = false
            throw LibraryError.corruptIndex
        }
    }

    func save(_ tracks: [Track]) throws {
        guard indexIsReadable else { throw LibraryError.corruptIndex }
        // Legacy callers may save without an explicit restore; validate an existing index before any overwrite.
        if committedTracks == nil { _ = try restore() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let automatic = tracks.filter { !$0.isDemo && $0.remote == nil }.map(MediaOverridesStore.automaticTrack)
        guard Set(automatic.map(\.id)).count == automatic.count,
              automatic.allSatisfy({ Self.isSafeBasename($0.audioFile) &&
                  ($0.artworkFile.map(Self.isSafeBasename) ?? true) }) else { throw LibraryError.corruptIndex }
        let data = try JSONEncoder().encode(automatic)
        try data.write(to: directory.appendingPathComponent("library.json"), options: .atomic)
        committedTracks = automatic
    }

    /// The actor serializes promotion and index replacement. A duplicate returns its original identity;
    /// a failed save removes only files just moved out of our UUID preview directory.
    func appendPreviewAudio(_ track: Track, from stagingDirectory: URL) throws -> LibraryAppendResult {
        guard indexIsReadable else { throw LibraryError.corruptIndex }
        let expected = directory.appendingPathComponent(".import-preview").standardizedFileURL.path + "/"
        guard stagingDirectory.standardizedFileURL.path.hasPrefix(expected), !track.isDemo, track.remote == nil,
              Self.isSafeBasename(track.audioFile), track.artworkFile.map(Self.isSafeBasename) ?? true else {
            throw LibraryError.invalidPath
        }
        let existing = try committedTracks ?? restore()
        if let hash = track.contentHash, hash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
           let duplicate = existing.first(where: { !$0.isDemo && $0.contentHash == hash }) {
            return LibraryAppendResult(track: duplicate, tracks: existing, reused: true)
        }
        guard !existing.contains(where: { $0.id == track.id }) else { throw LibraryError.corruptIndex }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try ImportPromotionJournal.begin(directory: directory, track: track)
        var moved: [URL] = []
        do {
            for filename in [track.audioFile, track.artworkFile].compactMap({ $0 }) {
                let source = stagingDirectory.appendingPathComponent(filename)
                let target = directory.appendingPathComponent(filename)
                guard !FileManager.default.fileExists(atPath: target.path) else { throw LibraryError.invalidPath }
                try FileManager.default.moveItem(at: source, to: target)
                moved.append(target)
            }
            var imported = track
            imported.addedAt = Date()
            let next = existing + [imported]
            try save(next)
            // Once the index committed, cleanup failure must not turn a saved song into an apparent failure.
            // A leftover journal is harmless: validated restore preserves this committed TrackID's assets.
            try? ImportPromotionJournal.complete(directory: directory, trackID: track.id)
            return LibraryAppendResult(track: imported, tracks: next, reused: false)
        } catch {
            for url in moved { try? FileManager.default.removeItem(at: url) }
            // Retaining a journal after failed cleanup permits a later verified restore to remove the orphan.
            if moved.allSatisfy({ !FileManager.default.fileExists(atPath: $0.path) }) {
                try? ImportPromotionJournal.complete(directory: directory, trackID: track.id)
            }
            throw error
        }
    }

    func discover(_ urls: [URL], folders: Bool) throws -> [AudioImportSource] {
        try AudioImportAccess.discover(urls, folders: folders)
    }

    func discoverPreview(_ urls: [URL], folders: Bool) throws -> [AudioImportSource] {
        try AudioImportAccess.discover(urls, folders: folders, companions: true)
    }

    func stageAudio(from source: URL, scope: URL? = nil, existing: [Track] = []) async throws -> Track {
        guard indexIsReadable else { throw LibraryError.corruptIndex }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let suffix = source.pathExtension.isEmpty ? "audio" : source.pathExtension
        let filename = id + "." + suffix
        let destination = directory.appendingPathComponent(filename)
        do {
            try AudioImportAccess.copy(source, scope: scope ?? source, to: destination)
            let hash = try AudioImportAccess.fingerprint(destination)
            guard !existing.contains(where: { !$0.isDemo && $0.contentHash == hash }) else { throw LibraryError.duplicateAudio }
            var track = try await MetadataReader.read(destination, id: id,
                                                      originalName: source.deletingPathExtension().lastPathComponent,
                                                      directory: directory)
            track.contentHash = hash
            track.addedAt = Date()
            return track
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    func discardStaged(_ track: Track) {
        // Roll back only files staged by this import, never the user's picker source.
        for filename in [track.audioFile, track.artworkFile].compactMap({ $0 }) where Self.isSafeBasename(filename) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
        }
    }

    func readLyrics(from source: URL) throws -> String {
        guard ["lrc", "txt"].contains(source.pathExtension.lowercased()) else { throw LibraryError.invalidLyrics }
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= 1_048_576 else { throw LibraryError.invalidLyrics }
        let data = try Data(contentsOf: source)
        let decoded = try LyricTextDecoder.decode(data)
        let document = try LyricDocument.parse(decoded.text,
            format: source.pathExtension.lowercased() == "lrc" ? .lrc : .plain)
        return try document.canonicalText
    }
}

