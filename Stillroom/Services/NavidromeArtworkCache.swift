import Foundation
import CryptoKit
import ImageIO

actor NavidromeArtworkCache {
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stillroom/NavidromeArt", isDirectory: true)
    }

    func read(key: String) throws -> Data? {
        let file = location(key)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let data = try Data(contentsOf: file)
        guard Self.isImage(data) else { return nil }
        return data
    }

    func save(_ data: Data, key: String) throws {
        guard Self.isImage(data) else { throw NavidromeError.invalidResponse }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: location(key), options: .atomic)
    }

    private func location(_ key: String) -> URL {
        let name = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name + ".image")
    }

    private static func isImage(_ data: Data) -> Bool {
        guard !data.isEmpty, data.count <= 4 * 1_024 * 1_024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return false }
        return width > 0 && height > 0 && width <= 4_096 && height <= 4_096
    }
}
