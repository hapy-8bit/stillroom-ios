import XCTest
@testable import Stillroom

final class LyricDocumentTests: XCTestCase {
    func testExactFractionsRepeatedTimesTranslationAndBracketedContent() throws {
        let source = "[00:10.25][00:01.003][00:02.7][Chorus] 原句\n[00:01.003]Translation\n[00:01.003]Translation"
        let document = try LyricDocument.parse(source)
        XCTAssertEqual(document.cues.map(\.time), [1.003, 2.7, 10.25])
        XCTAssertEqual(document.cues[0].text, "[Chorus] 原句\nTranslation")
        XCTAssertEqual(document.cues[1].text, "[Chorus] 原句")
        XCTAssertEqual(document.originalText, source)
        XCTAssertEqual(try document.canonicalText,
                       "[00:01.003][Chorus] 原句\n[00:01.003]Translation\n[00:02.700][Chorus] 原句\n[00:10.250][Chorus] 原句")
        XCTAssertEqual(Lyrics.parse(try document.canonicalText).map(\.text), document.cues.map(\.text))
    }

    func testSourceOffsetAdvancesWhileOldStoredStringsRetainLegacyAddition() throws {
        let source = "[00:01:25]First\n[offset:500]\n[offset:250]\n[00:10.5]Later"
        let document = try LyricDocument.parse(source)
        XCTAssertEqual(document.cues.map(\.time), [1, 10.25])
        XCTAssertEqual(document.offsetMilliseconds, 250)
        XCTAssertTrue(document.warnings.contains { $0.code == .duplicateOffset })
        XCTAssertTrue(document.warnings.contains { $0.code == .colonFraction })
        XCTAssertFalse(try document.canonicalText.contains("offset"))
        let legacy = Lyrics.parse("[offset:-250]\n[00:10.5][01:02.050]你好\n[00:01:25]开头\n[00:95]无效")
        XCTAssertEqual(legacy.map(\.time), [1, 10.25, 61.8])
        XCTAssertNil(Lyrics.activeIndex(in: legacy, at: 0))
    }

    func testNegativePrerollEventsRemainDistinctAndOnlyLastEffectiveEventSurvivesCanonicalBridge() throws {
        let raw = "[offset:2500]\r\n[00:00]Past\r\n[00:01]Effective\r\n[00:04]Future"
        let document = try LyricDocument.parse(raw)
        XCTAssertEqual(document.cues.map(\.time), [-2.5, -1.5, 1.5])
        XCTAssertEqual(document.originalText, raw)
        XCTAssertEqual(document.activeIndex(at: 0), 1)
        XCTAssertTrue(document.warnings.contains { $0.code == .negativePreroll })
        XCTAssertEqual(try document.canonicalText, "[00:00.000]Effective\n[00:01.500]Future")
        let zero = try LyricDocument.parse("[offset:1000]\n[00:00]Past\n[00:01]Real zero\n[00:02]Future")
        XCTAssertEqual(try zero.canonicalText, "[00:00.000]Real zero\n[00:01.000]Future")
    }

    func testUntimedContinuationFollowsEachRepeatedOccurrenceAndEmptyTimedCueClearsText() throws {
        let document = try LyricDocument.parse("[00:01][00:04]Original\n翻译\n[00:06]\n[00:07]Next")
        XCTAssertEqual(document.cues.map(\.text), ["Original\n翻译", "Original\n翻译", "", "Next"])
        XCTAssertEqual(document.activeIndex(at: 6.5), 2)
        XCTAssertEqual(Lyrics.parse(try document.canonicalText).map(\.text), document.cues.map(\.text))
        XCTAssertTrue(document.warnings.contains { $0.code == .untimedText })
    }

    func testBeforeFirstCueIsNotHighlightedAndInvalidMediaTimesNeverSelectALine() throws {
        let document = try LyricDocument.parse("[00:05]First\n[00:10]Second")
        XCTAssertEqual(document.activeIndex(at: 4.999), -1)
        XCTAssertEqual(document.activeIndex(at: 5), 0)
        XCTAssertEqual(document.activeIndex(at: 10), 1)
        for time in [-1, .nan, .infinity] {
            XCTAssertEqual(document.activeIndex(at: time), -1)
            XCTAssertNil(Lyrics.activeIndex(in: Lyrics.parse(try document.canonicalText), at: time))
        }
    }

    func testPlainTextRetainsRawSpacingNewlinesAndBracketsWithoutInventingTimestamps() throws {
        let raw = "  [Chorus]\r\n海边的风\r第二行  "
        let document = try LyricDocument.parse(raw)
        XCTAssertEqual(document.kind, .plain)
        XCTAssertEqual(document.originalText, raw)
        XCTAssertEqual(try document.canonicalText, raw)
        XCTAssertTrue(document.cues.isEmpty)
        XCTAssertEqual(document.activeIndex(at: 30), -1)
        XCTAssertTrue(Lyrics.parse(raw).isEmpty)
        XCTAssertEqual(try LyricDocument.parse("[00:01]literal", format: .plain).kind, .plain)
    }

