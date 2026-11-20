import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Stillroom

final class CraftPhotoProcessorTests: XCTestCase {
    func testCropCoordinatesFollowDraggedImageAndStayInsideEveryEdge() throws {
        let wide = CGSize(width: 200, height: 100)
        XCTAssertEqual(try CraftPhotoProcessor.pixelRectangle(CraftPhotoCrop(), imageSize: wide),
                       CGRect(x: 50, y: 0, width: 100, height: 100))
        let left = try CraftPhotoProcessor.pixelRectangle(CraftPhotoCrop(zoom: 2, offset: CGSize(width: 10_000, height: 10_000)), imageSize: wide)
        XCTAssertEqual(left, CGRect(x: 0, y: 0, width: 50, height: 50))
        let right = try CraftPhotoProcessor.pixelRectangle(CraftPhotoCrop(zoom: 2, offset: CGSize(width: -10_000, height: -10_000)), imageSize: wide)
        XCTAssertEqual(right, CGRect(x: 150, y: 50, width: 50, height: 50))
        let tall = try CraftPhotoProcessor.pixelRectangle(CraftPhotoCrop(), imageSize: CGSize(width: 100, height: 200))
        XCTAssertEqual(tall, CGRect(x: 0, y: 50, width: 100, height: 100))
        XCTAssertThrowsError(try CraftPhotoProcessor.pixelRectangle(CraftPhotoCrop(zoom: .nan), imageSize: wide))
        XCTAssertThrowsError(try CraftPhotoProcessor.pixelRectangle(CraftPhotoCrop(), imageSize: .zero))
    }

