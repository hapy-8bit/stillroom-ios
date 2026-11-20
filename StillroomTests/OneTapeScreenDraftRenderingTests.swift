import XCTest
import SwiftUI
import Vision
import UIKit
import ImageIO
@testable import Stillroom

/// Compatibility checks for legacy Frame/Canvas components, not selectable
/// production styles or acceptance of the reference's paid artwork. The current
/// five-style production route is covered by OneTapeReleaseScreenRenderingTests.
/// Offscreen rendering does not mount legacy NameSand callbacks or PCM delivery.
final class OneTapeScreenDraftRenderingTests: XCTestCase {
    private let displaySize = CGSize(width: 264.39, height: 165.63)
    private var artStyles: [OneTapeAppearance.ScreenStyle] {
        OneTapeAppearance.ScreenStyle.allCases.filter { $0 != .lcd }
    }
    private let editorialStyles: [OneTapeAppearance.ScreenStyle] = [.dunes, .iron, .fluid]
    private var legacyFrameStyles: [OneTapeAppearance.ScreenStyle] {
        artStyles.filter { !editorialStyles.contains($0) }
    }

    @MainActor
    func testLegacyFrameModesRenderChangesToBothQueueAndMediaTime() throws {
        for style in legacyFrameStyles {
            let original = try display(style, readout: readout())
            let newQueue = try display(style, readout: readout(index: 7, count: 12))
            let newTime = try display(style, readout: readout(position: 143, duration: 360))
            let queueRow = CGRect(x: 10, y: 6, width: 244, height: 13)
            let timeRow = CGRect(x: 10, y: 20, width: 244, height: 24)
            XCTAssertGreaterThan(try changedPixels(original, newQueue, in: queueRow), 20,
                "Queue text did not change in \(style.rawValue)")
            XCTAssertGreaterThan(try changedPixels(original, newTime, in: timeRow), 20,
                "Media time did not change in \(style.rawValue)")
        }
    }

    @MainActor
    func testLegacyFrameNonNameModesVisiblyKeepBothTitleAndArtist() throws {
        let footer = CGRect(x: 10, y: 121, width: 244, height: 41)
        for style in legacyFrameStyles where style != .name {
            let original = try display(style, readout: readout())
            let changedTitle = try display(style, readout: readout(title: "NIGHT TRAIN"))
            let changedArtist = try display(style, readout: readout(artist: "EMBER CHOIR"))
            XCTAssertGreaterThan(try changedPixels(original, changedTitle, in: footer), 20,
                "Title is missing from \(style.rawValue)")
            XCTAssertGreaterThan(try changedPixels(original, changedArtist, in: footer), 20,
                "Artist is missing from \(style.rawValue)")
            // Pixel changes alone could pass for a decorative reaction. OCR
            // verifies that the actual Latin fixture strings remain readable.
            let words = try recognizedLetters(in: original.cropped(to: footer))
            XCTAssertTrue(words.contains("RIVERSONG"), "Unreadable title in \(style.rawValue): \(words)")
            XCTAssertTrue(words.contains("MARBLEBAND"), "Unreadable artist in \(style.rawValue): \(words)")
        }
        // Name intentionally has no duplicate metadata footer. Its grain targets
        // load in layout callbacks ImageRenderer does not execute; no blank offscreen
        // Name image is treated here as proof of working particle lettering.
    }

    @MainActor
    func testQuarterTurnKeepsVisibleMetadataInLegacyFrameModes() throws {
        for style in legacyFrameStyles {
            let original = try display(style, readout: readout(), quarterTurns: 1)
            let changed = try display(style, readout: readout(title: "NIGHT TRAIN", artist: "EMBER CHOIR",
                position: 143, duration: 360, index: 7, count: 12), quarterTurns: 1)
            // A positive quarter-turn moves the tall header to the physical
            // screen's right edge, and its footer to the left edge. These broad
            // regions permit font-metric changes without freezing artwork pixels.
            let header = CGRect(x: 214, y: 5, width: 46, height: 155)
            XCTAssertGreaterThan(try changedPixels(original, changed, in: header), 20,
                "Rotated header is empty or clipped in \(style.rawValue)")
            if style != .name {
                let footer = CGRect(x: 5, y: 5, width: 48, height: 155)
                XCTAssertGreaterThan(try changedPixels(original, changed, in: footer), 20,
                    "Rotated footer is empty or clipped in \(style.rawValue)")
            }
        }
    }

