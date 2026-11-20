import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

enum CoverImportError: LocalizedError {
    case invalidImage, tooLarge, existingDestination, processing
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "请选择完整的 JPEG 或 PNG 图片。"
        case .tooLarge: return "封面不能超过16 MB或1亿像素，请缩小后再试。"
        case .existingDestination: return "封面暂存位置已存在，请重新选择。"
        case .processing: return "封面未能处理或保存，原图片未改动。"
        }
    }
}

enum CoverImportAdapter {
    /// Caller supplies an authorized staged file and a new app-owned destination. ImageIO bakes all
    /// eight EXIF orientations into sampled pixels; cropping uses those oriented pixel coordinates.
    static func normalize(source: URL, destination: URL) throws {
        guard source.isFileURL, destination.isFileURL,
              source.standardizedFileURL != destination.standardizedFileURL else { throw CoverImportError.invalidImage }
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw CoverImportError.existingDestination }
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 16 * 1_024 * 1_024 else { throw CoverImportError.tooLarge }
        let bytes = try Data(contentsOf: source, options: .mappedIfSafe)
        try normalize(data: bytes, destination: destination)
    }

    /// Embedded audio artwork uses the same bounded decode and orientation/
    /// square-crop boundary as a selected cover; compressed bytes are never
    /// decoded at their full source pixel size just to render a small sleeve.
    static func normalize(data bytes: Data, destination: URL) throws {
        guard destination.isFileURL else { throw CoverImportError.invalidImage }
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw CoverImportError.existingDestination }
        guard !bytes.isEmpty, bytes.count <= 16 * 1_024 * 1_024 else { throw CoverImportError.tooLarge }
        guard
              let input = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(input) as String?,
              [UTType.jpeg.identifier, UTType.png.identifier].contains(type),
              let properties = CGImageSourceCopyPropertiesAtIndex(input, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0,
              width.doubleValue * height.doubleValue <= 100_000_000 else { throw CoverImportError.invalidImage }
        let bound = min(1_536, max(width.intValue, height.intValue))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: bound
        ]
        guard let oriented = CGImageSourceCreateThumbnailAtIndex(input, 0, options as CFDictionary) else {
            throw CoverImportError.processing
        }
        let side = min(oriented.width, oriented.height)
        let rectangle = CGRect(x: (oriented.width - side) / 2, y: (oriented.height - side) / 2, width: side, height: side)
        guard side > 0, let crop = oriented.cropping(to: rectangle) else { throw CoverImportError.processing }
        let outputSide = min(1_024, side)
        guard let context = CGContext(data: nil, width: outputSide, height: outputSide, bitsPerComponent: 8,
                                      bytesPerRow: outputSide * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CoverImportError.processing }
        // JPEG has no alpha. Preview this neutral backing as part of the actual saved result.
        context.setFillColor(CGColor(gray: 0.965, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: outputSide, height: outputSide))
        context.interpolationQuality = .high
        context.draw(crop, in: CGRect(x: 0, y: 0, width: outputSide, height: outputSide))
        guard let rendered = context.makeImage() else { throw CoverImportError.processing }
        let encoded = NSMutableData()
        guard let encoder = CGImageDestinationCreateWithData(encoded, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CoverImportError.processing
        }
        CGImageDestinationAddImage(encoder, rendered, [kCGImageDestinationLossyCompressionQuality: 0.85,
                                                      kCGImagePropertyOrientation: 1] as CFDictionary)
        guard CGImageDestinationFinalize(encoder), encoded.length > 0 else { throw CoverImportError.processing }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (encoded as Data).write(to: destination, options: .atomic)
    }
}
