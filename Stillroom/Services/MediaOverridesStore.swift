import Foundation
import Darwin

enum MediaOverridesError: Error, LocalizedError {
    case notReady, corruptIndex, invalidTarget, invalidLyrics, invalidCover, saveFailed(cleanupPending: Bool)
    var errorDescription: String? {
        switch self {
        case .notReady: return "自定义资料尚未读取完成，请稍后重试。"
        case .corruptIndex: return "自定义歌词或封面索引无法完整读取，原资料已保留，请勿覆盖后重试。"
        case .invalidTarget: return "歌曲或专辑目标不可用，请重新打开资料预览。"
        case .invalidLyrics: return "歌词内容无法保存，请重新预览完整歌词。"
        case .invalidCover: return "封面不是已规范化的 JPEG，请重新选择图片。"
        case .saveFailed(let cleanup):
            return "资料未能保存，旧资料已保留，可以重试。" + (cleanup ? " 部分暂存资料未能清理。" : "")
        }
    }
}

private enum MediaOverrideKind: String, Codable, Sendable { case lyrics, trackCover = "track-cover", albumCover = "album-cover" }
private struct MediaOverrideEntry: Codable, Sendable {
    let kind: MediaOverrideKind
    let targetID: String
    let asset: String
    var original: String? = nil
}
private struct MediaOverridesIndex: Codable { var version = 1; var entries: [MediaOverrideEntry] = [] }

