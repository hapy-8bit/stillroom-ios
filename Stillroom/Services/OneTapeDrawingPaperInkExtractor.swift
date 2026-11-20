import CoreGraphics
import UIKit

enum OneTapeDrawingPaperInkExtractor {
    struct RGB {
        let r: Float
        let g: Float
        let b: Float
    }

    static let paperCream = RGB(r: 0.96, g: 0.945, b: 0.91)
    static let cutoutBlue = RGB(r: 0.24, g: 0.56, b: 0.92)
    static let guideBlue = RGB(r: 0.16, g: 0.44, b: 0.84)

    static func tryExtractTransparentArtworkIfApplicable(
        from image: UIImage,
        cgImage: CGImage
    ) -> OneTapeImportedPaper? {
        let w = cgImage.width
        let h = cgImage.height
        guard let rgba = extractRGBA(from: cgImage, targetSize: CGSize(width: w, height: h)) else {
            return nil
        }

        let totalPixels = w * h
        guard totalPixels > 0 else { return nil }

        // Check transparent ratio (>2%) and opaque ink count (>=0.01%) via uniform stride on large assets.
        let strideStep = max(1, totalPixels / 200_000)
        var sampled = 0
        var transparentSampled = 0
        var visibleInkSampled = 0
        var idx = 0
        while idx < totalPixels {
            let alpha = rgba[idx * 4 + 3]
            sampled += 1
            if alpha < 128 {
                transparentSampled += 1
            } else {
                visibleInkSampled += 1
            }
            idx += strideStep
        }

        guard Float(transparentSampled) / Float(max(1, sampled)) > 0.02 else {
            return nil
        }
        guard visibleInkSampled >= max(4, sampled / 10_000) else {
            return nil
        }

        return OneTapeImportedPaper(
            image: orientExtractedToPortrait(image),
            recognizedPaper: false
        )
    }

    static func containsTemplateBlue(in cgImage: CGImage) -> Bool {
        let sampleSize = CGSize(width: 260, height: 184)
        guard let rgba = extractRGBA(from: cgImage, targetSize: sampleSize) else { return false }
        let total = Int(sampleSize.width * sampleSize.height)
        var blueHits = 0
        for idx in 0..<total {
            let r = Float(rgba[idx * 4]) / 255.0
            let g = Float(rgba[idx * 4 + 1]) / 255.0
            let b = Float(rgba[idx * 4 + 2]) / 255.0
            if colorDistSq(r, g, b, cutoutBlue) < 0.032 || colorDistSq(r, g, b, guideBlue) < 0.032 {
                blueHits += 1
            }
        }
        return Float(blueHits) / Float(max(1, total)) >= 0.008
    }

    static func estimatePaperBackgroundColor(rgba: [UInt8], width: Int, height: Int) -> RGB {
        let total = width * height
        let step = max(1, total / 20_000)
        var sumR: Float = 0
        var sumG: Float = 0
        var sumB: Float = 0
        var count: Float = 0

        var idx = 0
        while idx < total {
            let offset = idx * 4
            let a = Float(rgba[offset + 3]) / 255.0
            if a > 0.5 {
                let r = Float(rgba[offset]) / 255.0
                let g = Float(rgba[offset + 1]) / 255.0
                let b = Float(rgba[offset + 2]) / 255.0
                let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                let isBlue = colorDistSq(r, g, b, cutoutBlue) < 0.04 || colorDistSq(r, g, b, guideBlue) < 0.04
                if luma > 0.72 && !isBlue {
                    sumR += r
                    sumG += g
                    sumB += b
                    count += 1
                }
            }
            idx += step
        }

        guard count >= 20 else { return paperCream }
        return RGB(r: sumR / count, g: sumG / count, b: sumB / count)
    }

    /// Strips blueprint cutout colors, anti-aliased transitions, and estimated paper tone; returns ink pixel count.
    static func stripBackgroundAndBlueCutouts(rgba: inout [UInt8], paper: RGB) -> Int {
        let totalPixels = rgba.count / 4
        var inkCount = 0

        let pR = paper.r
        let pG = paper.g
        let pB = paper.b
        let negR = max(0.001, pR)
        let posR = max(0.001, 1.0 - pR)
        let negG = max(0.001, pG)
        let posG = max(0.001, 1.0 - pG)
        let negB = max(0.001, pB)
        let posB = max(0.001, 1.0 - pB)

        for idx in 0..<totalPixels {
            let base = idx * 4
            let a = Float(rgba[base + 3]) / 255.0
            if a <= 0.001 {
                rgba[base] = 0
                rgba[base + 1] = 0
                rgba[base + 2] = 0
                rgba[base + 3] = 0
                continue
            }

            let r = Float(rgba[base]) / 255.0
            let g = Float(rgba[base + 1]) / 255.0
            let b = Float(rgba[base + 2]) / 255.0

            if colorDistSq(r, g, b, cutoutBlue) < 0.025
                || colorDistSq(r, g, b, guideBlue) < 0.022
                || isNearTransitionSegment(r: r, g: g, b: b, from: paper, to: cutoutBlue)
                || isNearTransitionSegment(r: r, g: g, b: b, from: paper, to: guideBlue)
                || isNearTransitionSegment(r: r, g: g, b: b, from: cutoutBlue, to: guideBlue) {
                rgba[base] = 0
                rgba[base + 1] = 0
                rgba[base + 2] = 0
                rgba[base + 3] = 0
                continue
            }

            let normR = r <= pR ? (pR - r) / negR : (r - pR) / posR
            let normG = g <= pG ? (pG - g) / negG : (g - pG) / posG
            let normB = b <= pB ? (pB - b) / negB : (b - pB) / posB
            let maxDeviation = max(normR, max(normG, normB))

            let alpha = min(1.0, max(0.0, (maxDeviation - 0.09) / 0.75))
            guard alpha > 0.004 else {
                rgba[base] = 0
                rgba[base + 1] = 0
                rgba[base + 2] = 0
                rgba[base + 3] = 0
                continue
            }

            let invT = 1.0 / max(0.001, maxDeviation)
            let cleanR = min(1.0, max(0.0, pR + (r - pR) * invT))
            let cleanG = min(1.0, max(0.0, pG + (g - pG) * invT))
            let cleanB = min(1.0, max(0.0, pB + (b - pB) * invT))

            let outA = UInt8(clamping: Int(alpha * 255.0))
            rgba[base] = UInt8(clamping: Int(cleanR * 255.0))
            rgba[base + 1] = UInt8(clamping: Int(cleanG * 255.0))
            rgba[base + 2] = UInt8(clamping: Int(cleanB * 255.0))
            rgba[base + 3] = outA
            if outA >= 25 {
                inkCount += 1
            }
        }
        return inkCount
    }

