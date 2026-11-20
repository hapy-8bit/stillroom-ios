import XCTest
import SwiftUI
import UIKit
import Vision
import ImageIO
@testable import Stillroom

/// Actual release components and named resources. Fixtures never synthesize PCM
/// or claim that ImageRenderer executes the live audio subscription/lifecycle.
final class OneTapeReleaseScreenRenderingTests: XCTestCase {
    private let styles: [OneTapeAppearance.ScreenStyle] = [.fluid, .rain, .trails, .name, .meters]
    private let size = CGSize(width: 264.39, height: 165.63)

    @MainActor
    func testPhysicalOrientationOnlyAllowsLeftLandscape() {
        for previous in [-1, 0, 1] {
            XCTAssertEqual(OneTapeOrientationMonitor.supportedTurn(for: .landscapeLeft, retaining: previous), 1)
            for orientation in [UIDeviceOrientation.portrait, .portraitUpsideDown, .landscapeRight] {
                XCTAssertEqual(OneTapeOrientationMonitor.supportedTurn(for: orientation, retaining: previous), 0)
            }
            for orientation in [UIDeviceOrientation.faceUp, .faceDown, .unknown] {
                XCTAssertEqual(OneTapeOrientationMonitor.supportedTurn(for: orientation, retaining: previous),
                               previous == 1 ? 1 : 0)
            }
        }
    }

    func testOrientationGeometryRetainsLogicalGlyphScaleThroughTheSquareMidpoint() {
        for fraction in [0.0, 0.25, 0.4999, 0.5, 0.5001, 0.75, 1.0] {
            let logical = OneTapeScreenLayoutGeometry(fraction: fraction)
            for scale in [0.65, 1.0, 2.0] {
                let scaled = CGSize(width: logical.size.width * scale,
                                    height: logical.size.height * scale)
                let recovered = OneTapeScreenLayoutGeometry(size: scaled)
                XCTAssertEqual(recovered.tallFraction, fraction, accuracy: 0.000001)
                XCTAssertEqual(recovered.unit, scale, accuracy: 0.000001)
            }
        }
        let before = OneTapeScreenLayoutGeometry(fraction: 0.4999).size
        let after = OneTapeScreenLayoutGeometry(fraction: 0.5001).size
        XCTAssertEqual(OneTapeScreenLayoutGeometry(fraction: 0.5).size.width, 215.01, accuracy: 0.000001)
        XCTAssertLessThan(abs(OneTapeApprovedScreenTypeface.titleSize(size: before)
            - OneTapeApprovedScreenTypeface.titleSize(size: after)), 0.01)
        XCTAssertLessThan(abs(OneTapeApprovedScreenTypeface.particleTitleSize(size: before)
            - OneTapeApprovedScreenTypeface.particleTitleSize(size: after)), 0.01)
        XCTAssertLessThan(abs(OneTapeApprovedScreenLayout.headerBaseline(size: before)
            - OneTapeApprovedScreenLayout.headerBaseline(size: after)), 0.01)
        for style in styles {
            XCTAssertLessThan(abs(OneTapeApprovedScreenLayout.titleLastBaseline(style: style, size: before)
                - OneTapeApprovedScreenLayout.titleLastBaseline(style: style, size: after)), 0.1)
        }
        XCTAssertEqual(OneTapeScreenLayoutGeometry(size: .zero).unit, 1)
        XCTAssertEqual(OneTapeScreenLayoutGeometry(size: .zero).tallFraction, 0)
    }

    @MainActor
    func testFiveReleasedScreensRenderLiveTrackCountTimeArtistAndStatusAcrossOrientations() throws {
        for style in styles {
            for turns in [0, 1] {
                let image = try panel(style, readout: readout(), turns: turns)
                let text = try recognize(image, orientation: turns == 0 ? .up : .left)
                let compact = text.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
                let latin = letters(text)
                XCTAssertTrue(compact.contains("03/09"), "\(style.rawValue): \(text)")
                XCTAssertTrue(compact.contains("1:05"), "\(style.rawValue): \(text)")
                XCTAssertTrue(compact.contains("2:43"), "Missing remaining time in \(style.rawValue): \(text)")
                XCTAssertFalse(compact.contains("3:48"), "Total duration returned in \(style.rawValue): \(text)")
                XCTAssertFalse(latin.contains("PAUSED"), "Status must be a symbol in \(style.rawValue)")
                XCTAssertTrue(latin.contains("MARBLEBAND"), "\(style.rawValue): \(text)")
                XCTAssertTrue(latin.contains("RIVERSONG"), "\(style.rawValue): \(text)")
                attach(image, "release-\(style.rawValue)-turn-\(turns)-live-copy")
            }
        }
    }