    func testPanSavesTheChosenHalfAndPreviewComesFromExactlyThoseJPEGBytes() throws {
        let original = picture(width: 200, height: 100, quadrants: false)
        let bytes = try encode(original, type: .png)
        let source = try CraftPhotoProcessor.prepare(bytes)
        let left = try CraftPhotoProcessor.finish(source, crop: CraftPhotoCrop(offset: CGSize(width: 0.5, height: 0)))
        let right = try CraftPhotoProcessor.finish(source, crop: CraftPhotoCrop(offset: CGSize(width: -0.5, height: 0)))
        XCTAssertEqual(left.image.size, CGSize(width: 100, height: 100))
        XCTAssertEqual(right.image.size, CGSize(width: 100, height: 100))
        let leftColor = try sample(try XCTUnwrap(left.image.cgImage), x: 25, y: 25)
        let rightColor = try sample(try XCTUnwrap(right.image.cgImage), x: 25, y: 25)
        XCTAssertGreaterThan(leftColor[0], 0.85); XCTAssertLessThan(leftColor[2], 0.15)
        XCTAssertGreaterThan(rightColor[2], 0.85); XCTAssertLessThan(rightColor[0], 0.15)
        XCTAssertEqual(left.image.imageOrientation, .up)
        let encodedImage = try XCTUnwrap(CGImageSourceCreateWithData(left.jpeg as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(encodedImage) as String?, UTType.jpeg.identifier)
        XCTAssertEqual(try sample(try XCTUnwrap(UIImage(data: left.jpeg)?.cgImage), x: 25, y: 25), leftColor)
        XCTAssertEqual(bytes, try encode(original, type: .png))
    }

    func testAllEightExifOrientationsBakeCorrectCornerPixelsBeforeCropping() throws {
        let original = picture(width: 120, height: 80, quadrants: true)
        // Original UIKit top-left coordinates: red, green, blue, yellow. EXIF mirrors and rotations
        // must change pixels, not merely leave an orientation flag on the displayed preview.
        let orders = [[0, 1, 2, 3], [1, 0, 3, 2], [3, 2, 1, 0], [2, 3, 0, 1],
                      [0, 2, 1, 3], [2, 0, 3, 1], [3, 1, 2, 0], [1, 3, 0, 2]]
        let colors: [[Double]] = [[1, 0, 0], [0, 1, 0], [0, 0, 1], [1, 1, 0]]
        for orientation in 1...8 {
            let source = try CraftPhotoProcessor.prepare(encode(original, type: .jpeg,
                properties: [kCGImagePropertyOrientation: orientation]))
            XCTAssertEqual(source.image.width, orientation <= 4 ? 120 : 80)
            XCTAssertEqual(source.image.height, orientation <= 4 ? 80 : 120)
            let points = [(1, 1), (3, 1), (1, 3), (3, 3)]
            for (index, point) in points.enumerated() {
                let actual = try sample(source.image, x: source.image.width * point.0 / 4, y: source.image.height * point.1 / 4)
                for channel in 0..<3 {
                    XCTAssertEqual(actual[channel], colors[orders[orientation - 1][index]][channel], accuracy: 0.15,
                                   "EXIF \(orientation), corner \(index)")
                }
            }
        }
    }

    func testLargeImageIsSampledAndOutputStripsLocationMetadata() throws {
        let original = picture(width: 1_800, height: 1_200, quadrants: true)
        let bytes = try encode(original, type: .jpeg, properties: [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 30.0,
                                          kCGImagePropertyGPSLatitudeRef: "N",
                                          kCGImagePropertyGPSLongitude: 120.0,
                                          kCGImagePropertyGPSLongitudeRef: "E"]
        ])
        let input = try XCTUnwrap(CGImageSourceCreateWithData(bytes as CFData, nil))
        let before = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(input, 0, nil) as? [CFString: Any])
        XCTAssertNotNil(before[kCGImagePropertyGPSDictionary])
        let source = try CraftPhotoProcessor.prepare(bytes)
        XCTAssertLessThanOrEqual(max(source.image.width, source.image.height), 1_536)
        let result = try CraftPhotoProcessor.finish(source, crop: CraftPhotoCrop())
        let output = try XCTUnwrap(CGImageSourceCreateWithData(result.jpeg as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(output, 0, nil) as? [CFString: Any])
        XCTAssertEqual(result.image.size.width, result.image.size.height)
        XCTAssertLessThanOrEqual(result.image.size.width, 1_024)
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
        XCTAssertEqual((properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1, 1)
    }

    func testRejectsEmptyInvalidUnsupportedAndOversizeBytes() throws {
        XCTAssertThrowsError(try CraftPhotoProcessor.prepare(Data())) { XCTAssertEqual($0 as? CraftPhotoError, .invalidImage) }
        XCTAssertThrowsError(try CraftPhotoProcessor.prepare(Data("not a photograph".utf8)))
        XCTAssertThrowsError(try CraftPhotoProcessor.prepare(Data(count: CraftPhotoProcessor.maximumBytes + 1))) {
            XCTAssertEqual($0 as? CraftPhotoError, .tooLarge)
        }
        let gif = try encode(picture(width: 8, height: 8, quadrants: false), type: .gif)
        XCTAssertThrowsError(try CraftPhotoProcessor.prepare(gif)) { XCTAssertEqual($0 as? CraftPhotoError, .unsupportedImage) }
    }

    func testDecodePreconditionAcceptsExactlyOneHundredMegapixelsAndRejectsLargerOrInvalidDimensions() throws {
        XCTAssertNoThrow(try CraftPhotoProcessor.validatePixelDimensions(width: 10_000, height: 10_000))
        XCTAssertThrowsError(try CraftPhotoProcessor.validatePixelDimensions(width: 10_001, height: 10_000)) {
            XCTAssertEqual($0 as? CraftPhotoError, .tooLarge)
        }
        XCTAssertThrowsError(try CraftPhotoProcessor.validatePixelDimensions(width: .greatestFiniteMagnitude, height: 2)) {
            XCTAssertEqual($0 as? CraftPhotoError, .tooLarge)
        }
        for invalid in [0.0, -1, .infinity, .nan] {
            XCTAssertThrowsError(try CraftPhotoProcessor.validatePixelDimensions(width: invalid, height: 100)) {
                XCTAssertEqual($0 as? CraftPhotoError, .invalidImage)
            }
        }
    }

    func testContradictoryOversizePNGHeaderIsRejectedWithoutDecodingRaster() throws {
        var png = try encode(picture(width: 4, height: 4, quadrants: false), type: .png)
        // The claimed size conflicts with the tiny compressed payload. Some ImageIO versions reject
        // that malformed container before metadata is exposed; others reach our pixel-size ceiling.
        for start in [16, 20] {
            for index in 0..<4 { png[start + index] = UInt8((10_001 >> ((3 - index) * 8)) & 255) }
        }
        var crc: UInt32 = .max
        for byte in png[12..<29] {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ (crc & 1 == 1 ? 0xEDB88320 : 0) }
        }
        crc ^= .max
        for index in 0..<4 { png[29 + index] = UInt8((crc >> ((3 - index) * 8)) & 255) }
        XCTAssertThrowsError(try CraftPhotoProcessor.prepare(png)) {
            let rejection = $0 as? CraftPhotoError
            XCTAssertTrue(rejection == .invalidImage || rejection == .tooLarge)
        }
    }

    private func picture(width: Int, height: Int, quadrants: Bool) -> CGImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            let halfWidth = CGFloat(width) / 2, halfHeight = CGFloat(height) / 2
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: halfWidth, height: CGFloat(height)))
            UIColor.blue.setFill(); context.fill(CGRect(x: halfWidth, y: 0, width: halfWidth, height: CGFloat(height)))
            if quadrants {
                UIColor.green.setFill(); context.fill(CGRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight))
                UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight))
                UIColor.yellow.setFill(); context.fill(CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight))
            }
        }.cgImage!
    }

    private func encode(_ image: CGImage, type: UTType, properties: [CFString: Any] = [:]) throws -> Data {
        let bytes = NSMutableData()
        let encoder = try XCTUnwrap(CGImageDestinationCreateWithData(bytes, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(encoder, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(encoder))
        return bytes as Data
    }

    private func sample(_ image: CGImage, x: Int, y: Int) throws -> [Double] {
        let pixel = try XCTUnwrap(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return bytes.prefix(3).map { Double($0) / 255 }
    }
}