    @MainActor
    func testScopeRespondsToMeasuredSamplesInsteadOfInventingAWaveFromEnergy() throws {
        var dynamics = OneTapeScreenDynamics()
        let samples: [Float] = [0, 0.8, 0.8, 0, -0.75, -0.75, 0, 0.6, 0, -0.5, 0]
        let measured = dynamics.consume(rms: 0.4, peak: 0.8, bands: [0.7], waveform: samples,
            active: true, elapsed: 0.05)
        let highEnergyFlat = dynamics.consume(rms: 0.8, peak: 1, bands: [0.9],
            waveform: Array(repeating: 0, count: samples.count), active: true, elapsed: 0.05)
        let stopped = dynamics.consume(rms: 0.8, peak: 1, bands: [0.9], waveform: samples,
            active: false, elapsed: 0.05)
        let silentImage = try scope(.silent)
        let measuredImage = try scope(measured)
        let flatImage = try scope(highEnergyFlat)
        let stoppedImage = try scope(stopped)
        let artwork = CGRect(x: 12, y: 49, width: 240, height: 66)
        let aboveBaseline = CGRect(x: 20, y: 49, width: 224, height: 22)
        XCTAssertGreaterThan(try changedPixels(silentImage, measuredImage, in: aboveBaseline), 100)
        XCTAssertLessThanOrEqual(try changedPixels(silentImage, flatImage, in: artwork), 4,
            "Energy alone must not create an oscilloscope waveform")
        XCTAssertLessThanOrEqual(try changedPixels(silentImage, stoppedImage, in: artwork), 4,
            "Inactive sampling must clear the measured waveform")
        // These are deterministic analyzer-input fixtures in the actual Canvas
        // and Frame. They do not pretend that ImageRenderer ran onReceive or PCM.
    }

    @MainActor
    func testEditorialPhotoResourcesHaveTonalDetailAndAreDifferentImages() throws {
        var sampledImages: [[UInt8]] = []
        for name in ["OneTapeScreenDunesPhoto", "OneTapeScreenIronPhoto", "OneTapeScreenFluidPhoto"] {
            let image = try XCTUnwrap(UIImage(named: name)?.cgImage, "Missing real photo asset: \(name)")
            XCTAssertGreaterThanOrEqual(image.width, 264)
            XCTAssertGreaterThanOrEqual(image.height, 166)
            let sample = try resizedRGBA(image, width: 128, height: 80)
            let luminance = stride(from: 0, to: sample.count, by: 4).map {
                (Double(sample[$0]) * 0.2126 + Double(sample[$0 + 1]) * 0.7152
                    + Double(sample[$0 + 2]) * 0.0722)
            }
            let mean = luminance.reduce(0, +) / Double(luminance.count)
            let deviation = sqrt(luminance.reduce(0) { $0 + pow($1 - mean, 2) } / Double(luminance.count))
            let occupiedTones = Set(luminance.map { Int($0) / 16 })
            // Matte iron intentionally stays in the dark end of the approved
            // palette. Reject flat/empty data without requiring bright highlights.
            XCTAssertGreaterThan(deviation, 8, "Blank or flat photograph: \(name)")
            XCTAssertGreaterThanOrEqual(occupiedTones.count, 5, "Missing gray tonal range: \(name)")
            XCTAssertGreaterThan(fraction(sample) { _, _, _, alpha in alpha > 240 }, 0.95)
            sampledImages.append(sample)
        }
        for first in 0..<sampledImages.count {
            for second in (first + 1)..<sampledImages.count {
                let a = sampledImages[first], b = sampledImages[second]
                let difference = stride(from: 0, to: a.count, by: 4).reduce(0.0) { sum, offset in
                    sum + (0..<3).reduce(0.0) { $0 + abs(Double(a[offset + $1]) - Double(b[offset + $1])) }
                } / Double(a.count / 4 * 3) / 255
                XCTAssertGreaterThan(difference, 0.015, "Two photo modes use the same material")
            }
        }
    }