/// Durable user media never shares the replaceable embedded/server layer. Fixed target strings are captured
/// by the caller; this actor never reads a current-player selection and never awaits midway through a commit.
actor MediaOverridesStore {
    typealias IndexWriter = @Sendable (Data, URL) throws -> Void
    private let directory: URL
    private let indexWriter: IndexWriter
    private var state = MediaOverridesIndex()
    private var lyrics: [String: String] = [:]
    private var ready = false

    /// IndexWriter is the atomic commit boundary; an injected writer must throw before replacing the index.
    init(directory: URL, indexWriter: @escaping IndexWriter = { try MediaOverridesStore.writeIndex($0, to: $1) }) {
        self.directory = directory
        self.indexWriter = indexWriter
    }

    func restore() throws {
        ready = false
        do {
            guard directory.isFileURL else { throw MediaOverridesError.corruptIndex }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let path = directory.appendingPathComponent("media-overrides.json")
            guard FileManager.default.fileExists(atPath: path.path) else {
                state = MediaOverridesIndex(); lyrics = [:]; ready = true; return
            }
            let parsed = try JSONDecoder().decode(MediaOverridesIndex.self, from: Self.read(path, limit: 4_194_304))
            guard parsed.version == 1, parsed.entries.count <= 20_000 else { throw MediaOverridesError.corruptIndex }
            var keys = Set<String>(), assets = Set<String>(), decoded: [String: String] = [:]
            for entry in parsed.entries {
                guard Self.validTarget(entry.targetID), keys.insert(entry.kind.rawValue + "\0" + entry.targetID).inserted,
                      assets.insert(entry.asset).inserted else { throw MediaOverridesError.corruptIndex }
                if entry.kind == .lyrics {
                    guard Self.validAsset(entry.asset, extension: "lrc"), let original = entry.original,
                          Self.validAsset(original, extension: "original"), assets.insert(original).inserted,
                          let text = String(data: try Self.read(directory.appendingPathComponent(entry.asset), limit: 2_097_152), encoding: .utf8),
                          let raw = String(data: try Self.read(directory.appendingPathComponent(original), limit: 2_097_152), encoding: .utf8),
                          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MediaOverridesError.corruptIndex }
                    decoded[entry.asset] = text
                } else {
                    guard Self.validAsset(entry.asset, extension: "jpg"), entry.original == nil else { throw MediaOverridesError.corruptIndex }
                    try Self.validateJPEG(Self.read(directory.appendingPathComponent(entry.asset), limit: 16_777_216))
                }
            }
            state = parsed; lyrics = decoded; ready = true
        } catch { throw MediaOverridesError.corruptIndex }
    }

    func apply(_ tracks: [Track]) throws -> [Track] { try tracks.map { try apply($0) } }

    func apply(_ track: Track) throws -> Track {
        guard ready else { throw MediaOverridesError.notReady }
        var result = Self.automaticTrack(track)
        result.automaticMedia = AutomaticMediaSnapshot(artworkFile: result.artworkFile, lyrics: result.lyrics, isLyricDemo: result.isLyricDemo)
        let album = entry(.albumCover, target: result.albumKey)
        let single = entry(.trackCover, target: result.id)
        // A song-only image affects its label/row/system image, never the album's representative sleeve.
        result.albumArtworkFile = album?.asset
        result.artworkFile = single?.asset ?? album?.asset ?? result.artworkFile
        if let lyric = entry(.lyrics, target: result.id), let text = lyrics[lyric.asset] {
            result.lyrics = text; result.isLyricDemo = false
        }
        return result
    }

    nonisolated static func automaticTrack(_ track: Track) -> Track {
        var result = track
        if let original = track.automaticMedia {
            result.artworkFile = original.artworkFile; result.lyrics = original.lyrics; result.isLyricDemo = original.isLyricDemo
        }
        result.automaticMedia = nil; result.albumArtworkFile = nil
        return result
    }

    func saveLyrics(trackID: String, canonical: String, original: String) throws {
        try requireReady(trackID)
        let text = Data(canonical.utf8), raw = Data(original.utf8)
        guard !canonical.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.count <= 2_097_152, raw.count <= 2_097_152 else { throw MediaOverridesError.invalidLyrics }
        let id = "media-" + UUID().uuidString, asset = id + ".lrc", source = id + ".original"
        do {
            try Self.writeAsset(text, to: directory.appendingPathComponent(asset))
            try Self.writeAsset(raw, to: directory.appendingPathComponent(source))
            try commit(MediaOverrideEntry(kind: .lyrics, targetID: trackID, asset: asset, original: source))
            lyrics[asset] = canonical
        } catch { throw MediaOverridesError.saveFailed(cleanupPending: cleanup([asset, source])) }
    }

    /// normalizedURL is an app-owned result of CoverImportAdapter, never an original picker URI.
    func saveCover(targetID: String, normalizedURL: URL, album: Bool) throws {
        try requireReady(targetID)
        guard normalizedURL.isFileURL else { throw MediaOverridesError.invalidCover }
        let data: Data
        do { data = try Self.read(normalizedURL, limit: 16_777_216); try Self.validateJPEG(data) }
        catch { throw MediaOverridesError.invalidCover }
        let asset = "media-" + UUID().uuidString + ".jpg"
        do {
            try Self.writeAsset(data, to: directory.appendingPathComponent(asset))
            try commit(MediaOverrideEntry(kind: album ? .albumCover : .trackCover, targetID: targetID, asset: asset))
        } catch { throw MediaOverridesError.saveFailed(cleanupPending: cleanup([asset])) }
    }

    func removeLyrics(trackID: String) throws { try remove(.lyrics, target: trackID) }
    func removeCover(targetID: String, album: Bool) throws { try remove(album ? .albumCover : .trackCover, target: targetID) }

    private func entry(_ kind: MediaOverrideKind, target: String) -> MediaOverrideEntry? {
        state.entries.first { $0.kind == kind && $0.targetID == target }
    }
    private func requireReady(_ target: String) throws {
        guard ready else { throw MediaOverridesError.notReady }
        guard Self.validTarget(target) else { throw MediaOverridesError.invalidTarget }
    }
    private func commit(_ value: MediaOverrideEntry) throws {
        var next = state
        next.entries.removeAll { $0.kind == value.kind && $0.targetID == value.targetID }
        next.entries.append(value)
        try indexWriter(JSONEncoder().encode(next), directory.appendingPathComponent("media-overrides.json"))
        state = next
        // Older assets remain durable until a separate verified cleanup; failed edits never delete old user media.
    }
    private func remove(_ kind: MediaOverrideKind, target: String) throws {
        try requireReady(target)
        guard entry(kind, target: target) != nil else { return }
        var next = state; next.entries.removeAll { $0.kind == kind && $0.targetID == target }
        do { try indexWriter(JSONEncoder().encode(next), directory.appendingPathComponent("media-overrides.json")) }
        catch { throw MediaOverridesError.saveFailed(cleanupPending: false) }
        state = next
    }
    private func cleanup(_ names: [String]) -> Bool {
        var failed = false
        for name in names {
            let url = directory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do { try FileManager.default.removeItem(at: url) } catch { failed = true }
        }
        return failed
    }
    private nonisolated static func validTarget(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 4_096 && !value.contains("\0")
    }
    private nonisolated static func validAsset(_ value: String, extension suffix: String) -> Bool {
        guard value.hasPrefix("media-"), value.hasSuffix("." + suffix) else { return false }
        let id = String(value.dropFirst(6).dropLast(suffix.count + 1))
        return UUID(uuidString: id) != nil && !value.contains("/") && !value.contains("\\")
    }
    private nonisolated static func validateJPEG(_ data: Data) throws {
        guard data.count >= 4, data.starts(with: [255, 216]), data.suffix(2).elementsEqual([255, 217]) else { throw MediaOverridesError.invalidCover }
    }
    private nonisolated static func read(_ path: URL, limit: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: path)
        defer { try? handle.close() }
        var result = Data()
        while true {
            let part = try handle.read(upToCount: min(65_536, limit + 1 - result.count)) ?? Data()
            if part.isEmpty { return result }
            result.append(part)
            guard result.count <= limit else { throw MediaOverridesError.corruptIndex }
        }
    }
    private nonisolated static func writeAsset(_ data: Data, to path: URL) throws {
        try data.write(to: path, options: .withoutOverwriting)
        let handle = try FileHandle(forWritingTo: path)
        do { try handle.synchronize(); try handle.close() }
        catch { try? handle.close(); throw error }
    }
    private nonisolated static func writeIndex(_ data: Data, to path: URL) throws {
        let pending = path.deletingLastPathComponent().appendingPathComponent(".media-index-" + UUID().uuidString + ".pending")
        defer { if FileManager.default.fileExists(atPath: pending.path) { try? FileManager.default.removeItem(at: pending) } }
        try writeAsset(data, to: pending)
        // Flush before rename. After this atomic commit point there is no fallible work that could roll back referenced assets.
        let result = pending.withUnsafeFileSystemRepresentation { source in
            path.withUnsafeFileSystemRepresentation { destination in Darwin.rename(source!, destination!) }
        }
        guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
}
