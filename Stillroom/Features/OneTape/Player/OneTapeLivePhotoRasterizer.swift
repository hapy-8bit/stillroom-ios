import CoreGraphics
import CoreImage
import Foundation
import UIKit

/// Named catalog resources only. Pixel conversion happens at this draw boundary;
/// Call inside Canvas drawing callbacks, never while building a View. Rendering
/// is synchronous on that caller's thread; this helper does not choose a queue.
enum OneTapeLivePhotoRasterizer {
    private static let renderer = LivePhotoRenderer()
    private static let playbackRenderer = LivePhotoRenderer()

    static func render(style: OneTapeAppearance.ScreenStyle, phase: Double,
                       size: CGSize, displayScale: CGFloat = 1) -> CGImage? {
        renderer.render(style: style, phase: phase, size: size, displayScale: displayScale)
    }

    /// Static/offscreen previews never wait on a playback worker's first field
    /// preparation. Separate bounded caches share the same pixel algorithm.
    static func renderForPlayback(style: OneTapeAppearance.ScreenStyle, phase: Double,
                                  size: CGSize, displayScale: CGFloat) -> CGImage? {
        playbackRenderer.render(style: style, phase: phase, size: size, displayScale: displayScale)
    }
}

private final class LivePhotoRenderer: @unchecked Sendable {
    private let lock = NSLock()
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let ci = CIContext(options: [.cacheIntermediates: false])
    private var sources: [String: Source] = [:]
    private var frames: [String: (Double, CGImage)] = [:]
    private var zeroFrames: [String: CGImage] = [:]

    private struct Source {
        let image: CGImage
        let bytes: [UInt8]
        let width: Int
        let height: Int
        let photoRect: CGRect
        var trail: [TrailPixel] = []
    }

    private struct TrailPixel {
        let offset: Int
        let delay: Double
        let mask: Double
        let red: Double
        let green: Double
        let blue: Double
    }