    @MainActor
    func testEditorialFontsUseRegisteredBundledFaces() throws {
        let registered = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String])
        for family in ["InstrumentSerif", "DMSans", "DMMono"] {
            XCTAssertTrue(registered.contains { $0.contains(family) }, "No bundled registration for \(family)")
        }
        for name in ["InstrumentSerif-Regular", "InstrumentSerif-Italic", "DMSans-Regular",
                     "DMSans-Medium", "DMMono-Regular"] {
            let font = try XCTUnwrap(UIFont(name: name, size: 20), "Silent font fallback: \(name)")
            XCTAssertEqual(font.fontName, name)
        }
    }

    @MainActor
    func testEditorialPhotosRenderAuthoritativeMetadataAcrossOrientations() throws {
        let wholePanel = CGRect(origin: .zero, size: displaySize)
        for style in editorialStyles {
            for turns in [0, 1] {
                let original = try display(style, readout: readout(), quarterTurns: turns)
                let title = try display(style, readout: readout(title: "NIGHT TRAIN"), quarterTurns: turns)
                let artist = try display(style, readout: readout(artist: "EMBER CHOIR"), quarterTurns: turns)
                let time = try display(style, readout: readout(position: 83), quarterTurns: turns)
                let queue = try display(style, readout: readout(index: 7), quarterTurns: turns)
                for (label, changed) in [("title", title), ("artist", artist), ("time", time), ("queue", queue)] {
                    XCTAssertGreaterThan(try changedPixels(original, changed, in: wholePanel), 20,
                        "\(style.rawValue) did not visibly update \(label), turn \(turns)")
                }
                // The photography fills the panel. Inspect the complete frame;
                // these modes intentionally have no header/art/footer strip contract.
                let orientation: CGImagePropertyOrientation = turns == 0 ? .up : .left
                let originalCopy = try recognizedText(in: original.image, orientation: orientation)
                let originalLetters = letters(originalCopy)
                XCTAssertTrue(originalLetters.contains("RIVERSONG"), "\(style.rawValue): \(originalCopy)")
                XCTAssertTrue(originalLetters.contains("MARBLEBAND"), "\(style.rawValue): \(originalCopy)")
                XCTAssertTrue(originalCopy.replacingOccurrences(of: " ", with: "").contains("0:23"),
                    "Missing authoritative elapsed time in \(style.rawValue): \(originalCopy)")
                let nextCopy = try recognizedText(in: time.image, orientation: orientation)
                XCTAssertTrue(nextCopy.replacingOccurrences(of: " ", with: "").contains("1:23"),
                    "Changed elapsed time is unreadable in \(style.rawValue): \(nextCopy)")
            }
        }
    }

    @MainActor
    func testEditorialLongMetadataAndStateFallbacksStayInsideThePanel() throws {
        let title = "NIGHT 夜航信号 👩🏽‍🚀🌒 " + String(repeating: "漫长的夜空与海面", count: 12)
        let artist = "EMBER 合成测试音 🎻 " + String(repeating: "这是一段很长的艺人名称", count: 12)
        let padding: CGFloat = 12
        let outerSize = CGSize(width: displaySize.width + padding * 2, height: displaySize.height + padding * 2)
        for style in editorialStyles {
            for turns in [0, 1] {
                let content = legacyDisplay(style: style,
                    readout: readout(title: title, artist: artist), quarterTurns: turns)
                    .padding(padding).background(Color(red: 1, green: 0, blue: 1))
                let outer = try render(content, size: outerSize)
                let margins = [CGRect(x: 0, y: 0, width: outerSize.width, height: 8),
                    CGRect(x: 0, y: outerSize.height - 8, width: outerSize.width, height: 8),
                    CGRect(x: 0, y: 0, width: 8, height: outerSize.height),
                    CGRect(x: outerSize.width - 8, y: 0, width: 8, height: outerSize.height)]
                for margin in margins {
                    XCTAssertGreaterThan(try fraction(rgba(outer.cropped(to: margin))) { r, g, b, a in
                        r > 248 && g < 8 && b > 248 && a > 248
                    }, 0.999, "Metadata/photo escaped \(style.rawValue)'s viewport")
                }
                let panelRect = CGRect(origin: CGPoint(x: padding, y: padding), size: displaySize)
                let panel = try outer.cropped(to: panelRect)
                let shortTitle = try render(legacyDisplay(style: style,
                    readout: readout(title: "NIGHT", artist: artist), quarterTurns: turns)
                    .padding(padding).background(Color(red: 1, green: 0, blue: 1)), size: outerSize)
                let shortArtist = try render(legacyDisplay(style: style,
                    readout: readout(title: title, artist: "EMBER"), quarterTurns: turns)
                    .padding(padding).background(Color(red: 1, green: 0, blue: 1)), size: outerSize)
                XCTAssertGreaterThan(try changedPixels(outer, shortTitle, in: panelRect), 20,
                    "Long title is not drawn in \(style.rawValue), turn \(turns)")
                XCTAssertGreaterThan(try changedPixels(outer, shortArtist, in: panelRect), 20,
                    "Long artist is not drawn in \(style.rawValue), turn \(turns)")
                attach(panel, name: "editorial-\(style.rawValue)-long-unicode-turn-\(turns)")
            }
            let empty = try display(style, readout: .empty)
            XCTAssertTrue(letters(try recognizedText(in: empty.image)).contains("NOTAPE"))
            attach(empty.image, name: "editorial-\(style.rawValue)-empty-fallback")
            let preparing = try display(style, readout: readout(isPlaying: false, isPreparing: true))
            XCTAssertTrue(letters(try recognizedText(in: preparing.image)).contains("LOADING"))
            attach(preparing.image, name: "editorial-\(style.rawValue)-loading-fallback")
        }
        // The retained frames require visual review of Chinese/emoji shaping.
        // Mixed-script OCR misclassifies even Latin prefixes next to CJK/emoji.
        // Per-field pixel changes and the margin sentinel establish drawing/bounds;
        // the all-Latin test retains strict OCR, and these frames require glyph review.
    }

    private func readout(title: String = "RIVER SONG", artist: String = "MARBLE BAND",
                         position: Double = 23, duration: Double = 240,
                         index: Int = 0, count: Int = 9,
                         isPlaying: Bool = true, isPreparing: Bool = false) -> OneTapePlaybackReadout {
        OneTapePlaybackReadout(title: title, artist: artist, positionSeconds: position,
            durationSeconds: duration, isPlaying: isPlaying, isPreparing: isPreparing,
            trackIndex: index, trackCount: count)
    }

    @MainActor
    private func display(_ style: OneTapeAppearance.ScreenStyle, readout: OneTapePlaybackReadout,
                         quarterTurns: Int = 0) throws -> Snapshot {
        try render(legacyDisplay(style: style, readout: readout, quarterTurns: quarterTurns))
    }

    @MainActor
    @ViewBuilder
    private func legacyDisplay(style: OneTapeAppearance.ScreenStyle,
                               readout: OneTapePlaybackReadout, quarterTurns: Int = 0) -> some View {
        let tall = abs(quarterTurns % 2) == 1
        Group {
            if editorialStyles.contains(style) {
                OneTapeEditorialScreenFrame(style: style, readout: readout) {
                    OneTapePhotographicMaterial(style: style, phase: 0)
                }
            } else {
                OneTapeScreenFrame(style: style, readout: readout) {
                    ZStack {
                        Color(red: 218 / 255, green: 223 / 255, blue: 224 / 255)
                        if style == .name {
                            OneTapeNameSand(readout: readout)
                        } else if style == .fox {
                            // The private legacy character view's zero pose.
                            Image("OneTapeFoxIdle00").resizable().aspectRatio(contentMode: .fit)
                        } else {
                            OneTapeScreenCanvas(style: style, response: .silent, phase: 0)
                        }
                    }
                }
            }
        }
        .frame(width: tall ? 165.63 : 264.39, height: tall ? 264.39 : 165.63)
        .rotationEffect(.degrees(Double(quarterTurns) * 90))
        .frame(width: 264.39, height: 165.63)
        .clipShape(RoundedRectangle(cornerRadius: 2.5))
        .accessibilityHidden(true)
    }

    @MainActor
    private func scope(_ response: OneTapeScreenResponse) throws -> Snapshot {
        try render(OneTapeScreenFrame(style: .oscilloscope, readout: readout()) {
            OneTapeScreenCanvas(style: .oscilloscope, response: response, phase: 0)
        })
    }

    @MainActor
    private func render<Content: View>(_ content: Content, size: CGSize? = nil) throws -> Snapshot {
        let canvas = size ?? displaySize
        let renderer = ImageRenderer(content: content
            .frame(width: canvas.width, height: canvas.height)
            .environment(\.scenePhase, .inactive)
            .environment(\.dynamicTypeSize, .medium))
        // Four resource pixels per logical point make the small metadata suitable
        // for OCR; artwork geometry and authoritative media time remain unchanged.
        renderer.scale = 4
        let image = try XCTUnwrap(renderer.uiImage?.cgImage)
        return Snapshot(image: image, logicalSize: canvas)
    }

    private func changedPixels(_ first: Snapshot, _ second: Snapshot, in rect: CGRect) throws -> Int {
        let a = try rgba(first.cropped(to: rect))
        let b = try rgba(second.cropped(to: rect))
        XCTAssertEqual(a.count, b.count)
        return stride(from: 0, to: min(a.count, b.count), by: 4).filter { offset in
            (0..<4).contains { abs(Int(a[offset + $0]) - Int(b[offset + $0])) >= 4 }
        }.count
    }

    private func recognizedLetters(in image: CGImage) throws -> String {
        letters(try recognizedText(in: image))
    }

    private func letters(_ text: String) -> String {
        text.uppercased().replacingOccurrences(of: "[^A-Z]", with: "", options: .regularExpression)
    }

    private func recognizedText(in image: CGImage, orientation: CGImagePropertyOrientation = .up) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.01
        try VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:]).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
    }

    private func attach(_ image: CGImage, name: String) {
        let attachment = XCTAttachment(image: UIImage(cgImage: image))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func fraction(_ pixels: [UInt8], matching predicate: (Int, Int, Int, Int) -> Bool) -> Double {
        let count = pixels.count / 4
        guard count > 0 else { return 0 }
        let matches = stride(from: 0, to: pixels.count, by: 4).filter { offset in
            predicate(Int(pixels[offset]), Int(pixels[offset + 1]),
                      Int(pixels[offset + 2]), Int(pixels[offset + 3]))
        }.count
        return Double(matches) / Double(count)
    }

    private func rgba(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let succeeded = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(succeeded)
        return pixels
    }

    private func resizedRGBA(_ image: CGImage, width: Int, height: Int) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let succeeded = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        XCTAssertTrue(succeeded)
        return pixels
    }

    private struct Snapshot {
        let image: CGImage
        let logicalSize: CGSize

        func cropped(to rect: CGRect) throws -> CGImage {
            let scaleX = CGFloat(image.width) / logicalSize.width
            let scaleY = CGFloat(image.height) / logicalSize.height
            let pixels = CGRect(x: rect.minX * scaleX, y: rect.minY * scaleY,
                width: rect.width * scaleX, height: rect.height * scaleY).integral
            return try XCTUnwrap(image.cropping(to: pixels))
        }
    }
}
