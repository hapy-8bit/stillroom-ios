import XCTest
import SwiftUI
@testable import Stillroom

final class OneTapeBodyMaterialTests: XCTestCase {
    func testOldAppearanceRemainsReadableAndNewMaterialsRoundTrip() throws {
        let old = Data("""
        {"tapeStyle":"classic","printStyle":"brand","bodyStyle":"graphite",
         "screenStyle":"lcd","doodleStyle":"none","bodyColor":"green","glassEnabled":true}
        """.utf8)
        let restored = try JSONDecoder().decode(OneTapeAppearance.self, from: old)
        XCTAssertNil(restored.bodyMaterial)
        XCTAssertEqual(restored.bodyColor, .green)
        for material in OneTapeBodyMaterial.allCases {
            var appearance = restored
            appearance.selectBodyMaterial(material)
            XCTAssertEqual(appearance.bodyColor, .black)
            XCTAssertEqual(try JSONDecoder().decode(OneTapeAppearance.self,
                from: JSONEncoder().encode(appearance)), appearance)
            appearance.selectBodyStyle(.adaptive)
            XCTAssertNil(appearance.bodyMaterial)
            XCTAssertEqual(appearance.bodyStyle, .adaptive)
            XCTAssertEqual(appearance.tapeStyle, restored.tapeStyle)
        }
    }

    func testAllMaterialColorsKeepValidReadableKeyAndLCDPalettes() {
        for material in OneTapeBodyMaterial.allCases {
            for color in OneTapeAppearance.BodyColor.allCases {
                var appearance = OneTapeAppearance()
                appearance.bodyMaterial = material
                appearance.bodyColor = color
                let palette = material.palette(color: color)
                let transport = OneTapeTransportMaterial(appearance: appearance)
                XCTAssertEqual(transport.face, palette.key)
                XCTAssertEqual(transport.symbol, palette.ink)
                XCTAssertFalse(transport.usesOriginalArtwork)
                XCTAssertEqual(OneTapeLCDMaterial(appearance: appearance).background, palette.lcd)
                for rgb in [palette.shell, palette.key, palette.ink, palette.lcd] {
                    for component in [rgb.red, rgb.green, rgb.blue] {
                        XCTAssertTrue(component.isFinite && (0...1).contains(component))
                    }
                }
                let high = max(palette.key.luminance, palette.ink.luminance)
                let low = min(palette.key.luminance, palette.ink.luminance)
                XCTAssertGreaterThanOrEqual((high + 0.05) / (low + 0.05), 3)
            }
        }
    }

    @MainActor
    func testEveryMaterialProtectsCassetteContentsAndProducesDistinctPhysicalSurfaces() throws {
        let protected = [CGPoint(x: 150, y: 300), CGPoint(x: 260, y: 500)]
        var colors: [[Int]] = []
        for open in [true, false] {
            var original = OneTapeAppearance()
            original.glassOpen = open
            let baseline = try render(face(original), size: CGSize(width: 393, height: 852))
            for material in OneTapeBodyMaterial.allCases {
                var appearance = original
                appearance.bodyMaterial = material
                let image = try render(face(appearance), size: CGSize(width: 393, height: 852),
                                       name: "material-\(material.rawValue)-glass\(open)")
                for point in protected {
                    XCTAssertEqual(try pixel(image, at: point), try pixel(baseline, at: point),
                                   "Shell material reached cassette content: \(material)")
                }
                if open { colors.append(try pixel(image, at: CGPoint(x: 196, y: 638))) }
            }
        }
        for i in colors.indices {
            for j in colors.indices where j > i {
                let difference = zip(colors[i].prefix(3), colors[j].prefix(3))
                    .reduce(0) { $0 + abs($1.0 - $1.1) }
                XCTAssertGreaterThan(difference, 18, "Two materials have no visible shell difference")
            }
        }
    }

    @MainActor
    func testMaterialTextureIsStaticBetweenRepeatedDraws() throws {
        for material in OneTapeBodyMaterial.allCases {
            try autoreleasepool {
                var appearance = OneTapeAppearance()
                appearance.bodyMaterial = material
                let a = try render(OneTapeBodySurface(appearance: appearance), size: CGSize(width: 393, height: 852))
                let b = try render(OneTapeBodySurface(appearance: appearance), size: CGSize(width: 393, height: 852))
                XCTAssertEqual(try XCTUnwrap(a.dataProvider?.data) as Data,
                               try XCTUnwrap(b.dataProvider?.data) as Data,
                               "Surface grain must not flicker on playback updates: \(material)")
            }
        }
    }

    @MainActor
    func testLightingKeepsEveryNewMaterialKeyRimFixedInAllDirections() throws {
        for material in OneTapeBodyMaterial.allCases {
            var appearance = OneTapeAppearance()
            appearance.bodyMaterial = material
            for turns in [-1, 0, 1] {
                let off = try render(OneTapeTransportKeyVisual(appearance: appearance, action: .play,
                    illuminated: false, quarterTurns: turns), size: CGSize(width: 58, height: 58))
                let on = try render(OneTapeTransportKeyVisual(appearance: appearance, action: .play,
                    illuminated: true, quarterTurns: turns), size: CGSize(width: 58, height: 58))
                for angle in stride(from: 0.0, to: 2 * .pi, by: .pi / 12) {
                    for radius in [26.0, 28.0] {
                        let point = CGPoint(x: 29 + cos(angle) * radius, y: 29 + sin(angle) * radius)
                        XCTAssertEqual(try pixel(off, at: point), try pixel(on, at: point), material.rawValue)
                    }
                }
            }
        }
    }

    @MainActor
    private func face(_ appearance: OneTapeAppearance) -> some View {
        OneTapePlayerFace(appearance: appearance, 
            glassInteractionEnabled: false, onGlass: {}, onLCD: {}, 
            onTransport: { _ in }, onSetGlassOpen: { _ in })
    }

    @MainActor
    private func render<Content: View>(_ view: Content, size: CGSize, name: String? = nil) throws -> CGImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        if let name {
            let attachment = XCTAttachment(data: try XCTUnwrap(image.pngData()), uniformTypeIdentifier: "public.png")
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        return try XCTUnwrap(image.cgImage)
    }

    private func pixel(_ image: CGImage, at point: CGPoint) throws -> [Int] {
        let sample = try XCTUnwrap(image.cropping(to: CGRect(x: floor(point.x * 3),
            y: floor(point.y * 3), width: 1, height: 1)))
        var data = [UInt8](repeating: 0, count: 4)
        let drew = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        XCTAssertTrue(drew)
        return data.map(Int.init)
    }
}
