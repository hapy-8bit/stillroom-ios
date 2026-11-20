import XCTest
import AVFoundation
import UIKit
import ImageIO
@testable import Stillroom

@MainActor
final class LocalCoverMetadataTests: XCTestCase {
    func testEmbeddedArtworkAndAlbumArtistSurviveRealM4AImportAndColdRestore() async throws {
        let root = try LocalCoverFixtures.directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = try await LocalCoverFixtures.audio(in: root, name: "Tagged", album: "Shared Album",
                                                      artist: "Singer", albumArtist: "Various Artists", artwork: .orange)
        let folder = root.appendingPathComponent("Library")
        let repository = LibraryRepository(directory: folder)
        let staged = try await repository.stageAudio(from: audio)
        XCTAssertEqual(staged.album, "Shared Album")
        XCTAssertEqual(staged.albumArtist, "Various Artists")
        let artworkName = try XCTUnwrap(staged.artworkFile)
        let image = try XCTUnwrap(CGImageSourceCreateWithURL(folder.appendingPathComponent(artworkName) as CFURL, nil))
        let pixels = try XCTUnwrap(CGImageSourceCreateImageAtIndex(image, 0, nil))
        XCTAssertEqual(pixels.width, pixels.height)
        XCTAssertLessThanOrEqual(pixels.width, 1_024)
        try await repository.save([staged])
        let restored = try await LibraryRepository(directory: folder).restore()
        XCTAssertEqual(restored.first?.artworkFile, artworkName)
        XCTAssertEqual(restored.first?.albumArtist, "Various Artists")
        XCTAssertTrue(FileManager.default.fileExists(atPath: audio.path), "Import never rewrites the source audio")
    }

    func testEmbeddedCoverSaveFailureStillStagesPlayableAudioAndExplainsMissingImage() async throws {
        let root = try LocalCoverFixtures.directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = try await LocalCoverFixtures.audio(in: root, name: "Tagged", album: "Album", artwork: .purple)
        let blocker = root.appendingPathComponent("cover-id.jpg")
        let original = Data("unrelated existing file".utf8)
        try original.write(to: blocker)
        let result = try await MetadataReader.readForPreview(audio, id: "cover-id", originalName: "Tagged", directory: root)
        XCTAssertNil(result.track.artworkFile)
        XCTAssertNotNil(result.artworkNotice)
        XCTAssertGreaterThan(result.track.duration, 0)
        XCTAssertEqual(try Data(contentsOf: blocker), original)
    }

    func testEmbeddedCompressedImageIsBoundedAndCannotReplaceExistingDestination() throws {
        let root = try LocalCoverFixtures.directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let data = LocalCoverFixtures.image(.cyan, size: CGSize(width: 2_800, height: 1_800))
        let path = root.appendingPathComponent("normalized.jpg")
        try CoverImportAdapter.normalize(data: data, destination: path)
        let image = try XCTUnwrap(UIImage(contentsOfFile: path.path)?.cgImage)
        XCTAssertEqual(image.width, image.height)
        XCTAssertLessThanOrEqual(image.width, 1_024)
        let saved = try Data(contentsOf: path)
        XCTAssertThrowsError(try CoverImportAdapter.normalize(data: data, destination: path))
        XCTAssertEqual(try Data(contentsOf: path), saved)
    }

    func testMetadataPositionsHandleTextFractionsAndBinaryITunesTuple() {
        XCTAssertEqual(LocalAudioMetadata.position(text: " 3/12 "), 3)
        XCTAssertNil(LocalAudioMetadata.position(text: "0/12"))
        XCTAssertNil(LocalAudioMetadata.position(text: "unknown"))
        XCTAssertEqual(LocalAudioMetadata.iTunesPosition(data: Data([0, 0, 0, 9, 0, 12, 0, 0])), 9)
        XCTAssertEqual(LocalAudioMetadata.iTunesPosition(data: Data([0, 0, 1, 3, 0, 0, 0, 0])), 259)
        XCTAssertNil(LocalAudioMetadata.iTunesPosition(data: Data([0, 0, 0])))
        XCTAssertNil(LocalAudioMetadata.iTunesPosition(data: Data([0, 0, 0, 0, 0, 12, 0, 0])))
    }
}

/// Synthetic audio is exported from the project's own bundled WAV. Metadata
/// differs per song so its content identity remains distinct during deduplication.
@MainActor
enum LocalCoverFixtures {
    static func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func image(_ color: UIColor, size: CGSize = CGSize(width: 96, height: 64)) -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.88) { context in
            color.setFill(); context.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func audio(in directory: URL, name: String, album: String, artist: String = "Artist",
                      albumArtist: String = "Album Artist", artwork: UIColor? = nil) async throws -> URL {
        let source = try XCTUnwrap(Bundle.main.url(forResource: "sea.wav", withExtension: nil))
        let asset = AVURLAsset(url: source)
        let exporter = try XCTUnwrap(AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A))
        var metadata = [text(.iTunesMetadataSongName, name), text(.iTunesMetadataAlbum, album),
                        text(.iTunesMetadataArtist, artist), text(.iTunesMetadataAlbumArtist, albumArtist)]
        if let artwork {
            let item = AVMutableMetadataItem()
            item.identifier = .iTunesMetadataCoverArt
            item.dataType = kCMMetadataBaseDataType_JPEG as String
            item.value = image(artwork) as NSData
            metadata.append(item)
        }
        exporter.metadata = metadata
        exporter.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 1, preferredTimescale: 600))
        let target = directory.appendingPathComponent(name + ".m4a")
        try await exporter.export(to: target, as: .m4a)
        return target
    }

    private static func text(_ id: AVMetadataIdentifier, _ value: String) -> AVMutableMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = id
        item.value = value as NSString
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        return item
    }
}
