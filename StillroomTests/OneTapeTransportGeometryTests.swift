import XCTest
import SwiftUI
@testable import Stillroom

final class OneTapeTransportGeometryTests: XCTestCase {
    func testTransportTargetsKeepMinimumSizeAndDoNotOverlapAcrossPhoneWindows() {
        let windows = [CGSize(width: 320, height: 568), CGSize(width: 375, height: 667),
                       CGSize(width: 393, height: 852), CGSize(width: 402, height: 874),
                       CGSize(width: 430, height: 932)]
        for window in windows {
            let scale = min(window.width / 393, window.height / 852)
            let hit = OneTapeTransportGeometry.hitDiameter(scale: scale)
            let frames = OneTapeTransportGeometry.centersY.map { y in
                CGRect(x: OneTapeTransportGeometry.centerX - hit / 2,
                       y: y - hit / 2, width: hit, height: hit)
            }
            for frame in frames {
                XCTAssertGreaterThanOrEqual(frame.width * scale, 44, "\(window)")
                XCTAssertGreaterThanOrEqual(frame.height * scale, 44, "\(window)")
                XCTAssertGreaterThanOrEqual(frame.minX, 0)
                XCTAssertGreaterThanOrEqual(frame.minY, 0)
                XCTAssertLessThan(frame.maxY, 852)
                // The LCD's left bezel is at x=91.59 design points.
                XCTAssertLessThan(frame.maxX, 91.59)
            }
            XCTAssertLessThan(frames[0].maxY, frames[1].minY)
            XCTAssertLessThan(frames[1].maxY, frames[2].minY)
        }
    }

