import XCTest
import SwiftUI
@testable import Stillroom

final class OneTapeTransportMaterialTests: XCTestCase {
    func testOnlyOriginalBlackUsesTheBlackPhotographAndExplicitColorWins() {
        XCTAssertTrue(OneTapeTransportMaterial(appearance: OneTapeAppearance()).usesOriginalArtwork)
        for style in OneTapeAppearance.BodyStyle.allCases {
            if style == .graphite { continue }
            var appearance = OneTapeAppearance()
            appearance.bodyStyle = style
            appearance.bodyColor = .white
            let white = OneTapeTransportMaterial(appearance: appearance)
            XCTAssertFalse(white.usesOriginalArtwork)
            XCTAssertEqual(white, material(color: .white))
        }
        for style in [OneTapeAppearance.BodyStyle.graphite, .adaptive, .cover] {
            var appearance = OneTapeAppearance()
            appearance.bodyStyle = style
            XCTAssertFalse(OneTapeTransportMaterial(appearance: appearance).usesOriginalArtwork)
        }
    }

    func testEveryCoordinatedFinishKeepsLegibleGlyphsAndValidComponents() {
        var finishes = OneTapeAppearance.BodyColor.allCases.map { material(color: $0) }
        for style in [OneTapeAppearance.BodyStyle.graphite, .adaptive, .cover] {
            var appearance = OneTapeAppearance()
            appearance.bodyStyle = style
            finishes.append(OneTapeTransportMaterial(appearance: appearance))
        }
        for finish in finishes {
            for rgb in [finish.face, finish.symbol] {
                for component in [rgb.red, rgb.green, rgb.blue] {
                    XCTAssertTrue(component.isFinite)
                    XCTAssertTrue((0...1).contains(component))
                }
            }
            let light = max(finish.face.luminance, finish.symbol.luminance)
            let dark = min(finish.face.luminance, finish.symbol.luminance)
            XCTAssertGreaterThanOrEqual((light + 0.05) / (dark + 0.05), 3)
        }
        XCTAssertGreaterThan(material(color: .white).face.luminance,
                             material(color: .navy).face.luminance + 0.4)
        XCTAssertNotEqual(material(color: .navy).face, material(color: .green).face)
    }

    @MainActor
    func testOriginalBlackPortraitRetainsPhotographedFacePixels() throws {
        let source = try XCTUnwrap(UIImage(named: "OneTapeBody")?.cgImage)
        let sourceScale = CGFloat(source.width) / 393
        for (index, action) in OneTapeTransportAction.allCases.enumerated() {
            let key = try render(OneTapeTransportKeyVisual(appearance: OneTapeAppearance(),
                action: action, illuminated: false, quarterTurns: 0),
                size: CGSize(width: 58, height: 58), name: "original-photo-\(action)")
            for point in [CGPoint(x: 29, y: 12), CGPoint(x: 12, y: 29), CGPoint(x: 29, y: 46)] {
                let sourcePoint = CGPoint(
                    x: OneTapeTransportGeometry.centerX + (point.x - 29) / OneTapeTransportGeometry.visualScale,
                    y: OneTapeTransportGeometry.sourceCentersY[index]
                        + (point.y - 29) / OneTapeTransportGeometry.visualScale)
                let sample = try XCTUnwrap(source.cropping(to: CGRect(
                    x: floor(sourcePoint.x * sourceScale), y: floor(sourcePoint.y * sourceScale),
                    width: 1, height: 1)))
                let expected = try bytes(sample).map(Int.init)
                let actual = try pixel(key, point: point)
                for channel in 0..<3 {
                    XCTAssertEqual(Double(actual[channel]), Double(expected[channel]), accuracy: 12,
                        "Original photograph changed: \(action), \(point)")
                }
            }
        }
    }

    @MainActor
    func testLightFinishesStayLightForEveryKeyOrientationAndPlayingOverlay() throws {
        for color in [OneTapeAppearance.BodyColor.white, .dove] {
            var appearance = OneTapeAppearance()
            appearance.bodyColor = color
            for action in OneTapeTransportAction.allCases {
                for turns in [-1, 0, 1] {
                    for lit in action == .play ? [false, true] : [false] {
                        let label = "\(color.rawValue)-\(action)-turn\(turns)-lit\(lit)"
                        let image = try render(OneTapeTransportKeyVisual(appearance: appearance,
                            action: action, illuminated: lit, quarterTurns: turns),
                            size: CGSize(width: 58, height: 58), name: label)
                        // Outside the glyph bounds but inside the face. A
                        // legacy black image or black orientation patch fails.
                        let face = try pixel(image, point: CGPoint(x: 29, y: 12))
                        XCTAssertGreaterThan(face[0], 140, label)
                        XCTAssertGreaterThan(face[1], 140, label)
                        XCTAssertGreaterThan(face[2], 135, label)
                        XCTAssertLessThan(try pixel(image, point: .zero)[3], 10, label)
                    }
                }
            }
        }
    }

