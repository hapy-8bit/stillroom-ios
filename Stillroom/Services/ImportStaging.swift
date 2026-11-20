import Foundation
import CryptoKit

struct PreparedImportItem: Sendable {
    let id: UUID
    let name: String
    let kind: ImportMediaKind
    var bytes: Int64 = 0
    var retainedFailedBytes: Int64 = 0
    var hash = ""
    var track: Track?
    var lyricText = ""
    var lyricOriginal = ""
    var coverURL: URL?
    var imageData: Data?
    var detail = ""
    var error = ""
    /// Ephemeral equality token only, never an original absolute path or index field.
    var sourceDirectoryID = ""
}

/// Scoped input lives only inside this adapter. Cancelling or closing a preview never changes originals.
actor ImportStaging {
    let directory: URL
    private var owned = Set<UUID>()

    init(libraryDirectory: URL) {
        directory = libraryDirectory.appendingPathComponent(".import-preview", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    func stage(_ source: AudioImportSource, remainingBytes: Int64 = 1_073_741_824) async -> PreparedImportItem {
        let id = UUID()
        let name = source.url.lastPathComponent
        let kind = ImportMediaKind.classify(name)
        var item = PreparedImportItem(id: id, name: name, kind: kind)
        let directoryPath = source.url.deletingLastPathComponent().standardizedFileURL.path
        item.sourceDirectoryID = SHA256.hash(data: Data(directoryPath.utf8)).map { String(format: "%02x", $0) }.joined()
        let destination = directory.appendingPathComponent(id.uuidString + "." + source.url.pathExtension.lowercased())
        do {
            guard kind != .unsupported else { throw ImportPreviewError.invalidType }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let access = source.scope.startAccessingSecurityScopedResource()
            defer { if access { source.scope.stopAccessingSecurityScopedResource() } }
            let size = try source.url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            let limit = kind == .audio ? 512 * 1_048_576 : kind == .lyrics ? 1_048_576 : 16 * 1_048_576
            guard size > 0, size <= limit else { throw ImportPreviewError.emptyOrLarge }
            guard Int64(size) <= remainingBytes else { throw ImportPreviewError.batchTooLarge }
            item.bytes = Int64(size)
            try AudioImportAccess.copy(source.url, scope: source.scope, to: destination)
            owned.insert(id)
            let actual = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard actual > 0, actual <= limit else { throw ImportPreviewError.emptyOrLarge }
            guard Int64(actual) <= remainingBytes else { throw ImportPreviewError.batchTooLarge }
            item.bytes = Int64(actual)
            if kind == .audio {
                item.hash = try AudioImportAccess.fingerprint(destination)
                let metadata = try await MetadataReader.readForPreview(destination, id: id.uuidString,
                    originalName: source.url.deletingPathExtension().lastPathComponent, directory: directory)
                var track = metadata.track
                track.contentHash = item.hash
                item.track = track
                item.detail = metadata.artworkNotice ?? (track.artworkFile == nil ? "" : "已读取内嵌专辑封面")
            } else if kind == .lyrics {
                let decoded = try LyricTextDecoder.decode(Data(contentsOf: destination))
                let document = try LyricDocument.parse(decoded.text,
                    format: source.url.pathExtension.lowercased() == "lrc" ? .lrc : .plain)
                item.lyricOriginal = document.originalText
                item.lyricText = try document.canonicalText
                item.detail = decoded.encoding.rawValue.uppercased() + " · 预览为实际播放时间，原稿另存"
                let warnings = document.warnings.map(\.message)
                if !warnings.isEmpty { item.detail += " · " + warnings.joined(separator: "；") }
            } else {
                let cover = directory.appendingPathComponent(id.uuidString + ".normalized.jpg")
                try CoverImportAdapter.normalize(source: destination, destination: cover)
                item.coverURL = cover
                item.imageData = try Data(contentsOf: cover)
                item.detail = "方向已校正 · 居中方形JPEG · 原图保留"
            }
        } catch {
            item.error = error.localizedDescription
            // Invalid media must not keep a large copied file alive until the user closes the preview.
            // Every candidate below belongs to this freshly generated UUID, never to a selected source.
            let leftovers = [destination, directory.appendingPathComponent(id.uuidString + ".jpg"),
                             directory.appendingPathComponent(id.uuidString + ".normalized.jpg")]
            do {
                for path in leftovers where FileManager.default.fileExists(atPath: path.path) {
                    try FileManager.default.removeItem(at: path)
                }
            } catch {
                item.retainedFailedBytes = item.bytes
                item.error += " 临时文件尚未完全清理，请关闭预览后重试。"
            }
        }
        return item
    }

    func cleanup() throws {
        // This UUID directory contains only this coordinator's previews, never committed library assets.
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
        owned.removeAll()
    }
}