    @MainActor
    func testSmallerFacesHaveVisibleGapsWithoutTouchingPocketOrBottomEdge() throws {
        let frames = OneTapeTransportGeometry.centersY.map {
            OneTapeTransportGeometry.visualFrame(centerY: $0)
        }
        for frame in frames {
            XCTAssertEqual(frame.width, 58, accuracy: 0.001)
            XCTAssertEqual(frame.height, frame.width)
        }
        XCTAssertGreaterThanOrEqual(frames[1].minY - frames[0].maxY, 10)
        XCTAssertGreaterThanOrEqual(frames[2].minY - frames[1].maxY, 10)
        // The pocket ends at y=622.1; keep its existing lower rim untouched.
        XCTAssertGreaterThan(frames[0].minY, 622.1 + 10)
        XCTAssertLessThan(frames[2].maxY, 852 - 16)

        // Preserve the actual body renderer for separate manual inspection of
        // old-ring removal and color masks; geometry assertions above do not
        // claim to verify the painted pixels or the simulator's final composite.
        for color in [OneTapeAppearance.BodyColor.black, .white] {
            var appearance = OneTapeAppearance()
            appearance.bodyColor = color
            let renderer = ImageRenderer(content: OneTapeBodySurface(appearance: appearance)
                .frame(width: 393, height: 852)
                .environment(\.colorScheme, .dark))
            renderer.proposedSize = ProposedViewSize(width: 393, height: 852)
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage, "Missing \(color.rawValue) body rendering")
            let pixels = try XCTUnwrap(image.cgImage, "Missing \(color.rawValue) body pixel image")
            XCTAssertEqual(pixels.width, 1179, "Unexpected \(color.rawValue) render width")
            XCTAssertEqual(pixels.height, 2556, "Unexpected \(color.rawValue) render height")
            assertNonBlank(pixels, name: color.rawValue)
            let data = try XCTUnwrap(image.pngData(), "Unable to encode \(color.rawValue) body PNG")
            XCTAssertFalse(data.isEmpty, "Empty \(color.rawValue) body PNG")
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = "transport-spacing-body-\(color.rawValue)-3x"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testFullPlayerColorsDoNotShowRectangularSourcePaddingWithEitherGlassState() throws {
        let finishes: [(String, OneTapeAppearance.BodyStyle, OneTapeAppearance.BodyColor)] = [
            ("black", .black, .black), ("graphite", .graphite, .black),
            ("white", .black, .white), ("dove", .black, .dove)
        ]
        let padding = [CGPoint(x: 10, y: 350), CGPoint(x: 382, y: 350),
                       CGPoint(x: 195, y: 60), CGPoint(x: 195, y: 630)]
        let readout = OneTapePlaybackReadout(title: "QA Track", artist: "QA Artist",
            positionSeconds: 13, durationSeconds: 30, isPlaying: false,
            isPreparing: false, trackIndex: 1, trackCount: 3)
        for (name, style, color) in finishes {
            var appearance = OneTapeAppearance()
            appearance.bodyStyle = style
            appearance.bodyColor = color
            let body = try renderPlayer(OneTapeBodySurface(appearance: appearance),
                                        name: "transport-reference-body-\(name)")
            for glassOpen in [true, false] {
                appearance.glassOpen = glassOpen
                let label = "\(name)-glass-\(glassOpen ? "open" : "closed")"
                let face = OneTapePlayerFace(appearance: appearance,
                    readout: readout,
                    glassInteractionEnabled: true, onGlass: {}, onLCD: {},
                    onTransport: { _ in }, onSetGlassOpen: { _ in })
                let image = try renderPlayer(face, name: "transport-full-face-\(label)")
                for point in padding {
                    let reference = try rgb(body, at: point)
                    let actual = try rgb(image, at: point)
                    for channel in 0..<3 {
                        XCTAssertLessThanOrEqual(abs(reference[channel] - actual[channel]), 2,
                            "Opaque cassette padding covers body material: \(label), \(point)")
                    }
                }
                // A body-only or omitted TimelineView cannot satisfy the
                // regression: the real cassette must also exist inside it.
                let inside = CGPoint(x: 195, y: 100)
                let bodyPixel = try rgb(body, at: inside)
                let cassettePixel = try rgb(image, at: inside)
                let difference = zip(bodyPixel, cassettePixel).reduce(0) { $0 + abs($1.0 - $1.1) }
                XCTAssertGreaterThan(difference, 90, "Missing cassette composite: \(label)")
            }
        }
    }

    @MainActor
    private func renderPlayer<Content: View>(_ content: Content, name: String) throws -> CGImage {
        // The readout is paused, so ReelMotion's zero rate already freezes the
        // canvas. Reduce Motion is a system-owned, read-only environment value.
        let renderer = ImageRenderer(content: content.frame(width: 393, height: 852)
            .environment(\.colorScheme, .dark))
        renderer.proposedSize = ProposedViewSize(width: 393, height: 852)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, "Missing \(name) rendering")
        let pixels = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(pixels.width, 1179)
        XCTAssertEqual(pixels.height, 2556)
        assertNonBlank(pixels, name: name)
        let attachment = XCTAttachment(data: try XCTUnwrap(image.pngData()),
                                       uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return pixels
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

    private func assertNonBlank(_ image: CGImage, name: String) {
        var bytes = [UInt8](repeating: 0, count: 32 * 64 * 4)
        let drew = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 32, height: 64,
                                          bitsPerComponent: 8, bytesPerRow: 32 * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 32, height: 64))
            return true
        }
        XCTAssertTrue(drew, "Unable to inspect \(name) body rendering")
        guard drew else { return }
        // A valid attachment must contain actual nonuniform, visible artwork;
        // this coarse validity check does not assess spacing or seam quality.
        let red = stride(from: 0, to: bytes.count, by: 4).map { bytes[$0] }
        let alpha = stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
        XCTAssertGreaterThan(Int(red.max() ?? 0) - Int(red.min() ?? 0), 20,
                             "Blank/uniform \(name) body rendering")
        XCTAssertGreaterThan(alpha.max() ?? 0, 0, "Transparent \(name) body rendering")
    }
}
