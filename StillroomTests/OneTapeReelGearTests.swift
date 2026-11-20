import XCTest
import SwiftUI
import UIKit
@testable import Stillroom

final class OneTapeReelGearTests: XCTestCase {
    func testAppearanceDefaultsToNilReelColorAndDecodesLegacyJSON() throws {
        XCTAssertNil(OneTapeAppearance().reelColor)

        let baseline = OneTapeAppearance()
        let fullData = try JSONEncoder().encode(baseline)
        var rawObject = try XCTUnwrap(JSONSerialization.jsonObject(with: fullData) as? [String: Any])
        rawObject.removeValue(forKey: "reelColor")
        let legacyData = try JSONSerialization.data(withJSONObject: rawObject)
        let decoded = try JSONDecoder().decode(OneTapeAppearance.self, from: legacyData)
        XCTAssertNil(decoded.reelColor)
        XCTAssertEqual(decoded.tapeStyle, baseline.tapeStyle)
    }

    func testReelColorRoundTripsInPreferencesAndTabOrderIncludesReel() throws {
        let suite = "OneTapeReelGearTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = OneTapeAppearancePreferences(defaults: defaults)

        for color in OneTapeAppearance.ReelColor.allCases {
            var appearance = OneTapeAppearance()
            appearance.reelColor = color
            try preferences.save(appearance)
            XCTAssertEqual(try preferences.load().reelColor, color)
        }

        XCTAssertEqual(
            OneTapeCustomizationTab.allCases,
            [.tape, .print, .reel, .body, .screen]
        )
        XCTAssertEqual(OneTapeCustomizationTab.reel.title, "卷盘")
        XCTAssertEqual(OneTapeCustomizationTab.reel.panelHeightFraction, 1)
    }

    @MainActor
    func testSelectingReelColorDyesClassicHubsAndPreservesRotation() throws {
        var baseAppearance = OneTapeAppearance()
        baseAppearance.tapeStyle = .classic
        baseAppearance.reelColor = .crimson

        let red = try render(OneTapeCassetteArtwork(
            appearance: baseAppearance,
            supplyAngle: .degrees(0),
            takeupAngle: .degrees(0),
            tapeProgress: 0.4
        ))

        baseAppearance.reelColor = .blue
        let blue = try render(OneTapeCassetteArtwork(
            appearance: baseAppearance,
            supplyAngle: .degrees(0),
            takeupAngle: .degrees(0),
            tapeProgress: 0.4
        ))

        let supplyRect = CGRect(x: 164, y: 132, width: 80, height: 80)
        let takeupRect = CGRect(x: 164, y: 364, width: 80, height: 80)

        XCTAssertGreaterThan(try changedPixels(red, blue, in: supplyRect), 250,
            "Supply hub gear collar did not change color between crimson and blue")
        XCTAssertGreaterThan(try changedPixels(red, blue, in: takeupRect), 250,
            "Take-up hub gear collar did not change color between crimson and blue")

        let rotatedBlue = try render(OneTapeCassetteArtwork(
            appearance: baseAppearance,
            supplyAngle: .degrees(18),
            takeupAngle: .degrees(14),
            tapeProgress: 0.4
        ))

        XCTAssertGreaterThan(try changedPixels(blue, rotatedBlue, in: supplyRect), 40,
            "Supply hub gear collar did not rotate with supplyAngle")
        XCTAssertGreaterThan(try changedPixels(blue, rotatedBlue, in: takeupRect), 40,
            "Take-up hub gear collar did not rotate with takeupAngle")
    }

