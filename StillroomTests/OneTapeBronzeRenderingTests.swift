import XCTest
import SwiftUI
import UIKit
@testable import Stillroom

/// These checks exercise the product's own bronze artwork. They do not establish
/// the reference app's motion, frame rate or physical-device rendering quality.
final class OneTapeBronzeRenderingTests: XCTestCase {
    @MainActor
    func testPrintedWordmarkUsesTheBundledRegisteredRacingFont() throws {
        XCTAssertNotNil(Bundle.main.url(forResource: "RacingSansOne-Regular", withExtension: "ttf"))
        let registeredFonts = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String])
        XCTAssertTrue(registeredFonts.contains("RacingSansOne-Regular.ttf"))
        let font = try XCTUnwrap(UIFont(name: "RacingSansOne-Regular", size: 46))
        XCTAssertEqual(font.fontName, "RacingSansOne-Regular")
        XCTAssertEqual(font.familyName, "Racing Sans One")
    }

    func testBronzePreferenceRoundTripKeepsIndependentChoicesAndTheLegacyGlassKey() throws {
        let suite = "OneTapeBronzeRenderingTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = OneTapeAppearancePreferences(defaults: defaults)
        var appearance = OneTapeAppearance()
        appearance.tapeStyle = .bronze
        appearance.printStyle = .blank
        appearance.bodyStyle = .graphite
        appearance.bodyColor = .green
        appearance.screenStyle = .water
        appearance.doodleStyle = .wild
        appearance.glassOpen = false
        try preferences.save(appearance)
        XCTAssertEqual(try preferences.load(), appearance)
        let data = try XCTUnwrap(defaults.data(forKey: "oneTape.appearance.v1"))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(record["tapeStyle"] as? String, "bronze")
        XCTAssertEqual(record["glassEnabled"] as? Bool, false)
        XCTAssertNil(record["glassOpen"])
    }

    @MainActor
    func testBothVisibleReelCoresRespondToIndependentSmallAngles() throws {
        let still = try render(OneTapeBronzeCassette(supplyAngle: .degrees(0),
            takeupAngle: .degrees(0), tapeProgress: 0.5))
        let advanced = try render(OneTapeBronzeCassette(supplyAngle: .degrees(0.47),
            takeupAngle: .degrees(0.17), tapeProgress: 0.5))
        // Logical-point regions surround the two visible cores. Comparing only
        // these regions catches a static shell accidentally covering either reel.
        let supply = CGRect(x: 142, y: 110, width: 124, height: 124)
        let takeup = CGRect(x: 174, y: 374, width: 60, height: 60)
        XCTAssertGreaterThan(try changedPixels(still, advanced, in: supply), 12,
            "The visible supply core did not respond to its angle")
        XCTAssertGreaterThan(try changedPixels(still, advanced, in: takeup), 6,
            "The visible take-up core did not respond to its angle")
    }

    @MainActor
    func testTapeProgressChangesTheVisibleWindowDrawing() throws {
        let early = try render(OneTapeBronzeCassette(supplyAngle: .degrees(0),
            takeupAngle: .degrees(0), tapeProgress: 0.05))
        let late = try render(OneTapeBronzeCassette(supplyAngle: .degrees(0),
            takeupAngle: .degrees(0), tapeProgress: 0.95))
        // The fixed dial covers the inner sixty points. Include the surrounding
        // wedge, where the changing tape pack remains visible outside that dial.
        let window = CGRect(x: 102, y: 48, width: 208, height: 304)
        let changed = try changedPixels(early, late, in: window)
        XCTAssertGreaterThan(changed, 100, "The visible tape amount remained static")
    }

    @MainActor
    func testPrintMaskLeavesTheWedgeAndSocketClearButKeepsTheBlankPanelPrintable() throws {
        let image = try render(OneTapeBronzePrintMask().fill(.white))
        // Representative interior points are deliberately away from antialiased
        // edges. Alpha checks verify the real rendered mask, without freezing art.
        let clearPoints = [CGPoint(x: 204.02, y: 171.80), CGPoint(x: 204.02, y: 403.93),
                           CGPoint(x: 204.13, y: 130.63), CGPoint(x: 78.57, y: 288.10)]
        for point in clearPoints {
            XCTAssertLessThan(try meanAlpha(image, at: point), 5, "Blocked opening at \(point)")
        }
        let printablePoints = [CGPoint(x: 267.97, y: 492.39), CGPoint(x: 342.45, y: 300.87)]
        for point in printablePoints {
            XCTAssertGreaterThan(try meanAlpha(image, at: point), 250, "Missing printable panel at \(point)")
        }
    }

    @MainActor
    private func render<Content: View>(_ content: Content) throws -> CGImage {
        let renderer = ImageRenderer(content: content.frame(width: 376.33, height: 576))
        // Resource pixels enter only at this rendering boundary. Higher sampling
        // resolves sub-degree angle changes without claiming device frame timing.
        renderer.scale = 3
        return try XCTUnwrap(renderer.uiImage?.cgImage)
    }

    private func changedPixels(_ first: CGImage, _ second: CGImage, in logicalRect: CGRect) throws -> Int {
        XCTAssertEqual(first.width, second.width)
        XCTAssertEqual(first.height, second.height)
        let scale = CGFloat(first.height) / 576
        let pixelRect = CGRect(x: logicalRect.minX * scale, y: logicalRect.minY * scale,
            width: logicalRect.width * scale, height: logicalRect.height * scale).integral
        let a = try rgba(try XCTUnwrap(first.cropping(to: pixelRect)))
        let b = try rgba(try XCTUnwrap(second.cropping(to: pixelRect)))
        XCTAssertEqual(a.count, b.count)
        return stride(from: 0, to: min(a.count, b.count), by: 4).filter { offset in
            (0..<4).contains { abs(Int(a[offset + $0]) - Int(b[offset + $0])) >= 3 }
        }.count
    }

    private func meanAlpha(_ image: CGImage, at point: CGPoint) throws -> Double {
        let scale = CGFloat(image.height) / 576
        let sample = CGRect(x: (point.x * scale).rounded() - 1,
            y: (point.y * scale).rounded() - 1, width: 3, height: 3)
        let pixels = try rgba(try XCTUnwrap(image.cropping(to: sample)))
        let alphas = stride(from: 3, to: pixels.count, by: 4).map { Double(pixels[$0]) }
        return alphas.reduce(0, +) / Double(alphas.count)
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
}