    @MainActor
    func testTrackChangeAndLoadingRetainTheNewSongAndArtistInsteadOfReplacingThem() throws {
        for style in styles {
            let old = try panel(style, readout: readout())
            let next = try panel(style, readout: readout(title: "NIGHT TRAIN", artist: "EMBER CHOIR",
                position: 0, duration: 320, index: 3, playing: false, preparing: true, id: "second-track"))
            XCTAssertGreaterThan(try changedPixels(old, next), 80, "No live update in \(style.rawValue)")
            let text = try recognize(next)
            let latin = letters(text)
            XCTAssertTrue(latin.contains("NIGHTTRAIN"), "\(style.rawValue): \(text)")
            XCTAssertTrue(latin.contains("EMBERCHOIR"), "\(style.rawValue): \(text)")
            XCTAssertFalse(latin.contains("LOADING"), "Loading must not replace the symbol with English text")
            XCTAssertTrue(text.replacingOccurrences(of: " ", with: "").contains("04/09"),
                          "\(style.rawValue): \(text)")
        }
        // The ID test separately covers different tracks with identical names.
        // Root's UI journey must still verify actual engine-driven publication.
    }

    @MainActor
    func testLongMixedScriptMetadataDoesNotEscapeTheScreenOrReplaceTimeAndStatus() throws {
        let longTitle = "夜航 SIGNAL 👩🏽‍🚀🌒 " + String(repeating: "漫长夜空与海面 ", count: 12)
        let longArtist = "EMBER 乐队 🎻 " + String(repeating: "这是一段很长的艺人名称 ", count: 12)
        let padding: CGFloat = 10
        let outerSize = CGSize(width: size.width + padding * 2, height: size.height + padding * 2)
        for style in styles {
            for turns in [0, 1] {
                let view = OneTapeDisplay(style: style,
                    readout: readout(title: longTitle, artist: longArtist), quarterTurns: turns)
                    .padding(padding).background(Color(red: 1, green: 0, blue: 1))
                let outer = try render(view, size: outerSize)
                let margins = [CGRect(x: 0, y: 0, width: outerSize.width, height: 6),
                    CGRect(x: 0, y: outerSize.height - 6, width: outerSize.width, height: 6),
                    CGRect(x: 0, y: 0, width: 6, height: outerSize.height),
                    CGRect(x: outerSize.width - 6, y: 0, width: 6, height: outerSize.height)]
                for rect in margins {
                    let pixels = try rgba(crop(outer, rect: rect, logicalSize: outerSize))
                    let count = pixels.count / 4
                    let pink = stride(from: 0, to: pixels.count, by: 4).filter {
                        pixels[$0] > 248 && pixels[$0 + 1] < 8 && pixels[$0 + 2] > 248 && pixels[$0 + 3] > 248
                    }.count
                    XCTAssertGreaterThan(Double(pink) / Double(max(1, count)), 0.999,
                        "Text/art escaped \(style.rawValue), turn \(turns)")
                }
                let image = try crop(outer,
                    rect: CGRect(x: padding, y: padding, width: size.width, height: size.height),
                    logicalSize: outerSize)
                let text = try recognize(image, orientation: turns == 0 ? .up : .left)
                XCTAssertTrue(text.replacingOccurrences(of: " ", with: "").contains("2:43"),
                    "Long metadata displaced remaining time in \(style.rawValue): \(text)")
                XCTAssertTrue(text.replacingOccurrences(of: " ", with: "").contains("1:05"),
                    "Long metadata displaced media time in \(style.rawValue)")
                attach(image, "release-\(style.rawValue)-long-cjk-emoji-turn-\(turns)")
            }
        }
        // Retained frames require human shaping/contrast review. Mixed-script
        // OCR is not treated as proof that every Chinese/emoji glyph is correct.
    }

    @MainActor
    func testFrozenClockHoldsActualArtworkAndResumeChangesItsPose() throws {
        var clock = OneTapeScreenMotionClock()
        clock.setRunning(true, at: 100)
        clock.setRunning(false, at: 102)
        let paused = clock.phase(at: 102), laterPaused = clock.phase(at: 500)
        XCTAssertEqual(paused, laterPaused)
        clock.setRunning(true, at: 900)
        let resumed = clock.phase(at: 901)
        XCTAssertGreaterThan(resumed, paused)
        for style in [OneTapeAppearance.ScreenStyle.fluid, .rain, .trails, .name] {
            let first = try artwork(style, phase: paused)
            let held = try artwork(style, phase: laterPaused)
            let moving = try artwork(style, phase: resumed)
            XCTAssertEqual(try rgba(first), try rgba(held), "Paused \(style.rawValue) changed")
            XCTAssertGreaterThan(try changedPixels(first, moving), 20,
                "Resumed \(style.rawValue) stayed static")
        }
        // This covers the pure clock used by the actual display plus the actual
        // draw boundary. TimelineView/onChange lifecycle still needs UI coverage.
    }

