import XCTest
import CoreGraphics
@testable import Stillroom

/// Exercises actual iOS Core Image output. This does not establish device frame
/// rate, reference-app motion fidelity or reduced-motion view behavior.
final class OneTapeMaterialRasterizerTests: XCTestCase {
    private let styles: [OneTapeAppearance.ScreenStyle] = [.dunes, .iron, .fluid]

    @MainActor
    func testEachMaterialChangesWithPhaseAndRepeatsDeterministically() throws {
        let size = CGSize(width: 264.39, height: 165.63)
        for style in styles {
            let still = try pixels(render(style, phase: 0, size: size, scale: 2))
            let moved = try pixels(render(style, phase: 5, size: size, scale: 2))
            let repeated = try pixels(render(style, phase: 5, size: size, scale: 2))
            let returned = try pixels(render(style, phase: 0, size: size, scale: 2))
            XCTAssertEqual(still.width, moved.width)
            XCTAssertEqual(still.height, moved.height)
            XCTAssertGreaterThan(changedPixels(still.bytes, moved.bytes), 20,
                "No visible phase response from \(style.rawValue)")
            XCTAssertTrue(moved.bytes.elementsEqual(repeated.bytes),
                "Repeated phase changed output for \(style.rawValue)")
            // Returning after another phase also exercises a new render, rather
            // than proving determinism only by reading the last-frame cache.
            XCTAssertTrue(still.bytes.elementsEqual(returned.bytes),
                "Returning to phase zero changed output for \(style.rawValue)")
        }
    }

    @MainActor
    func testDistortedMaterialsKeepTheirCoverOpaqueIncludingEveryEdge() throws {
        for style in styles {
            for phase in [0.0, 5.0] {
                let frame = try pixels(render(style, phase: phase,
                    size: CGSize(width: 264.39, height: 165.63), scale: 2))
                let alphaIsOpaque = stride(from: 3, to: frame.bytes.count, by: 4)
                    .allSatisfy { frame.bytes[$0] >= 250 }
                XCTAssertTrue(alphaIsOpaque, "Transparent cover pixels in \(style.rawValue), phase \(phase)")
                XCTAssertTrue(edgeAlphas(frame).allSatisfy { $0 >= 250 },
                    "Distortion exposed a transparent border in \(style.rawValue), phase \(phase)")
            }
        }
    }

    @MainActor
    func testOutputPreservesAspectCapsDimensionsAndRejectsInvalidSizes() throws {
        let cases: [(CGSize, CGFloat)] = [
            (CGSize(width: 264.39, height: 165.63), 2),
            (CGSize(width: 1_200, height: 600), 3),
            (CGSize(width: 600, height: 1_200), 3),
            (CGSize(width: 1_000_000, height: 500_000), 1)
        ]
        for (size, scale) in cases {
            let image = try render(.fluid, phase: 5, size: size, scale: scale)
            let requestedWidth = size.width * scale
            let requestedHeight = size.height * scale
            let cap = min(1, 900 / max(requestedWidth, requestedHeight))
            XCTAssertGreaterThan(image.width, 0)
            XCTAssertGreaterThan(image.height, 0)
            XCTAssertLessThanOrEqual(max(image.width, image.height), 900)
            XCTAssertEqual(CGFloat(image.width), requestedWidth * cap, accuracy: 1.1)
            XCTAssertEqual(CGFloat(image.height), requestedHeight * cap, accuracy: 1.1)
        }
        let invalidSizes = [CGSize.zero, CGSize(width: -1, height: 100),
            CGSize(width: 100, height: 0), CGSize(width: CGFloat.nan, height: 100),
            CGSize(width: 100, height: CGFloat.infinity),
            CGSize(width: -CGFloat.infinity, height: 100)]
        for size in invalidSizes {
            XCTAssertNil(OneTapeMaterialRasterizer.render(style: .fluid, phase: 0, size: size))
        }
        for style in [OneTapeAppearance.ScreenStyle.lcd, .fox] {
            XCTAssertNil(OneTapeMaterialRasterizer.render(style: style, phase: 0,
                size: CGSize(width: 264.39, height: 165.63)))
        }
    }

    @MainActor
    private func render(_ style: OneTapeAppearance.ScreenStyle, phase: Double,
                        size: CGSize, scale: CGFloat) throws -> CGImage {
        try XCTUnwrap(OneTapeMaterialRasterizer.render(style: style, phase: phase,
            size: size, displayScale: scale), "Failed iOS CI render for \(style.rawValue), phase \(phase)")
    }

    private func changedPixels(_ first: [UInt8], _ second: [UInt8]) -> Int {
        guard first.count == second.count else { return 0 }
        return stride(from: 0, to: first.count, by: 4).filter { offset in
            (0..<4).contains { abs(Int(first[offset + $0]) - Int(second[offset + $0])) >= 3 }
        }.count
    }

    private func edgeAlphas(_ image: PixelFrame) -> [UInt8] {
        var alphas: [UInt8] = []
        for x in 0..<image.width {
            alphas.append(image.bytes[x * 4 + 3])
            alphas.append(image.bytes[((image.height - 1) * image.width + x) * 4 + 3])
        }
        for y in 0..<image.height {
            alphas.append(image.bytes[(y * image.width) * 4 + 3])
            alphas.append(image.bytes[(y * image.width + image.width - 1) * 4 + 3])
        }
        return alphas
    }

    private func pixels(_ image: CGImage) throws -> PixelFrame {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drew = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(drew)
        return PixelFrame(width: image.width, height: image.height, bytes: bytes)
    }

    private struct PixelFrame {
        let width: Int
        let height: Int
        let bytes: [UInt8]
    }
}
