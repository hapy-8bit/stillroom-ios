import XCTest
import SwiftUI
@testable import Stillroom

final class OneTapeBodyFinishRenderingTests: XCTestCase {
    @MainActor
    func testBodyMaterialsNeverPaintInsideTheCompleteCassetteFrame() throws {
        // The protected module includes its fixed rim and dark backing, not
        // only each tape's plastic silhouette. Points are in player design units.
        let protected = [CGPoint(x: 20.5, y: 350), CGPoint(x: 372.5, y: 350),
                         CGPoint(x: 196, y: 69.5), CGPoint(x: 196, y: 620.5),
                         CGPoint(x: 26, y: 350), CGPoint(x: 367, y: 350),
                         CGPoint(x: 150, y: 300), CGPoint(x: 260, y: 500)]
        for tape in OneTapeAppearance.TapeStyle.allCases {
            for open in [false, true] {
                var baseline = OneTapeAppearance()
                baseline.tapeStyle = tape
                baseline.glassOpen = open
                let original = try render(baseline, name: "protected-frame-original", attach: false)
                var finishes = OneTapeBodyMaterial.allCases.map { material in
                    var value = baseline
                    value.bodyMaterial = material
                    return value
                }
                finishes += [OneTapeAppearance.BodyStyle.graphite, .cover].map { style in
                    var value = baseline
                    value.bodyStyle = style
                    return value
                }
                var white = baseline
                white.bodyColor = .white
                finishes.append(white)
                for appearance in finishes {
                    try autoreleasepool {
                        let name = "protected-frame-\(tape)-\(appearance.bodyMaterial?.rawValue ?? appearance.bodyStyle.rawValue)-glass\(open)"
                        let image = try render(appearance, name: name,
                            attach: tape == .facet && appearance.bodyColor == .black)
                        for point in protected {
                            let actual = try rgb(image, at: point)
                            let expected = try rgb(original, at: point)
                            // Filtered shell edges can round by one 8-bit level
                            // when SwiftUI composites an additional body layer.
                            // Keep the tolerance below any visible material tint.
                            let difference = zip(actual, expected).map { abs($0 - $1) }.max() ?? 0
                            XCTAssertLessThanOrEqual(difference, 1,
                                "Body material crossed the cassette frame at \(point): \(name)")
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func testEveryFinishReachesPocketLCDAndBothOuterEnds() throws {
        let samples = [CGPoint(x: 18, y: 350), CGPoint(x: 190, y: 67),
                       CGPoint(x: 190, y: 624), CGPoint(x: 94, y: 730),
                       CGPoint(x: 370, y: 730), CGPoint(x: 200, y: 823),
                       CGPoint(x: 56, y: 3), CGPoint(x: 12, y: 25),
                       CGPoint(x: 56, y: 849), CGPoint(x: 12, y: 827),
                       CGPoint(x: 50, y: 30)]
        let original = try render(OneTapeAppearance(), name: "finish-original-black")
        var finishes = OneTapeAppearance.BodyColor.allCases.filter { $0 != .black }.map { color in
            var appearance = OneTapeAppearance()
            appearance.bodyColor = color
            return appearance
        }
        finishes += OneTapeAppearance.BodyStyle.allCases.filter { $0 != .black }.map { style in
            var appearance = OneTapeAppearance()
            appearance.bodyStyle = style
            return appearance
        }
        for appearance in finishes {
            try autoreleasepool {
                let name = "finish-\(appearance.bodyStyle.rawValue)-\(appearance.bodyColor.rawValue)"
                let image = try render(appearance, name: name)
                for point in samples {
                    let before = try rgb(original, at: point)
                    let after = try rgb(image, at: point)
                    let difference = zip(before, after).reduce(0) { $0 + abs($1.0 - $1.1) }
                    XCTAssertGreaterThan(difference, 60, "Original black remains at \(point) in \(name)")
                }
            }
        }
    }

    @MainActor
    func testBodyChangeProtectsActualCassetteAndScreenWithGlassOpenOrClosed() throws {
        let interior = [CGPoint(x: 150, y: 300), CGPoint(x: 260, y: 500),
                        CGPoint(x: 115, y: 675), CGPoint(x: 220, y: 730),
                        CGPoint(x: 345, y: 800)]
        for tape in [OneTapeAppearance.TapeStyle.classic, .strata] {
            for open in [false, true] {
                try autoreleasepool {
                    var appearance = OneTapeAppearance()
                    appearance.tapeStyle = tape
                    appearance.glassOpen = open
                    let original = try render(appearance, name: "interior-black-\(tape)-\(open)", attach: false)
                    appearance.bodyColor = .white
                    let white = try render(appearance, name: "interior-white-\(tape)-\(open)")
                    for point in interior {
                        let before = try rgb(original, at: point)
                        let after = try rgb(white, at: point)
                        for (a, b) in zip(before, after) {
                            XCTAssertEqual(Double(a), Double(b), accuracy: 2, "Body tint reached content at \(point)")
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func testWindowRemaindersUseSelectedFinishInsteadOfFixedGrey() throws {
        var appearance = OneTapeAppearance()
        appearance.bodyColor = .white
        let expected = OneTapeTransportMaterial(appearance: appearance).face
        for (window, point) in [(CGSize(width: 393, height: 900), CGPoint(x: 196, y: 2)),
                                (CGSize(width: 420, height: 852), CGPoint(x: 2, y: 426))] {
            let image = try render(appearance, name: "finish-window-\(window)", window: window)
            let pixel = try rgb(image, at: point)
            for (value, component) in zip(pixel, [expected.red, expected.green, expected.blue]) {
                XCTAssertEqual(Double(value), component * 255, accuracy: 3)
            }
        }
    }

    @MainActor
    private func render(_ appearance: OneTapeAppearance, name: String,
                        window: CGSize = CGSize(width: 393, height: 852), attach: Bool = true) throws -> CGImage {
        let face = OneTapePlayerFace(appearance: appearance, 
            glassInteractionEnabled: false, onGlass: {}, onLCD: {}, 
            onTransport: { _ in }, onSetGlassOpen: { _ in })
        let renderer = ImageRenderer(content: face.frame(width: window.width, height: window.height)
            .environment(\.colorScheme, .dark))
        renderer.proposedSize = ProposedViewSize(window)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        if attach {
            let attachment = XCTAttachment(data: try XCTUnwrap(image.pngData()), uniformTypeIdentifier: "public.png")
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        return try XCTUnwrap(image.cgImage)
    }

    private func rgb(_ image: CGImage, at point: CGPoint) throws -> [Int] {
        let pixel = try XCTUnwrap(image.cropping(to: CGRect(x: floor(point.x * 3),
            y: floor(point.y * 3), width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        let drew = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        XCTAssertTrue(drew)
        return bytes.prefix(3).map(Int.init)
    }
}