    static func orientExtractedToPortrait(_ image: UIImage) -> UIImage {
        let targetSize = OneTapeDrawingGeometry.storedPortraitPixelSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let imgW = image.size.width * image.scale
        let imgH = image.size.height * image.scale
        let isLandscape = imgW > imgH * 1.05

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            let cg = context.cgContext
            if isLandscape {
                // Rotate landscape paper/sheet +90 deg clockwise so upright top lines up with cassette top.
                cg.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
                cg.rotate(by: .pi / 2)
                let rotatedBounds = CGSize(width: targetSize.height, height: targetSize.width)
                let drawRect = aspectFitRect(sourceSize: CGSize(width: imgW, height: imgH), in: CGRect(
                    x: -rotatedBounds.width / 2,
                    y: -rotatedBounds.height / 2,
                    width: rotatedBounds.width,
                    height: rotatedBounds.height
                ))
                image.draw(in: drawRect)
            } else {
                let drawRect = aspectFitRect(sourceSize: CGSize(width: imgW, height: imgH), in: CGRect(origin: .zero, size: targetSize))
                image.draw(in: drawRect)
            }
        }
    }

    static func normalizeUpOrientation(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let rawSize = image.size
        guard rawSize.width > 0, rawSize.height > 0 else { return nil }
        let longest = max(rawSize.width, rawSize.height)
        let scale = min(1.0, maxDimension / longest)
        let target = CGSize(width: floor(rawSize.width * scale), height: floor(rawSize.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    static func extractRGBA(from cgImage: CGImage, targetSize: CGSize) -> [UInt8]? {
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        guard width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for idx in 0..<(width * height) {
            let base = idx * 4
            let a = bytes[base + 3]
            if a > 0 && a < 255 {
                let af = Float(a) / 255.0
                bytes[base] = UInt8(clamping: Int(Float(bytes[base]) / af))
                bytes[base + 1] = UInt8(clamping: Int(Float(bytes[base + 1]) / af))
                bytes[base + 2] = UInt8(clamping: Int(Float(bytes[base + 2]) / af))
            }
        }
        return bytes
    }

    static func makeCGImage(fromRGBA bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, bytes.count >= width * height * 4 else { return nil }
        var premul = bytes
        for idx in 0..<(width * height) {
            let base = idx * 4
            let a = Float(premul[base + 3]) / 255.0
            premul[base] = UInt8(clamping: Int(Float(premul[base]) * a))
            premul[base + 1] = UInt8(clamping: Int(Float(premul[base + 1]) * a))
            premul[base + 2] = UInt8(clamping: Int(Float(premul[base + 2]) * a))
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let data = Data(premul)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private static func aspectFitRect(sourceSize: CGSize, in bounds: CGRect) -> CGRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return bounds }
        let scale = min(bounds.width / sourceSize.width, bounds.height / sourceSize.height)
        let w = sourceSize.width * scale
        let h = sourceSize.height * scale
        return CGRect(
            x: bounds.midX - w / 2,
            y: bounds.midY - h / 2,
            width: w,
            height: h
        )
    }

    private static func colorDistSq(_ r: Float, _ g: Float, _ b: Float, _ target: RGB) -> Float {
        let dr = r - target.r
        let dg = g - target.g
        let db = b - target.b
        return dr * dr + dg * dg + db * db
    }

    private static func isNearTransitionSegment(r: Float, g: Float, b: Float, from a: RGB, to c: RGB) -> Bool {
        let dx = c.r - a.r
        let dy = c.g - a.g
        let dz = c.b - a.b
        let lenSq = dx * dx + dy * dy + dz * dz
        guard lenSq > 0.0001 else { return false }
        let t = (dx * (r - a.r) + dy * (g - a.g) + dz * (b - a.b)) / lenSq
        guard t > 0.10 && t < 1.10 else { return false }
        let rx = (r - a.r) - dx * t
        let ry = (g - a.g) - dy * t
        let rz = (b - a.b) - dz * t
        return (rx * rx + ry * ry + rz * rz) < 0.0022
    }
}