    @MainActor
    func testMetersUseMeasuredBandsClearOnPauseAndDoNotInventRhythmFromVisualPhase() throws {
        var measured = OneTapeScreenResponse.silent
        measured.bands = (0..<16).map { $0.isMultiple(of: 2) ? 0.75 : 0.35 }
        measured.heldPeaks = [Double](repeating: 0.85, count: 16)
        let playing = readout(playing: true)
        let first = try render(OneTapeLiveScreenArtwork(style: .meters, phase: 1,
            readout: playing, response: measured, signalAvailable: true), size: size)
        let later = try render(OneTapeLiveScreenArtwork(style: .meters, phase: 5,
            readout: playing, response: measured, signalAvailable: true), size: size)
        let paused = try render(OneTapeLiveScreenArtwork(style: .meters, phase: 1,
            readout: readout(), response: measured, signalAvailable: true), size: size)
        let buffering = try render(OneTapeLiveScreenArtwork(style: .meters, phase: 1,
            readout: readout(preparing: true), response: measured, signalAvailable: true), size: size)
        let silent = try render(OneTapeLiveScreenArtwork(style: .meters, phase: 1,
            readout: playing, response: .silent, signalAvailable: true), size: size)
        XCTAssertEqual(try rgba(first), try rgba(later), "Visual time must not generate fake meter rhythm")
        XCTAssertGreaterThan(try changedPixels(first, silent), 200)
        XCTAssertEqual(try rgba(paused), try rgba(silent), "Pause retained previous-track meter energy")
        XCTAssertEqual(try rgba(buffering), try rgba(silent), "Loading retained measured activity")
    }

    @MainActor
    func testNameBitmapLayoutRetainsEmojiUsesThreeTallLinesAndInvalidatesForNewTitle() throws {
        for canvas in [size, CGSize(width: size.height, height: size.width)] {
            let short = OneTapeParticleTitle.makeLayout(title: "RIVER SONG", size: canvas)
            let changed = OneTapeParticleTitle.makeLayout(title: "NIGHT TRAIN", size: canvas)
            let emoji = OneTapeParticleTitle.makeLayout(title: "👩🏽‍🚀🌒", size: canvas)
            let long = OneTapeParticleTitle.makeLayout(
                title: "夜航 SIGNAL 👩🏽‍🚀 " + String(repeating: "漫长的夜空与海面 ", count: 12), size: canvas)
            XCTAssertNotNil(short.image)
            XCTAssertGreaterThan(short.grains.count, 50)
            XCTAssertNotEqual(short.key, changed.key)
            XCTAssertNotEqual(short.grains.map(\.point), changed.grains.map(\.point))
            XCTAssertGreaterThan(emoji.grains.count, 30, "Bitmap-only emoji disappeared from the title mask")
            XCTAssertGreaterThan(long.grains.count, 50)
            XCTAssertEqual(long.lineCount, canvas.height > canvas.width ? 3 : 1)
            let rect = OneTapeApprovedScreenLayout.artworkRect(style: .name, size: canvas).insetBy(dx: -1, dy: -1)
            XCTAssertTrue(long.grains.allSatisfy { rect.contains($0.point) },
                          "Long glyphs leave the reserved title artwork")
        }
    }

