import XCTest
import SwiftUI
@testable import Stillroom

final class OneTapeBodyStyleTests: XCTestCase {
    typealias RGB = OneTapeTransportMaterial.RGB

    func testChoosingAnotherMaterialRemovesThePreviousManualOverride() {
        for style in OneTapeAppearance.BodyStyle.allCases {
            var appearance = OneTapeAppearance()
            appearance.bodyColor = .cognac
            appearance.selectBodyStyle(style)
            XCTAssertEqual(appearance.bodyStyle, style)
            XCTAssertEqual(appearance.bodyColor, .black)
        }
    }

    @MainActor
    func testSamplerReadsRealCoverHueAndDoesNotInventColorForMissingArt() throws {
        XCTAssertNil(OneTapeArtworkColorSampler.color(from: nil))
        let transparent = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { _ in }
        XCTAssertNil(OneTapeArtworkColorSampler.color(from: transparent))
        for color in [UIColor.red, UIColor.blue, UIColor.green] {
            let sample = try XCTUnwrap(OneTapeArtworkColorSampler.color(from: cover(color)))
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            XCTAssertEqual(sample.red, Double(red), accuracy: 0.01)
            XCTAssertEqual(sample.green, Double(green), accuracy: 0.01)
            XCTAssertEqual(sample.blue, Double(blue), accuracy: 0.01)
        }
    }

    @MainActor
    func testAdaptiveShellKeysAndLCDChangeWithCoverAndReturnToFallback() throws {
        var appearance = OneTapeAppearance()
        appearance.bodyStyle = .adaptive
        let colors = try [UIColor(red: 0.75, green: 0.18, blue: 0.12, alpha: 1),
                          UIColor(red: 0.10, green: 0.28, blue: 0.75, alpha: 1)].map {
            try XCTUnwrap(OneTapeArtworkColorSampler.color(from: cover($0)))
        }
        var images: [CGImage] = []
        for color in colors {
            let face = OneTapePlayerFace(appearance: appearance, 
                artworkColor: color, glassInteractionEnabled: false, onGlass: {}, onLCD: {},
                onTransport: { _ in }, onSetGlassOpen: { _ in })
            images.append(try render(face, size: CGSize(width: 393, height: 852)))
        }
        for point in [CGPoint(x: 190, y: 35), CGPoint(x: 48, y: 714), CGPoint(x: 350, y: 675)] {
            let red = try pixel(images[0], at: point)
            let blue = try pixel(images[1], at: point)
            XCTAssertGreaterThan(red[0] - red[2], 15, "Red cover lost at \(point)")
            XCTAssertGreaterThan(blue[2] - blue[0], 15, "Blue cover lost at \(point)")
        }
        XCTAssertNotEqual(OneTapeLCDMaterial(appearance: appearance, artworkColor: colors[0]),
                          OneTapeLCDMaterial(appearance: appearance, artworkColor: colors[1]))
        XCTAssertEqual(OneTapeTransportMaterial(appearance: appearance).face,
                       RGB(0.28, 0.49, 0.48))
        appearance.bodyColor = .white
        XCTAssertEqual(OneTapeTransportMaterial(appearance: appearance, artworkColor: colors[0]),
                       OneTapeTransportMaterial(appearance: appearance, artworkColor: colors[1]))
    }

    @MainActor
    func testGraphiteKeepsDarkPhotographicKeysAndRedPlayInEveryOrientationAndState() throws {
        var appearance = OneTapeAppearance()
        appearance.bodyStyle = .graphite
        for turns in [-1, 0, 1] {
            for lit in [false, true] {
                let image = try render(OneTapeTransportKeyVisual(appearance: appearance,
                    action: .play, illuminated: lit, quarterTurns: turns), size: CGSize(width: 58, height: 58))
                let center = try pixel(image, at: CGPoint(x: 29, y: 29))
                XCTAssertGreaterThan(center[0], center[1] * 2)
                XCTAssertGreaterThan(center[0], center[2] * 2)
                XCTAssertLessThan(try pixel(image, at: CGPoint(x: 14, y: 30))[0], 100)
            }
        }
    }

    @MainActor
    func testPlayingNeverChangesTheOuterRimOrPaddingPixels() throws {
        for style in OneTapeAppearance.BodyStyle.allCases {
            var appearance = OneTapeAppearance()
            appearance.bodyStyle = style
            for turns in [-1, 0, 1] {
                let off = try render(OneTapeTransportKeyVisual(appearance: appearance,
                    action: .play, illuminated: false, quarterTurns: turns), size: CGSize(width: 58, height: 58))
                let on = try render(OneTapeTransportKeyVisual(appearance: appearance,
                    action: .play, illuminated: true, quarterTurns: turns), size: CGSize(width: 58, height: 58))
                for angle in stride(from: 0.0, to: 2 * .pi, by: .pi / 16) {
                    for radius in [26.0, 28.0] {
                        let point = CGPoint(x: 29 + cos(angle) * radius, y: 29 + sin(angle) * radius)
                        XCTAssertEqual(try pixel(off, at: point), try pixel(on, at: point),
                                       "Playing enlarged \(style) at \(point)")
                    }
                }
                XCTAssertNotEqual(try pixel(off, at: CGPoint(x: 25, y: 17)),
                                  try pixel(on, at: CGPoint(x: 25, y: 17)), "Lamp must still light")
            }
        }
    }

    @MainActor
    private func cover(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
    }

    @MainActor
    private func render<Content: View>(_ content: Content, size: CGSize) throws -> CGImage {
        let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(data: try XCTUnwrap(image.pngData()), uniformTypeIdentifier: "public.png")
        attachment.name = "body-style-render"
        attachment.lifetime = .keepAlways
        add(attachment)
        return try XCTUnwrap(image.cgImage)
    }

    private func pixel(_ image: CGImage, at point: CGPoint) throws -> [Int] {
        let sample = try XCTUnwrap(image.cropping(to: CGRect(x: floor(point.x * 3),
            y: floor(point.y * 3), width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        let drew = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        XCTAssertTrue(drew)
        return bytes.map(Int.init)
    }
}
