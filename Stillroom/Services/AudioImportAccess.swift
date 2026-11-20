import Foundation
import CryptoKit
import UniformTypeIdentifiers

enum AudioImportAccess {
    static func discover(_ roots: [URL], folders: Bool, companions: Bool = false) throws -> [AudioImportSource] {
        guard folders else { return roots.map { AudioImportSource(url: $0, scope: $0) } }
        var sources: [AudioImportSource] = []
        for root in roots {
            let accessed = root.startAccessingSecurityScopedResource()
            defer { if accessed { root.stopAccessingSecurityScopedResource() } }
            try coordinate(root) { readable in
                var enumerationError: Error?
                guard let enumerator = FileManager.default.enumerator(
                    at: readable, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants],
                    errorHandler: { _, error in enumerationError = error; return false }
                ) else { throw CocoaError(.fileReadUnknown) }
                for case let url as URL in enumerator {
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    // Never follow aliases/symlinks outside the user's selected directory.
                    guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                    let suffix = url.pathExtension.lowercased()
                    let audio = UTType(filenameExtension: suffix)?.conforms(to: .audio) == true
                    let companion = companions && ["lrc", "txt", "jpg", "jpeg", "png"].contains(suffix)
                    if audio || companion || ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac", "alac"].contains(suffix) {
                        sources.append(AudioImportSource(url: url, scope: root))
                    }
                }
                if let enumerationError { throw enumerationError }
            }
        }
        return sources.sorted { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
    }

    static func copy(_ source: URL, scope: URL, to destination: URL) throws {
        let accessed = scope.startAccessingSecurityScopedResource()
        defer { if accessed { scope.stopAccessingSecurityScopedResource() } }
        // Coordination lets iCloud/Files providers materialize the file before reading its bytes.
        try coordinate(source) { readable in
            try FileManager.default.copyItem(at: readable, to: destination)
        }
    }

    static func fingerprint(_ url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hash = SHA256()
        // Bound memory use for lossless albums; never load the whole audio file into Data.
        while let chunk = try file.read(upToCount: 1_048_576), !chunk.isEmpty { hash.update(data: chunk) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func coordinate(_ url: URL, read: (URL) throws -> Void) throws {
        var coordinationError: NSError?
        var readError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
            do { try read(readable) } catch { readError = error }
        }
        if let coordinationError { throw coordinationError }
        if let readError { throw readError }
    }
}