    func render(style: OneTapeAppearance.ScreenStyle, phase: Double,
                size: CGSize, displayScale: CGFloat) -> CGImage? {
        guard style == .rain || style == .trails,
              size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return nil }
        let scale = min(displayScale.isFinite ? max(1, displayScale) : 1, 900 / max(size.width, size.height))
        let width = max(1, Int((size.width * scale).rounded()))
        let height = max(1, Int((size.height * scale).rounded()))
        let layout = OneTapeScreenLayoutGeometry(size: size)
        let asset = style == .rain ? "OneTapeScreenRainPhoto" : "OneTapeScreenTrailsPhoto"
        // Fraction comes from logical geometry, before pixel rounding. Include
        // it so two adjacent transition poses sharing a raster size do not reuse
        // the previous crop, while endpoint compositions remain exact.
        let key = "\(asset):\(width):\(height):\(layout.tallFraction)"
        let time = phase.isFinite ? max(0, phase).truncatingRemainder(dividingBy: 6) : 0
        // A small serial cache prevents overlapping async Canvas callbacks from
        // generating the same expensive path-distance field twice.
        lock.lock(); defer { lock.unlock() }
        if time == 0, let zero = zeroFrames[key] { return zero }
        if let held = frames[key], held.0 == time { return held.1 }
        if sources[key] == nil {
            guard let source = makeSource(asset: asset, width: width, height: height,
                                          trails: style == .trails, layout: layout) else { return nil }
            if sources.count >= 4 { sources.removeAll(); frames.removeAll(); zeroFrames.removeAll() }
            sources[key] = source
        }
        guard let source = sources[key] else { return nil }
        let image = style == .rain ? rain(source, time: time) : trails(source, time: time)
        if let image { frames[key] = (time, image) }
        if time == 0, let image { zeroFrames[key] = image }
        return image
    }

    private func bitmap(_ width: Int, _ height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                  bytesPerRow: width * 4, space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    private func makeSource(asset: String, width: Int, height: Int, trails: Bool,
                            layout: OneTapeScreenLayoutGeometry) -> Source? {
        guard let image = UIImage(named: asset)?.cgImage, let context = bitmap(width, height) else { return nil }
        let viewport = CGRect(x: 0, y: 0, width: width, height: height)
        let target: CGRect
        let photoRect: CGRect
        let factor = max(Double(width) / Double(image.width), Double(height) / Double(image.height))
        let w = Double(image.width) * factor, h = Double(image.height) * factor
        if trails {
            let narrowTarget = CGRect(x: Double(width) * 0.19, y: Double(height) * 0.10,
                                      width: Double(width) * 0.71, height: Double(height) * 0.49)
            // Source crop (40%,7%,55%,79%) is mapped to a separate portrait art
            // region. Interpolate a single photo matrix and clipping region so
            // the original pixels and their light field move together in a turn.
            let narrowPhoto = CGRect(x: narrowTarget.minX - narrowTarget.width * 0.40 / 0.55,
                                     y: narrowTarget.minY - narrowTarget.height * 0.07 / 0.79,
                                     width: narrowTarget.width / 0.55, height: narrowTarget.height / 0.79)
            let widePhoto = CGRect(x: (Double(width) - w) / 2, y: (Double(height) - h) / 2, width: w, height: h)
            target = CGRect(x: layout.mix(viewport.minX, narrowTarget.minX),
                            y: layout.mix(viewport.minY, narrowTarget.minY),
                            width: layout.mix(viewport.width, narrowTarget.width),
                            height: layout.mix(viewport.height, narrowTarget.height))
            photoRect = CGRect(x: layout.mix(widePhoto.minX, narrowPhoto.minX),
                               y: layout.mix(widePhoto.minY, narrowPhoto.minY),
                               width: layout.mix(widePhoto.width, narrowPhoto.width),
                               height: layout.mix(widePhoto.height, narrowPhoto.height))
        } else {
            target = viewport
            photoRect = CGRect(x: (Double(width) - w) * layout.mix(0.50, 0.70),
                               y: (Double(height) - h) / 2, width: w, height: h)
        }
        context.setFillColor(CGColor(red: 5 / 255.0, green: 5 / 255.0, blue: 4 / 255.0, alpha: 1))
        context.fill(viewport)
        context.interpolationQuality = .high
        context.saveGState()
        context.clip(to: CGRect(x: target.minX, y: Double(height) - target.maxY,
                                width: target.width, height: target.height))
        context.draw(image, in: CGRect(x: photoRect.minX, y: Double(height) - photoRect.maxY,
                                      width: photoRect.width, height: photoRect.height))
        if trails && layout.tallFraction > 0 {
            shade(context, top: target.minY + target.height * 0.74, bottom: target.maxY,
                  height: Double(height), colors: [CGColor(red: 5 / 255.0, green: 5 / 255.0, blue: 4 / 255.0, alpha: 0),
                      CGColor(red: 5 / 255.0, green: 5 / 255.0, blue: 4 / 255.0,
                              alpha: layout.tallFraction)], locations: [0, 1])
        } else if !trails {
            shade(context, top: Double(height) * layout.mix(0.45, 0.40), bottom: Double(height),
                  height: Double(height), colors: [CGColor(red: 7 / 255.0, green: 10 / 255.0, blue: 9 / 255.0, alpha: 0),
                      CGColor(red: 6 / 255.0, green: 9 / 255.0, blue: 9 / 255.0, alpha: 173 / 255.0),
                      CGColor(red: 6 / 255.0, green: 9 / 255.0, blue: 9 / 255.0, alpha: 220 / 255.0)], locations: [0, 0.70, 1])
        }
        context.restoreGState()
        guard let base = context.makeImage(), let data = context.data else { return nil }
        var source = Source(image: base, bytes: Array(UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: UInt8.self), count: width * height * 4)),
            width: width, height: height, photoRect: photoRect)
        if trails { prepareTrail(&source) }
        return source
    }

    private func shade(_ context: CGContext, top: Double, bottom: Double, height: Double,
                       colors: [CGColor], locations: [CGFloat]) {
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else { return }
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height - top),
                                   end: CGPoint(x: 0, y: height - bottom), options: [])
    }

    private func rain(_ source: Source, time: Double) -> CGImage? {
        let w = Double(source.width), h = Double(source.height)
        let bounds = CGRect(x: 0, y: 0, width: w, height: h)
        guard let context = bitmap(source.width, source.height) else { return nil }
        context.draw(source.image, in: bounds)
        let input = CIImage(cgImage: source.image, options: [.colorSpace: colorSpace]).clampedToExtent()
        let beads: [(Double, Double, Double, Double)] = [
            (0.65, 0.08, 0.44, 0.14), (0.81, 0.28, 0.55, 0.51), (0.91, 0.14, 0.45, 0.82)
        ]
        for (index, bead) in beads.enumerated() {
            let progress = (time / 6 + bead.3).truncatingRemainder(dividingBy: 1)
            let opacity = pow(sin(.pi * progress), 0.8)
            let x = w * bead.0 + w / 192 * sin(progress * 2 * .pi + Double(index))
            let y = h * (1 - bead.1 - bead.2 * progress)
            let rx = w / 480 * (index == 1 ? 3.8 : 3.0)
            let ry = h / 300 * (index == 1 ? 6.2 : 5.0)
            let rect = CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2)
            let lens = input.applyingFilter("CIBumpDistortion", parameters: [
                kCIInputCenterKey: CIVector(x: x, y: y + 0.5),
                kCIInputRadiusKey: ry * 2.1, kCIInputScaleKey: 0.56
            ]).cropped(to: bounds)
            // Only this tiny ellipse is composited. Request integer-aligned
            // output around it (plus antialias padding), keeping CI coordinates
            // unchanged so ROI evaluation preserves the full-frame refraction.
            let region = rect.insetBy(dx: -2, dy: -2).integral.intersection(bounds)
            guard !region.isEmpty,
                  let refracted = ci.createCGImage(lens, from: region, format: .RGBA8,
                                                  colorSpace: colorSpace) else { continue }
            context.saveGState(); context.setAlpha(opacity)
            context.addEllipse(in: rect); context.clip(); context.draw(refracted, in: region)
            context.restoreGState()
            context.saveGState(); context.setAlpha(opacity)
            context.setStrokeColor(CGColor(gray: 0.04, alpha: 0.60)); context.setLineWidth(w / 600)
            context.strokeEllipse(in: rect)
            context.setStrokeColor(CGColor(red: 0.75, green: 0.79, blue: 0.75, alpha: 0.62))
            context.setLineWidth(w / 685)
            context.move(to: CGPoint(x: x - rx * 0.65, y: y - ry * 0.55))
            context.addQuadCurve(to: CGPoint(x: x + rx * 0.55, y: y - ry * 0.70),
                                 control: CGPoint(x: x, y: y - ry * 1.02))
            context.strokePath(); context.restoreGState()
        }
        return context.makeImage()
    }

    private var lightPoints: [(Double, Double)] {
        [(0.672,0.116),(0.647,0.146),(0.628,0.177),(0.622,0.203),
         (0.640,0.231),(0.681,0.255),(0.733,0.279),(0.786,0.304),
         (0.834,0.333),(0.867,0.361),(0.881,0.389),(0.884,0.414),
         (0.875,0.446),(0.860,0.480),(0.837,0.516),(0.806,0.552),
         (0.768,0.590),(0.723,0.626),(0.669,0.661),(0.609,0.695),
         (0.550,0.731),(0.501,0.764),(0.468,0.790)]
    }

    private func prepareTrail(_ source: inout Source) {
        let width = source.width, height = source.height
        // Marks are traced in the photograph's normalized top-left space.
        // Aspect-fill may put its edges far outside a tall LCD, so every field
        // must use the same photo rect rather than stretching to the viewport.
        let photo = source.photoRect
        let points = lightPoints.map { CGPoint(x: photo.minX + $0.0 * photo.width,
                                              y: photo.minY + $0.1 * photo.height) }
        let firstX = min(width, max(0, Int(floor(photo.minX + photo.width * 0.45))))
        let pixelScale = photo.width / 480
        source.trail.reserveCapacity(width * height / 20)
        for y in 0..<height {
            for x in firstX..<width {
                let index = y * width + x
                guard max(source.bytes[index * 4], source.bytes[index * 4 + 1], source.bytes[index * 4 + 2]) >= 12 else { continue }
                var nearest = 1000.0
                var progress = 0.0
                for segment in 0..<(points.count - 1) {
                    let a = points[segment], b = points[segment + 1]
                    let dx = b.x - a.x, dy = b.y - a.y
                    let p = min(1, max(0, ((Double(x) - a.x) * dx + (Double(y) - a.y) * dy) / (dx * dx + dy * dy)))
                    let distance = hypot(Double(x) - a.x - dx * p, Double(y) - a.y - dy * p)
                    if distance < nearest {
                        nearest = distance
                        progress = (Double(segment) + p) / Double(points.count - 1)
                    }
                }
                // These source colors, delays and distance falloffs are fixed.
                // Only lit pixels need per-frame gain; keep exp/pow and the
                // full-image scan out of the playback loop.
                let mask = exp(-pow(nearest / pixelScale, 2) / 110)
                guard mask > 0.005 else { continue }
                source.trail.append(TrailPixel(offset: index * 4, delay: 0.10 + progress * 3.10,
                    mask: mask, red: Double(source.bytes[index * 4]),
                    green: Double(source.bytes[index * 4 + 1]), blue: Double(source.bytes[index * 4 + 2])))
            }
        }
    }

    private func trails(_ source: Source, time: Double) -> CGImage? {
        var output = source.bytes
        let width = source.width, height = source.height
        output.withUnsafeMutableBufferPointer { bytes in
            source.trail.withUnsafeBufferPointer { trail in
                var index = 0
                while index < trail.count {
                    let pixel = trail[index]
                    let age = time - pixel.delay
                    let active = smooth(-0.07, 0.18, age) * (1 - smooth(1.10, 2.50, age))
                    let gain = 1 + pixel.mask * (-0.78 + active * 1.55)
                    bytes[pixel.offset] = UInt8(min(255, max(0, pixel.red * gain)))
                    bytes[pixel.offset + 1] = UInt8(min(255, max(0, pixel.green * gain)))
                    bytes[pixel.offset + 2] = UInt8(min(255, max(0, pixel.blue * gain)))
                    index += 1
                }
            }
        }
        let provider = CGDataProvider(data: Data(output) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    private func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let x = min(1, max(0, (value - low) / (high - low)))
        return x * x * (3 - 2 * x)
    }
}
