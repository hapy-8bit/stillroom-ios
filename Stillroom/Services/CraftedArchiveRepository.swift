import Foundation
import Darwin
import ImageIO
import UniformTypeIdentifiers

struct CraftedAssetLoad: Sendable {
    var data: [String: Data] = [:]
    var unavailable: [String] = []
}

/// The JSON document owns references, not source music. All mutations are serialized without an await
/// between writing a new immutable photo and the atomic document commit. A failed commit keeps old media.
actor CraftedArchiveRepository {
    typealias IndexWriter = @Sendable (Data, URL) throws -> Void
    private let directory: URL
    private let indexWriter: IndexWriter
    private var state = CraftedArchive()
    private var ready = false
    private var indexURL: URL { directory.appendingPathComponent("crafted-archive.json") }

    /// Injected writers must throw before replacing the document; used to verify the actual commit boundary.
    init(directory: URL, indexWriter: @escaping IndexWriter = { try CraftedArchiveRepository.writeIndex($0, to: $1) }) {
        self.directory = directory
        self.indexWriter = indexWriter
    }

    func restore() throws -> CraftedArchive {
        ready = false
        do {
            guard directory.isFileURL else { throw CraftedArchiveError.corruptArchive }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let next: CraftedArchive
            if FileManager.default.fileExists(atPath: indexURL.path) {
                next = try JSONDecoder().decode(CraftedArchive.self, from: Self.read(indexURL, limit: 20_971_520))
                try next.validate()
            } else { next = CraftedArchive() }
            state = next
            ready = true
            return next
        } catch { throw CraftedArchiveError.corruptArchive }
    }

    /// Missing pictures are a repairable media problem. Their records and text remain visible and saved;
    /// only malformed document structure fails the entire archive closed.
    func loadAssets() throws -> CraftedAssetLoad {
        try requireReady()
        let names = Set(state.records.compactMap(\.coverAsset) + state.memories.compactMap(\.photoAsset))
        var result = CraftedAssetLoad()
        for name in names.sorted() {
            do {
                let bytes = try Self.read(directory.appendingPathComponent(name), limit: 16_777_216)
                try Self.validateJPEG(bytes)
                result.data[name] = bytes
            } catch { result.unavailable.append(name) }
        }
        return result
    }

    /// A playing edition may still reference an immutable photo replaced in the editable archive.
    /// Only app-owned prepared JPEG basenames are accepted; this never changes the current document.
    func loadRetainedAsset(_ name: String) throws -> Data {
        try requireReady()
        guard CraftedArchive.validAsset(name) else { throw CraftedArchiveError.invalidPhoto }
        do {
            let bytes = try Self.read(directory.appendingPathComponent(name), limit: 16_777_216)
            try Self.validateJPEG(bytes)
            return bytes
        } catch { throw CraftedArchiveError.invalidPhoto }
    }

    func saveRecord(_ input: CraftedRecord, photoJPEG: Data? = nil) throws -> CraftedArchive {
        try requireReady()
        var value = input
        let original = state.records.first { $0.id == input.id }
        // Collection is the person's intent for this record. Completion belongs to one printed edition:
        // an unchanged editor preserves a later completion, while changed content starts uncompleted.
        value.createdAt = original?.createdAt ?? input.createdAt
        value.collectedAt = original?.collectedAt
        value.updatedAt = Date()
        let newAsset = photoJPEG == nil ? nil : freshAssetName()
        if let newAsset { value.coverAsset = newAsset }
        let sameEdition = original?.hasSameEdition(as: value) == true
        value.completedAt = sameEdition ? original?.completedAt : nil
        try value.validate()
        if photoJPEG == nil, value.coverAsset != original?.coverAsset { try validateExistingAsset(value.coverAsset) }
        var next = state
        next.records.removeAll { $0.id == value.id }
        next.records.append(value)
        return try commit(next, photoJPEG: photoJPEG, newAsset: newAsset)
    }

    func saveMemory(_ input: SongMemory, photoJPEG: Data? = nil) throws -> CraftedArchive {
        try requireReady()
        var value = input
        let original = state.memories.first { $0.id == input.id }
        guard original == nil || original?.trackID == input.trackID else { throw CraftedArchiveError.invalidMemory }
        value.createdAt = original?.createdAt ?? input.createdAt
        value.updatedAt = Date()
        let newAsset = photoJPEG == nil ? nil : freshAssetName()
        if let newAsset { value.photoAsset = newAsset }
        try value.validate()
        if photoJPEG == nil, value.photoAsset != original?.photoAsset { try validateExistingAsset(value.photoAsset) }
        var next = state
        next.memories.removeAll { $0.id == value.id }
        next.memories.append(value)
        return try commit(next, photoJPEG: photoJPEG, newAsset: newAsset)
    }

    func collect(_ id: String) throws -> CraftedArchive {
        try requireReady()
        guard let index = state.records.firstIndex(where: { $0.id == id }), !state.records[index].isDraft else {
            throw CraftedArchiveError.missingTarget
        }
        guard state.records[index].collectedAt == nil else { return state }
        var next = state
        next.records[index].collectedAt = Date()
        next.records[index].updatedAt = Date()
        return try commit(next)
    }

    func markCompleted(_ id: String) throws -> CraftedArchive {
        try requireReady()
        guard let index = state.records.firstIndex(where: { $0.id == id }), !state.records[index].isDraft else {
            throw CraftedArchiveError.missingTarget
        }
        var next = state
        next.records[index].completedAt = Date()
        next.records[index].updatedAt = Date()
        return try commit(next)
    }

    func discardDraft(_ id: String) throws -> CraftedArchive {
        try requireReady()
        guard let original = state.records.first(where: { $0.id == id }) else { return state }
        guard original.isDraft else { throw CraftedArchiveError.invalidRecord }
        var next = state
        next.records.removeAll { $0.id == id }
        return try commit(next)
    }

    private func requireReady() throws {
        guard ready else { throw CraftedArchiveError.notReady }
    }

    private func validateExistingAsset(_ name: String?) throws {
        guard let name else { return }
        guard CraftedArchive.validAsset(name) else { throw CraftedArchiveError.invalidPhoto }
        do { try Self.validateJPEG(Self.read(directory.appendingPathComponent(name), limit: 16_777_216)) }
        catch { throw CraftedArchiveError.invalidPhoto }
    }

    private func freshAssetName() -> String {
        var name: String
        repeat { name = "craft-" + UUID().uuidString + ".jpg" }
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)
        return name
    }

    private func commit(_ next: CraftedArchive, photoJPEG: Data? = nil, newAsset: String? = nil) throws -> CraftedArchive {
        try next.validate()
        if let photoJPEG { try Self.validateJPEG(photoJPEG) }
        let document = try JSONEncoder().encode(next)
        guard document.count <= 20_971_520 else { throw CraftedArchiveError.corruptArchive }
        var attemptedNewAsset = false
        do {
            if let photoJPEG, let newAsset {
                attemptedNewAsset = true
                try Self.writeAsset(photoJPEG, to: directory.appendingPathComponent(newAsset))
            }
            try indexWriter(document, indexURL)
        } catch {
            var cleanupPending = false
            if attemptedNewAsset, let newAsset,
               FileManager.default.fileExists(atPath: directory.appendingPathComponent(newAsset).path) {
                do { try FileManager.default.removeItem(at: directory.appendingPathComponent(newAsset)) }
                catch { cleanupPending = true }
            }
            throw CraftedArchiveError.saveFailed(cleanupPending: cleanupPending)
        }
        state = next
        // Older photos stay untouched so failed or stale edits can never destroy a previously saved memory.
        return next
    }

    private nonisolated static func validateJPEG(_ data: Data) throws {
        guard data.count > 4, data.count <= 16_777_216,
              data.starts(with: [255, 216]), data.suffix(2).elementsEqual([255, 217]),
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetType(source) as String? == UTType.jpeg.identifier,
              CGImageSourceGetCount(source) == 1,
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = metadata[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = metadata[kCGImagePropertyPixelHeight] as? NSNumber,
              width.intValue > 0, height.intValue > 0, width.intValue <= 2_048, height.intValue <= 2_048,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else { throw CraftedArchiveError.invalidPhoto }
    }

    private nonisolated static func read(_ url: URL, limit: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while true {
            let part = try handle.read(upToCount: min(65_536, limit + 1 - data.count)) ?? Data()
            if part.isEmpty { return data }
            data.append(part)
            guard data.count <= limit else { throw CraftedArchiveError.corruptArchive }
        }
    }

    private nonisolated static func writeAsset(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .withoutOverwriting)
        let handle = try FileHandle(forWritingTo: url)
        do { try handle.synchronize(); try handle.close() }
        catch { try? handle.close(); throw error }
    }

    private nonisolated static func writeIndex(_ data: Data, to url: URL) throws {
        let pending = url.deletingLastPathComponent().appendingPathComponent(".craft-" + UUID().uuidString + ".pending")
        defer { if FileManager.default.fileExists(atPath: pending.path) { try? FileManager.default.removeItem(at: pending) } }
        try writeAsset(data, to: pending)
        // The flushed temporary file is renamed in the same directory; no fallible asset work follows.
        let result = pending.withUnsafeFileSystemRepresentation { source in
            url.withUnsafeFileSystemRepresentation { destination in Darwin.rename(source!, destination!) }
        }
        guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
}
