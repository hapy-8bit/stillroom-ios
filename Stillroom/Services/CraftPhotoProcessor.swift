import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

struct CraftPhotoCrop: Equatable, Sendable {
    var zoom: CGFloat = 1
    /// Translation as a fraction of the square viewport. This survives layout and orientation changes.
    var offset: CGSize = .zero
}

/// ImageIO creates these immutable sampled pixels before crossing back to the main actor.
struct CraftPhotoSource: @unchecked Sendable {
    let image: CGImage
    var size: CGSize { CGSize(width: image.width, height: image.height) }
}

struct CraftPhotoResult: @unchecked Sendable {
    let jpeg: Data
    let image: UIImage
}

enum CraftPhotoError: LocalizedError, Equatable {
    case unavailable, invalidImage, unsupportedImage, tooLarge, invalidCrop, processing

    var errorDescription: String? {
        switch self {
        case .unavailable: return "照片尚未读取完成，请检查网络后重新选择。"
        case .invalidImage: return "这张照片无法读取，请选择完整的照片。"
        case .unsupportedImage: return "请选择 HEIC、JPEG 或 PNG 照片。"
        case .tooLarge: return "照片不能超过 16 MB 或一亿像素，请缩小后再选。"
        case .invalidCrop: return "裁切范围无效，请重置后再试。"
        case .processing: return "照片处理没有完成，原照片未改动，请重试。"
        }
    }
}

enum CraftPhotoProcessor {
    static let maximumBytes = 16 * 1_024 * 1_024

    /// No file access: the caller supplies bytes granted by the system picker. Pixel dimensions are
    /// checked before decoding; ImageIO bakes all eight EXIF orientations into a bounded thumbnail.
    static func prepare(_ bytes: Data) throws -> CraftPhotoSource {
        guard !bytes.isEmpty else { throw CraftPhotoError.invalidImage }
        guard bytes.count <= maximumBytes else { throw CraftPhotoError.tooLarge }
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let identifier = CGImageSourceGetType(source) as String?,
              let type = UTType(identifier) else { throw CraftPhotoError.invalidImage }
        guard type.conforms(to: .jpeg) || type.conforms(to: .png) ||
              ["public.heic", "public.heif"].contains(identifier) else { throw CraftPhotoError.unsupportedImage }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else { throw CraftPhotoError.invalidImage }
        try validatePixelDimensions(width: width.doubleValue, height: height.doubleValue)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_536
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CraftPhotoError.processing
        }
        try Task.checkCancellation()
        return CraftPhotoSource(image: image)
    }

    /// Metadata dimensions are source pixels, not layout points. Validate this decode precondition
    /// independently of ImageIO: malformed containers can fail before they expose any metadata.
    static func validatePixelDimensions(width: Double, height: Double) throws {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { throw CraftPhotoError.invalidImage }
        guard width * height <= 100_000_000 else { throw CraftPhotoError.tooLarge }
    }

    static func constrained(_ crop: CraftPhotoCrop, imageSize: CGSize) -> CraftPhotoCrop {
        guard imageSize.width.isFinite, imageSize.height.isFinite,
              imageSize.width > 0, imageSize.height > 0 else { return CraftPhotoCrop() }
        let zoom = crop.zoom.isFinite ? min(6, max(1, crop.zoom)) : 1
        let factor = zoom / min(imageSize.width, imageSize.height)
        let horizontal = max(0, (imageSize.width * factor - 1) / 2)
        let vertical = max(0, (imageSize.height * factor - 1) / 2)
        return CraftPhotoCrop(zoom: zoom, offset: CGSize(
            width: crop.offset.width.isFinite ? min(horizontal, max(-horizontal, crop.offset.width)) : 0,
            height: crop.offset.height.isFinite ? min(vertical, max(-vertical, crop.offset.height)) : 0))
    }

    /// The CGImage crop uses top-left oriented pixel coordinates, matching UIImage(.up) in the
    /// viewport. Dragging the image right selects pixels further left. Zoom never reveals blank edges.
    static func pixelRectangle(_ crop: CraftPhotoCrop, imageSize: CGSize) throws -> CGRect {
        guard imageSize.width.isFinite, imageSize.height.isFinite, imageSize.width > 0, imageSize.height > 0,
              crop.zoom.isFinite, crop.offset.width.isFinite, crop.offset.height.isFinite else {
            throw CraftPhotoError.invalidCrop
        }
        let value = constrained(crop, imageSize: imageSize)
        let side = min(imageSize.width, imageSize.height) / value.zoom
        return CGRect(x: max(0, min(imageSize.width - side, (imageSize.width - side) / 2 - value.offset.width * side)),
                      y: max(0, min(imageSize.height - side, (imageSize.height - side) / 2 - value.offset.height * side)),
                      width: side, height: side)
    }

    /// JPEG is encoded from fresh RGB pixels, with no source metadata or location fields. The
    /// returned preview is decoded from those exact JPEG bytes; callers persist only after Save.
    static func finish(_ source: CraftPhotoSource, crop: CraftPhotoCrop) throws -> CraftPhotoResult {
        try Task.checkCancellation()
        let rectangle = try pixelRectangle(crop, imageSize: source.size)
        guard let selected = source.image.cropping(to: rectangle) else { throw CraftPhotoError.processing }
        let side = min(1_024, selected.width, selected.height)
        guard side > 0, let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CraftPhotoError.processing }
        context.setFillColor(CGColor(gray: 0.965, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.interpolationQuality = .high
        context.draw(selected, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let rendered = context.makeImage() else { throw CraftPhotoError.processing }
        let bytes = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CraftPhotoError.processing
        }
        CGImageDestinationAddImage(destination, rendered, [kCGImageDestinationLossyCompressionQuality: 0.88,
                                                         kCGImagePropertyOrientation: 1] as CFDictionary)
        guard CGImageDestinationFinalize(destination), let preview = UIImage(data: bytes as Data) else {
            throw CraftPhotoError.processing
        }
        try Task.checkCancellation()
        return CraftPhotoResult(jpeg: bytes as Data, image: preview)
    }
}