    func testMalformedRowsHavePreviewWarningsAndInvalidOrOversizedDocumentsCannotSilentlyTruncate() throws {
        let document = try LyricDocument.parse("[00:70]invalid\n[00:01.1234]too precise\n[00:02]Valid")
        XCTAssertEqual(document.cues.map(\.time), [2])
        XCTAssertEqual(document.warnings.filter { $0.code == .invalidTime }.count, 2)
        for source in ["[00:95]bad", "[00:01 broken", "[00:01.1234]bad"] {
            XCTAssertThrowsError(try LyricDocument.parse(source)) { XCTAssertEqual($0 as? LyricImportError, .invalidFormat) }
        }
        for source in ["[offset:1.2]\n[00:01]voice", "[offset:999999999999999999999]\n[00:01]voice"] {
            XCTAssertThrowsError(try LyricDocument.parse(source)) { XCTAssertEqual($0 as? LyricImportError, .invalidOffset) }
        }
        XCTAssertThrowsError(try LyricDocument.parse("a\0b")) { XCTAssertEqual($0 as? LyricImportError, .invalidText) }
        XCTAssertThrowsError(try LyricDocument.parse("[ar:Artist]\n[ti:Title]")) { XCTAssertEqual($0 as? LyricImportError, .empty) }
        XCTAssertThrowsError(try LyricDocument.parse(String(repeating: "x", count: 1_048_577))) { XCTAssertEqual($0 as? LyricImportError, .tooLarge) }
        XCTAssertThrowsError(try LyricDocument.parse(Array(repeating: "line", count: 10_001).joined(separator: "\n"))) {
            XCTAssertEqual($0 as? LyricImportError, .tooManyLines)
        }
        XCTAssertThrowsError(try LyricDocument.parse(String(repeating: "[00:01]", count: 10_001) + "voice")) {
            XCTAssertEqual($0 as? LyricImportError, .tooManyCues)
        }
        let long = (0..<2_100).map { String(format: "[%02d:%02d]line%d", $0 / 60, $0 % 60, $0) }.joined(separator: "\n")
        XCTAssertEqual(Lyrics.parse(long).count, 2_100)
    }

    func testUTF8AndBOMUTF16StrictlyPreserveUnicodeAndCanonicalTiming() throws {
        let raw = "[00:01.25]海边 · café 🌙\r\n[00:02]第二句"
        let utf8 = try LyricTextDecoder.decode(Data([239, 187, 191]) + Data(raw.utf8))
        XCTAssertEqual(utf8.text, raw); XCTAssertEqual(utf8.encoding, .utf8)
        for little in [true, false] {
            let result = try LyricTextDecoder.decode(utf16(raw, little: little))
            XCTAssertEqual(result.encoding, little ? .utf16LE : .utf16BE)
            XCTAssertEqual(result.text, raw)
            XCTAssertEqual(try LyricDocument.parse(result.text).canonicalText, "[00:01.250]海边 · café 🌙\n[00:02.000]第二句")
        }
        XCTAssertEqual(try LyricTextDecoder.decode(utf16(raw, bom: false), encoding: .utf16LE).text, raw)
        XCTAssertThrowsError(try LyricTextDecoder.decode(utf16(raw, bom: false))) { XCTAssertEqual($0 as? LyricImportError, .invalidEncoding) }
    }

    func testMalformedEncodingCannotReplaceCharactersOrGuessLegacyChinesePages() {
        for bytes: [UInt8] in [[195], [192, 175], [237, 160, 128], [240, 159, 140], [255, 254, 65], [255, 254, 0, 216], [254, 255, 220, 0]] {
            XCTAssertThrowsError(try LyricTextDecoder.decode(Data(bytes))) { XCTAssertEqual($0 as? LyricImportError, .invalidEncoding) }
        }
        for encoding: LyricEncodingRequest in [.gbk, .gb18030] {
            XCTAssertThrowsError(try LyricTextDecoder.decode(Data([186, 163, 177, 223]), encoding: encoding)) {
                XCTAssertEqual($0 as? LyricImportError, .unsupportedEncoding)
            }
        }
        XCTAssertThrowsError(try LyricTextDecoder.decode(Data([255, 254, 0, 0, 65, 0, 0, 0]))) { XCTAssertEqual($0 as? LyricImportError, .unsupportedEncoding) }
        XCTAssertThrowsError(try LyricTextDecoder.decode(utf16("海边"), encoding: .utf8)) { XCTAssertEqual($0 as? LyricImportError, .encodingConflict) }
        XCTAssertThrowsError(try LyricTextDecoder.decode(Data(repeating: 65, count: 1_048_577))) { XCTAssertEqual($0 as? LyricImportError, .tooLarge) }
        for bytes: [UInt8] in [[], [239, 187, 191], [255, 254], [32, 10, 9]] {
            XCTAssertThrowsError(try LyricTextDecoder.decode(Data(bytes))) { XCTAssertEqual($0 as? LyricImportError, .empty) }
        }
    }

    private func utf16(_ text: String, little: Bool = true, bom: Bool = true) -> Data {
        var bytes: [UInt8] = bom ? (little ? [255, 254] : [254, 255]) : []
        for unit in text.utf16 {
            bytes.append(little ? UInt8(unit & 255) : UInt8(unit >> 8))
            bytes.append(little ? UInt8(unit >> 8) : UInt8(unit & 255))
        }
        return Data(bytes)
    }
}