    @MainActor
    func testApprovedTimingFontsAreRealRegisteredBundledFaces() throws {
        let entries = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String])
        for name in ["InstrumentSerif-Italic", "InstrumentSerif-Regular",
                     "CormorantGaramond-MediumItalic", "SpaceGrotesk-Medium"] {
            let font = try XCTUnwrap(UIFont(name: name, size: 20), "Silent fallback: \(name)")
            XCTAssertEqual(font.fontName, name)
            let entry = try XCTUnwrap(entries.first { $0.hasSuffix(name + ".ttf") },
                                      "Missing UIAppFonts entry: \(name)")
            let resources = try XCTUnwrap(Bundle.main.resourceURL)
            XCTAssertTrue(FileManager.default.fileExists(atPath: resources.appendingPathComponent(entry).path),
                          "Registered font absent from app bundle: \(entry)")
        }
    }

    @MainActor
    func testPlaybackStateChangesTheRenderedSymbolWithoutEnglishStatusCopy() throws {
        let rect = OneTapeApprovedScreenLayout.symbolRect(size: size).insetBy(dx: -1, dy: -1)
        for style in styles {
            let paused = try panel(style, readout: readout())
            let playing = try panel(style, readout: readout(playing: true))
            let loading = try panel(style, readout: readout(playing: true, preparing: true))
            let pauseMark = try crop(paused, rect: rect, logicalSize: size)
            let playMark = try crop(playing, rect: rect, logicalSize: size)
            let loadMark = try crop(loading, rect: rect, logicalSize: size)
            XCTAssertGreaterThan(try changedPixels(pauseMark, playMark), 20,
                "The actual frame ignored pause/play in \(style.rawValue)")
            XCTAssertGreaterThan(try changedPixels(playMark, loadMark), 20,
                "The actual frame kept the playing symbol while loading in \(style.rawValue)")
            attach(paused, "labels-\(style.rawValue)-pause-symbol")
            attach(playing, "labels-\(style.rawValue)-play-symbol")
        }
    }

    private func readout(title: String = "RIVER SONG", artist: String = "MARBLE BAND",
                         position: Double = 65, duration: Double = 228, index: Int = 2,
                         playing: Bool = false, preparing: Bool = false,
                         id: String = "first-track") -> OneTapePlaybackReadout {
        OneTapePlaybackReadout(title: title, artist: artist, positionSeconds: position,
            durationSeconds: duration, isPlaying: playing, isPreparing: preparing,
            trackIndex: index, trackCount: 9, trackID: id)
    }

    @MainActor
    private func panel(_ style: OneTapeAppearance.ScreenStyle, readout: OneTapePlaybackReadout,
                       turns: Int = 0) throws -> CGImage {
        try render(OneTapeDisplay(style: style, readout: readout, quarterTurns: turns), size: size)
    }

    @MainActor
    private func artwork(_ style: OneTapeAppearance.ScreenStyle, phase: Double) throws -> CGImage {
        if style == .name {
            return try render(OneTapeLiveScreenArtwork(style: .name, phase: phase,
                readout: readout(), response: .silent, signalAvailable: true), size: size)
        }
        if style == .fluid {
            return try XCTUnwrap(OneTapeMaterialRasterizer.render(style: style, phase: phase,
                                                                 size: size, displayScale: 2))
        }
        return try XCTUnwrap(OneTapeLivePhotoRasterizer.render(style: style, phase: phase,
                                                             size: size, displayScale: 2))
    }

    @MainActor
    private func render<Content: View>(_ content: Content, size: CGSize) throws -> CGImage {
        let renderer = ImageRenderer(content: content
            .frame(width: size.width, height: size.height)
            .environment(\.scenePhase, .inactive)
            .environment(\.dynamicTypeSize, .medium))
        renderer.scale = 4
        return try XCTUnwrap(renderer.uiImage?.cgImage)
    }

    private func crop(_ image: CGImage, rect: CGRect, logicalSize: CGSize) throws -> CGImage {
        let sx = Double(image.width) / logicalSize.width
        let sy = Double(image.height) / logicalSize.height
        return try XCTUnwrap(image.cropping(to: CGRect(x: rect.minX * sx, y: rect.minY * sy,
            width: rect.width * sx, height: rect.height * sy)))
    }

    private func rgba(_ image: CGImage) throws -> [UInt8] {
        var result = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        try result.withUnsafeMutableBytes { data in
            let context = try XCTUnwrap(CGContext(data: data.baseAddress, width: image.width,
                height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return result
    }

    private func changedPixels(_ a: CGImage, _ b: CGImage) throws -> Int {
        XCTAssertEqual(a.width, b.width)
        XCTAssertEqual(a.height, b.height)
        let first = try rgba(a), second = try rgba(b)
        return stride(from: 0, to: min(first.count, second.count), by: 4).filter { offset in
            (0..<3).contains { abs(Int(first[offset + $0]) - Int(second[offset + $0])) >= 4 }
        }.count
    }

    private func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation = .up) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.01
        try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    }

    private func letters(_ text: String) -> String {
        text.uppercased().replacingOccurrences(of: "[^A-Z]", with: "", options: .regularExpression)
    }

    private func attach(_ image: CGImage, _ name: String) {
        let attachment = XCTAttachment(image: UIImage(cgImage: image))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

