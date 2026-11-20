import XCTest
import CoreGraphics
@testable import Stillroom

final class OneTapeNameSandLayoutTests: XCTestCase {
    func testLongMetadataKeepsReadableGlyphHeightInsideNarrowAndWideArtwork() throws {
        let sizes = [CGSize(width: 244.39, height: 106), CGSize(width: 151.63, height: 195)]
        for size in sizes {
            let short = OneTapeNameSand.grainTargets(title: "夜間飛行", artist: "坂本龍一", size: size)
            let long = OneTapeNameSand.grainTargets(
                title: String(repeating: "夜間飛行を聴きながら歩く", count: 30),
                artist: String(repeating: "坂本龍一與他的朋友們", count: 20), size: size)
            XCTAssertFalse(long.isEmpty)
            assertInside(long, size: size)
            // The title and artist have distinct vertical lanes. Their actual
            // sampled height must survive long metadata, rather than collapsing
            // toward zero as an entire line is scaled down to fit the viewport.
            for titleLane in [false, true] {
                let shortHeight = try glyphHeight(short, in: size, titleLane: titleLane)
                let longHeight = try glyphHeight(long, in: size, titleLane: titleLane)
                XCTAssertGreaterThan(shortHeight, titleLane ? 10 : 6)
                XCTAssertGreaterThanOrEqual(longHeight, shortHeight * 0.7,
                    "Long metadata lost readable height in \(size)")
            }
        }
    }

    func testMixedCJKAndEmojiFallbackKeepsFiniteVisibleLetterOutlines() throws {
        let size = CGSize(width: 151.63, height: 195)
        let text = OneTapeNameSand.normalizedText(
            title: "🌙 夜の海 🎵 Archive", artist: "Björk・坂本龍一 🎹", hasTrack: true)
        let points = OneTapeNameSand.grainTargets(title: text.title, artist: text.artist, size: size)
        XCTAssertFalse(points.isEmpty)
        assertInside(points, size: size)
        XCTAssertGreaterThan(try glyphHeight(points, in: size, titleLane: true), 10)
        XCTAssertGreaterThan(try glyphHeight(points, in: size, titleLane: false), 6)

        // Color bitmap emoji may provide no vector path. Skipping those glyphs
        // must remain safe rather than force-unwrapping a nonexistent outline.
        let emojiOnly = OneTapeNameSand.grainTargets(title: "🎵", artist: "🎹", size: size)
        assertInside(emojiOnly, size: size)
    }

    func testWhitespaceMetadataAndEmptyLibraryHaveVisibleFallbackText() throws {
        let size = CGSize(width: 244.39, height: 106)
        let missing = OneTapeNameSand.normalizedText(title: " \n\t", artist: "\u{3000}\n", hasTrack: true)
        XCTAssertEqual(missing.title, "未命名歌曲")
        XCTAssertEqual(missing.artist, "未知艺人")
        let empty = OneTapeNameSand.normalizedText(title: "", artist: "", hasTrack: false)
        XCTAssertEqual(empty.title, "还没有磁带")
        XCTAssertEqual(empty.artist, "在音乐库添加音乐")
        for text in [missing, empty] {
            let points = OneTapeNameSand.grainTargets(title: text.title, artist: text.artist, size: size)
            assertInside(points, size: size)
            XCTAssertGreaterThan(try glyphHeight(points, in: size, titleLane: true), 10)
            XCTAssertGreaterThan(try glyphHeight(points, in: size, titleLane: false), 6)
        }
    }

    private func glyphHeight(_ points: [CGPoint], in size: CGSize, titleLane: Bool) throws -> CGFloat {
        let lane = points.filter { ($0.y >= size.height * 0.5) == titleLane }
        let first = try XCTUnwrap(lane.first, "Missing \(titleLane ? "title" : "artist") outlines")
        let minimum = lane.reduce(first.y) { min($0, $1.y) }
        let maximum = lane.reduce(first.y) { max($0, $1.y) }
        return maximum - minimum
    }

    private func assertInside(_ points: [CGPoint], size: CGSize,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(points.allSatisfy {
            $0.x.isFinite && $0.y.isFinite && $0.x >= 0 && $0.y >= 0
                && $0.x < size.width && $0.y < size.height
        }, "Glyph targets escaped their artwork viewport", file: file, line: line)
    }
}