    @MainActor
    func testSelectingReelColorDyesAllTapeStylesAndPreservesRotation() throws {
        let supplyRect = CGRect(x: 164, y: 132, width: 80, height: 80)
        let takeupRect = CGRect(x: 164, y: 364, width: 80, height: 80)

        for style in OneTapeAppearance.TapeStyle.allCases {
            var baseAppearance = OneTapeAppearance()
            baseAppearance.tapeStyle = style
            baseAppearance.reelColor = .crimson

            let red = try render(OneTapeCassetteArtwork(
                appearance: baseAppearance,
                supplyAngle: .degrees(0),
                takeupAngle: .degrees(0),
                tapeProgress: 0.4
            ))

            baseAppearance.reelColor = .blue
            let blue = try render(OneTapeCassetteArtwork(
                appearance: baseAppearance,
                supplyAngle: .degrees(0),
                takeupAngle: .degrees(0),
                tapeProgress: 0.4
            ))

            let supplyDelta = try changedPixels(red, blue, in: supplyRect)
            let takeupDelta = try changedPixels(red, blue, in: takeupRect)
            XCTAssertGreaterThan(supplyDelta, 250,
                "Supply gear collar did not visibly dye for \(style.rawValue): \(supplyDelta)")
            XCTAssertGreaterThan(takeupDelta, 250,
                "Take-up gear collar did not visibly dye for \(style.rawValue): \(takeupDelta)")

            let rotatedBlue = try render(OneTapeCassetteArtwork(
                appearance: baseAppearance,
                supplyAngle: .degrees(18),
                takeupAngle: .degrees(14),
                tapeProgress: 0.4
            ))

            XCTAssertGreaterThan(try changedPixels(blue, rotatedBlue, in: supplyRect), 40,
                "Supply gear collar did not rotate for \(style.rawValue)")
            XCTAssertGreaterThan(try changedPixels(blue, rotatedBlue, in: takeupRect), 40,
                "Take-up gear collar did not rotate for \(style.rawValue)")

            // Verify central steel axle pin is rendered solidly at both spindle centers (not hollow).
            for (name, center) in [("supply", OneTapeCassetteStandard.portraitSupplyCenter),
                                   ("takeup", OneTapeCassetteStandard.portraitTakeupCenter)] {
                let axle = try meanRGB(blue, at: center, radius: 1.5)
                XCTAssertGreaterThan(axle.luminance, 95,
                    "Missing central axle pin at \(name) for \(style.rawValue): \(axle)")
            }

            let attachment = XCTAttachment(image: UIImage(cgImage: blue))
            attachment.name = "repaired-\(style.rawValue)-blue"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testFieldNotesWindowIsSingleUnifiedApertureAndSilverOvalAvoidsOrangeClash() throws {
        // Verify fieldNotes window path connects both reel circles cleanly with no stroke crossing hubs.
        let windowPath = OneTapeBespokeGeometry.landscapeWindow(for: .fieldNotes)
        XCTAssertTrue(windowPath.contains(OneTapeBespokeGeometry.supply))
        XCTAssertTrue(windowPath.contains(OneTapeBespokeGeometry.takeup))
        // Midpoint between supply and axle edge along y = supply.y should be strictly inside the unioned path.
        let innerEdgePoint = CGPoint(x: OneTapeBespokeGeometry.supply.x + 24, y: OneTapeBespokeGeometry.supply.y)
        XCTAssertTrue(windowPath.contains(innerEdgePoint))

        // Verify silverOval with blue reelColor replaces the orange lock ring with neutral metal.
        var appearance = OneTapeAppearance()
        appearance.tapeStyle = .silverOval
        appearance.reelColor = .blue
        let blueSilver = try render(OneTapeCassetteArtwork(
            appearance: appearance,
            supplyAngle: .degrees(12),
            takeupAngle: .degrees(24),
            tapeProgress: 0.35
        ))
        // Sample the lock-ring annulus around 30pt above portrait supply center (x: 204.01, y: 171.81 - 30).
        let lockRingSample = try meanRGB(blueSilver, at: CGPoint(x: 204.01, y: 141.81), radius: 1.5)
        XCTAssertLessThan(Int(lockRingSample.r) - Int(lockRingSample.b), 35,
            "SilverOval lock ring remained orange instead of neutralizing for custom reelColor: \(lockRingSample)")
    }

    private func meanRGB(_ image: CGImage, at logicalPoint: CGPoint, radius: CGFloat) throws -> (r: UInt8, g: UInt8, b: UInt8, luminance: Int) {
        let scale = CGFloat(image.height) / 576
        let rect = CGRect(
            x: (logicalPoint.x - radius) * scale,
            y: (logicalPoint.y - radius) * scale,
            width: radius * 2 * scale,
            height: radius * 2 * scale
        ).integral
        let values = try rgba(try XCTUnwrap(image.cropping(to: rect)))
        let count = max(1, values.count / 4)
        var rSum = 0, gSum = 0, bSum = 0
        for i in stride(from: 0, to: values.count, by: 4) {
            rSum += Int(values[i])
            gSum += Int(values[i + 1])
            bSum += Int(values[i + 2])
        }
        let r = UInt8(rSum / count)
        let g = UInt8(gSum / count)
        let b = UInt8(bSum / count)
        return (r, g, b, (Int(r) + Int(g) + Int(b)) / 3)
    }

    @MainActor
    private func render<Content: View>(_ content: Content) throws -> CGImage {
        let renderer = ImageRenderer(content: content.frame(width: 376.33, height: 576))
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
            (0..<4).contains { abs(Int(a[offset + $0]) - Int(b[offset + $0])) >= 4 }
        }.count
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
