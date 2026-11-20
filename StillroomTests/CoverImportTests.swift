import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Stillroom

final class CoverImportTests: XCTestCase {
    func testOrdinaryPNGWithNoExifImportsFromPartFilenameWithoutChangingSource() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 90, height: 60), format: format())
        let original = renderer.pngData { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 45, height: 60))
            UIColor.blue.setFill(); context.fill(CGRect(x: 45, y: 0, width: 45, height: 60))
        }
        let source = folder.appendingPathComponent("source.part"), output = folder.appendingPathComponent("cover.jpg")
        try original.write(to: source)
        try CoverImportAdapter.normalize(source: source, destination: output)
        XCTAssertEqual(try Data(contentsOf: source), original)
        let normalized = try XCTUnwrap(CGImageSourceCreateWithURL(output as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetType(normalized) as String?, UTType.jpeg.identifier)
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(normalized, 0, nil))
        XCTAssertEqual(image.width, 60); XCTAssertEqual(image.height, 60)
        XCTAssertThrowsError(try CoverImportAdapter.normalize(source: source, destination: output))
    }

    func testAllExifOrientationsAreBakedIntoBoundedSquarePixels() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1_800, height: 1_200), format: format()).image { context in
            UIColor.orange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 900, height: 1_200))
            UIColor.green.setFill(); context.fill(CGRect(x: 900, y: 0, width: 900, height: 1_200))
        }
        for orientation in 1...8 {
            let input = NSMutableData()
            let encoder = try XCTUnwrap(CGImageDestinationCreateWithData(input, UTType.jpeg.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(encoder, try XCTUnwrap(image.cgImage), [kCGImagePropertyOrientation: orientation] as CFDictionary)
            XCTAssertTrue(CGImageDestinationFinalize(encoder))
            let source = folder.appendingPathComponent("source-\(orientation).jpg")
            let output = folder.appendingPathComponent("output-\(orientation).jpg")
            try (input as Data).write(to: source)
            try CoverImportAdapter.normalize(source: source, destination: output)
            let decoded = try XCTUnwrap(CGImageSourceCreateWithURL(output as CFURL, nil))
            let result = try XCTUnwrap(CGImageSourceCreateImageAtIndex(decoded, 0, nil))
            XCTAssertEqual(result.width, result.height); XCTAssertLessThanOrEqual(result.width, 1_024)
            let metadata = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(decoded, 0, nil) as? [CFString: Any])
            XCTAssertEqual((metadata[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1, 1)
        }
    }

    func testRenamedOrEmptyNonImageIsRejectedWithoutCreatingDestination() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("fake.png"), output = folder.appendingPathComponent("new.jpg")
        try Data("not an image".utf8).write(to: source)
        XCTAssertThrowsError(try CoverImportAdapter.normalize(source: source, destination: output))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }

    private func format() -> UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; return format
    }
}
