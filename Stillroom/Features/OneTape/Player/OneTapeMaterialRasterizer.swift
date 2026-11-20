import CoreGraphics
import CoreImage
import Foundation
import UIKit

/// Built-in material studies: no custom kernel, user files, audio or clock.
/// Call only inside the Canvas drawing closure, never from a SwiftUI body.
enum OneTapeMaterialRasterizer {
    private static let renderer = MaterialRenderer()

    static func render(style: OneTapeAppearance.ScreenStyle, phase: Double,
                       size: CGSize, displayScale: CGFloat = 1) -> CGImage? {
        renderer.render(style: style, phase: phase, size: size, displayScale: displayScale)
    }
}

private final class MaterialRenderer: @unchecked Sendable {
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let context: CIContext
    private let lock = NSLock()
    private var sources: [String: CGImage] = [:]
    // One held output per style bounds memory and reuses the paused pose.
    private var frames: [String: (key: FrameKey, image: CGImage)] = [:]

    init() {
        context = CIContext(options: [
            .useSoftwareRenderer: false, .cacheIntermediates: false,
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ])
    }

    func render(style: OneTapeAppearance.ScreenStyle, phase: Double,
                size: CGSize, displayScale: CGFloat) -> CGImage? {
        guard let asset = Self.asset(for: style),
              size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        let scale = displayScale.isFinite && displayScale > 0 ? displayScale : 1
        let boundedScale = min(scale, 900 / max(size.width, size.height))
        let width = max(1, min(900, Int((size.width * boundedScale).rounded())))
        let height = max(1, min(900, Int((size.height * boundedScale).rounded())))
        let seconds = phase.isFinite ? max(0, phase) : 0
        let key = FrameKey(width: width, height: height, phase: seconds)
        lock.lock()
        let cached = frames[asset]
        lock.unlock()
        if let cached, cached.key == key { return cached.image }
        guard let source = source(named: asset) else { return nil }

        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let image = CIImage(cgImage: source, options: [.colorSpace: colorSpace])
        let factor = max(bounds.width / image.extent.width, bounds.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
        let base = scaled.transformed(by: CGAffineTransform(
            translationX: (bounds.width - scaled.extent.width) / 2 - scaled.extent.minX,
            y: (bounds.height - scaled.extent.height) / 2 - scaled.extent.minY
        )).cropped(to: bounds)
        let output = seconds == 0 ? base
            : (transformed(base, style: style, seconds: seconds, bounds: bounds) ?? base)
        // Clamped intermediates are infinite: always request a finite sRGB crop.
        guard let result = context.createCGImage(output.cropped(to: bounds), from: bounds,
                                                format: .RGBA8, colorSpace: colorSpace) else { return nil }
        lock.lock()
        frames[asset] = (key, result)
        lock.unlock()
        return result
    }

    private func source(named asset: String) -> CGImage? {
        lock.lock()
        let cached = sources[asset]
        lock.unlock()
        if let cached { return cached }
        // Named asset catalog only. Retain immutable CGImage across async draws.
        guard let image = UIImage(named: asset)?.cgImage else { return nil }
        lock.lock()
        sources[asset] = image
        lock.unlock()
        return image
    }

    private func transformed(_ base: CIImage, style: OneTapeAppearance.ScreenStyle,
                             seconds: Double, bounds: CGRect) -> CIImage? {
        let width = bounds.width
        let height = bounds.height
        let unit = min(width, height)
        let input = base.clampedToExtent()
        switch style {
        case .dunes:
            // CI positions are bottom-left pixels. Sampling displacement moves
            // image features in the opposite direction, matching the study.
            let dx = -0.0068 * width * sin(seconds * 0.075)
            let dy = -0.0024 * height * (cos(seconds * 0.065) - 1)
            return input.transformed(by: CGAffineTransform(translationX: dx, y: dy)).cropped(to: bounds)
        case .iron:
            // Two small fields stay inside the dense right-hand filaments.
            guard let first = bump(input, center: CGPoint(x: width * 0.74, y: height * 0.48),
                                   radius: unit * 0.26, scale: 0.055 * sin(seconds * 0.38)) else { return nil }
            return bump(first.cropped(to: bounds).clampedToExtent(),
                        center: CGPoint(x: width * 0.87, y: height * 0.73),
                        radius: unit * 0.22, scale: -0.040 * sin(seconds * 0.31))?.cropped(to: bounds)
        case .fluid:
            let phase = seconds.truncatingRemainder(dividingBy: 2 * .pi / 0.21) * 0.21
            // Native low-angle counter-flow at the photo's two S bends, not a
            // fluid solver or a recovered paid-reference animation.
            guard let first = twirl(input, center: CGPoint(x: width * 0.43, y: height * 0.70),
                                    radius: unit * 0.70, angle: 0.12 * sin(phase)) else { return nil }
            return twirl(first.cropped(to: bounds).clampedToExtent(),
                         center: CGPoint(x: width * 0.73, y: height * 0.48),
                         radius: unit * 0.62, angle: -0.09 * (cos(phase) - 1))?.cropped(to: bounds)
        default:
            return base
        }
    }

    private func bump(_ image: CIImage, center: CGPoint, radius: CGFloat, scale: Double) -> CIImage? {
        guard let filter = CIFilter(name: "CIBumpDistortion") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: center), forKey: kCIInputCenterKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        return filter.outputImage
    }

    private func twirl(_ image: CIImage, center: CGPoint, radius: CGFloat, angle: Double) -> CIImage? {
        guard let filter = CIFilter(name: "CITwirlDistortion") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: center), forKey: kCIInputCenterKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(angle, forKey: kCIInputAngleKey)
        return filter.outputImage
    }

    private static func asset(for style: OneTapeAppearance.ScreenStyle) -> String? {
        switch style {
        case .dunes: "OneTapeScreenDunesPhoto"
        case .iron: "OneTapeScreenIronPhoto"
        case .fluid: "OneTapeScreenFluidPhoto"
        default: nil
        }
    }

    private struct FrameKey: Equatable {
        let width: Int
        let height: Int
        let phase: Double
    }
}
