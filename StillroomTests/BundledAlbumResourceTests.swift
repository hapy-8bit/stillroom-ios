import XCTest
import AVFoundation
import CryptoKit
import UIKit
@testable import Stillroom

final class BundledAlbumResourceTests: XCTestCase {
    func testOfficialRecordingsAreUnmodifiedAndDecodeAtTheirRealDurations() throws {
        let expectedHashes = [
            "cz-cylinder-one": "dc88756d6c5453ca0293f340c59c62b41ed0478f2c4b7d3d12f1df9428675b74",
            "cz-heliograph": "ed614ee448559a1f7f4ad597d6548723d07c79e5d47bb9569dbe42994cf4f60d",
            "cz-angiesss": "da30666fa279136c53caa7592ea3efe01ff11ce9a292633293d5bf30db6f859d",
            "cz-src": "290a9151d76a38d1e26b3d7dcc55f8d69cb0b4f73a79db011ba2cb13e7011970",
            "cz-ababab": "81c75886ca712a182b46f4015d5fb4ef42158fd11c288dcc82128f35a1eebf49",
            "cz-asleep": "6d407ea5f9820e23703243f61eb6f0415b05ce2c85a2c3c48a4f654505beb478",
            "cz-neptuneflux": "01f808394372067cd9e7fe73d59fbd8aaab2fa81a5ea2c344828b08a55c835cb",
            "cz-reappear": "e86525ad207cd0ec6de1ebcda362f45f3a0e4066459e709bbedb39d1b5b860b4",
            "cz-dtv": "150811660da8bed82b681146ba83e5b2dd27002de231cf46b45f11e2ad4678fa"
        ]
        XCTAssertEqual(Set(BundledAlbumCatalog.tracks.map(\.id)), Set(expectedHashes.keys))
        for track in BundledAlbumCatalog.tracks {
            let url = try XCTUnwrap(Bundle.main.url(forResource: track.audioFile, withExtension: nil))
            let bytes = try Data(contentsOf: url)
            let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(hash, expectedHashes[track.id])
            let decoder = try AVAudioPlayer(contentsOf: url)
            XCTAssertGreaterThan(decoder.duration, 60)
            XCTAssertEqual(decoder.duration, track.duration, accuracy: 0.01)
            XCTAssertFalse(decoder.isPlaying)
            XCTAssertFalse(track.isLyricDemo)
            XCTAssertTrue(track.lyrics.isEmpty)
        }
    }

    func testOriginalCoversAndSourceCreditsExistWithoutReusingLegacyIDs() throws {
        let legacyIDs = Set(Track.demos.map(\.id))
        XCTAssertEqual(BundledAlbumCatalog.tracks.count, 9)
        XCTAssertEqual(Set(BundledAlbumCatalog.tracks.map(\.albumKey)).count, 9)
        XCTAssertEqual(Set(BundledAlbumCatalog.tracks.map(\.audioFile)).count, 9)
        XCTAssertEqual(Set(BundledAlbumCatalog.tracks.compactMap { BundledAlbumCatalog.artworkAssetName(for: $0.id) }).count, 9)
        for track in BundledAlbumCatalog.tracks {
            XCTAssertFalse(legacyIDs.contains(track.id))
            XCTAssertEqual(track.artist, "Chris Zabriskie")
            let asset = try XCTUnwrap(BundledAlbumCatalog.artworkAssetName(for: track.id))
            let image = try XCTUnwrap(UIImage(named: asset))
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(image.cgImage).width, 1000)
            let credit = try XCTUnwrap(BundledAlbumCatalog.credit(for: track.id))
            XCTAssertEqual(credit.albumPage.host, "chriszabriskie.com")
            XCTAssertEqual(credit.audioSource.host, "audio.chriszabriskie.com")
            XCTAssertEqual(credit.license.absoluteString, "https://creativecommons.org/licenses/by/4.0/")
        }
        XCTAssertEqual(BundledAlbumCatalog.credit(for: "cz-reappear")?.audioSource.absoluteString,
                       "https://audio.chriszabriskie.com/reappear/reappear-04.m4a")
        XCTAssertNil(BundledAlbumCatalog.credit(for: "sea"))
        XCTAssertNil(BundledAlbumCatalog.artworkAssetName(for: "sea"))
    }
}