    @MainActor
    func testGraphiteAndColoredBodiesProduceDistinctRealKeyPixels() throws {
        let cases: [(OneTapeAppearance.BodyStyle, OneTapeAppearance.BodyColor)] = [
            (.black, .black), (.black, .white),
            (.black, .navy), (.black, .green), (.black, .cognac)
        ]
        var faceColors: [[Int]] = []
        for (style, color) in cases {
            var appearance = OneTapeAppearance()
            appearance.bodyStyle = style
            appearance.bodyColor = color
            let image = try render(OneTapeTransportKeyVisual(appearance: appearance,
                action: .previous, illuminated: false, quarterTurns: 0),
                size: CGSize(width: 58, height: 58), name: "finish-\(style)-\(color)")
            faceColors.append(try pixel(image, point: CGPoint(x: 29, y: 12)))
        }
        for index in 1..<faceColors.count {
            let difference = zip(faceColors[0].prefix(3), faceColors[index].prefix(3))
                .reduce(0) { $0 + abs($1.0 - $1.1) }
            XCTAssertGreaterThan(difference, 65, "Finish still uses original black: \(cases[index])")
        }
        XCTAssertGreaterThan(faceColors[2][2] - faceColors[2][0], 20, "Navy lost its hue")
        XCTAssertGreaterThan(faceColors[3][1] - faceColors[3][0], 20, "Green lost its hue")
        XCTAssertGreaterThan(faceColors[4][0] - faceColors[4][2], 30, "Cognac lost its hue")
    }

    @MainActor
    func testLampChangesTheActualColoredPlayFaceWithoutReplacingTheFinish() throws {
        var appearance = OneTapeAppearance()
        appearance.bodyColor = .white
        let off = try render(OneTapeTransportKeyVisual(appearance: appearance,
            action: .play, illuminated: false, quarterTurns: 0),
            size: CGSize(width: 58, height: 58), name: "white-play-unlit")
        let on = try render(OneTapeTransportKeyVisual(appearance: appearance,
            action: .play, illuminated: true, quarterTurns: 0),
            size: CGSize(width: 58, height: 58), name: "white-play-lit")
        let unlit = try bytes(off)
        let lit = try bytes(on)
        let changed = stride(from: 0, to: unlit.count, by: 4).filter { index in
            (0..<3).contains { abs(Int(unlit[index + $0]) - Int(lit[index + $0])) > 3 }
        }.count
        XCTAssertGreaterThan(changed, 150, "Playing does not visibly illuminate the finish")
        XCTAssertGreaterThan(try pixel(on, point: CGPoint(x: 29, y: 12))[0], 170)
    }

    @MainActor
    func testShellClearsAndTintsTheWholeOldButtonFootprint() throws {
        var appearance = OneTapeAppearance()
        appearance.bodyColor = .white
        let image = try render(OneTapeBodySurface(appearance: appearance),
            size: CGSize(width: 393, height: 852), name: "white-cleared-button-shell")
        for y in OneTapeTransportGeometry.sourceCentersY {
            for x in [OneTapeTransportGeometry.centerX - 20,
                      OneTapeTransportGeometry.centerX,
                      OneTapeTransportGeometry.centerX + 20] {
                let shell = try pixel(image, point: CGPoint(x: x, y: y))
                XCTAssertGreaterThan(shell[0], 145, "Old black button patch at \(x),\(y)")
                XCTAssertGreaterThan(shell[1], 145)
                XCTAssertGreaterThan(shell[2], 140)
            }
        }
    }

    private func material(color: OneTapeAppearance.BodyColor) -> OneTapeTransportMaterial {
        var appearance = OneTapeAppearance()
        appearance.bodyColor = color
        return OneTapeTransportMaterial(appearance: appearance)
    }

    @MainActor
    private func render<Content: View>(_ view: Content, size: CGSize, name: String) throws -> CGImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, name)
        let pixels = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(pixels.width, Int(size.width * 3))
        XCTAssertEqual(pixels.height, Int(size.height * 3))
        let attachment = XCTAttachment(data: try XCTUnwrap(image.pngData()),
                                       uniformTypeIdentifier: "public.png")
        attachment.name = "transport-material-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        return pixels
    }

    private func pixel(_ image: CGImage, point: CGPoint) throws -> [Int] {
        let x = min(image.width - 1, max(0, Int(point.x * 3)))
        let y = min(image.height - 1, max(0, Int(point.y * 3)))
        let sample = try XCTUnwrap(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
        return try bytes(sample).map(Int.init)
    }

    private func bytes(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drew = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width,
                height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(drew)
        return bytes
    }
}
