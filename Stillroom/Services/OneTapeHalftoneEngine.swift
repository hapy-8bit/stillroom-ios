import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

enum OneTapeHalftoneEngine {
    static let previewRenderSize = CGSize(width: 376, height: 576)
    static let finalExportSize = CGSize(width: 784, height: 1200)

    static func normalizeSourceImage(_ image: UIImage, maxDimension: CGFloat = 1800) throws -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            throw OneTapeArtworkError.unreadable
        }
        let scale = min(1.0, maxDimension / max(size.width, size.height))
        let target = CGSize(width: max(1, floor(size.width * scale)), height: max(1, floor(size.height * scale)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard rendered.cgImage != nil else {
            throw OneTapeArtworkError.unreadable
        }
        return rendered
    }

    static func extractSubjectCutout(from sourceImage: UIImage) throws -> UIImage {
        guard let cgSource = sourceImage.cgImage else {
            throw OneTapeArtworkError.unreadable
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgSource, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else {
                throw OneTapeArtworkError.noSubjectFound
            }
            let maskBuffer = try observation.generateScaledMaskForImage(
                forInstances: observation.allInstances,
                from: handler
            )
            let maskCI = CIImage(cvPixelBuffer: maskBuffer)
            let inputCI = CIImage(cgImage: cgSource)
            let blend = CIFilter.blendWithMask()
            blend.inputImage = inputCI
            blend.maskImage = maskCI
            blend.backgroundImage = CIImage.empty()

            let context = CIContext()
            guard let outputCI = blend.outputImage,
                  let outCG = context.createCGImage(outputCI, from: inputCI.extent) else {
                throw OneTapeArtworkError.noSubjectFound
            }
            let result = UIImage(cgImage: outCG)
            guard countVisibleAlphaPixels(in: outCG, threshold: 40) >= max(16, (outCG.width * outCG.height) / 500) else {
                throw OneTapeArtworkError.noSubjectFound
            }
            return result
        } catch let error as OneTapeArtworkError {
            throw error
        } catch {
            throw OneTapeArtworkError.noSubjectFound
        }
    }

    static func renderComposedSource(
        sourceImage: UIImage,
        subjectMaskImage: UIImage?,
        recipe: OneTapeArtworkRecipe,
        targetSize: CGSize
    ) -> UIImage {
        let baseImage = (recipe.subjectOnly ? (subjectMaskImage ?? sourceImage) : sourceImage)
        let cropped = cropImage(baseImage, normalizedRect: recipe.placement.cropRect)

        // Photo placement is authored in horizontal cassette coordinates (576x376.33)
        // and rotated +90 deg into portrait canvas coordinates (376.33x576) to match
        // OneTapeBrandPrint and OneTapeTapeThumbnail's -90 deg presentation.
        let landscapeSize = CGSize(width: targetSize.height, height: targetSize.width)
        let srcW = max(1, cropped.size.width)
        let srcH = max(1, cropped.size.height)
        let coverScale = max(landscapeSize.width / srcW, landscapeSize.height / srcH)
        let appliedScale = coverScale * CGFloat(max(0.25, recipe.placement.scale))
        let drawW = srcW * appliedScale
        let drawH = srcH * appliedScale

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: targetSize.width * 0.5, y: targetSize.height * 0.5)
            cg.rotate(by: .pi / 2)
            cg.translateBy(
                x: CGFloat(recipe.placement.offsetX) * landscapeSize.width,
                y: CGFloat(recipe.placement.offsetY) * landscapeSize.height
            )
            cg.rotate(by: CGFloat(recipe.placement.rotationDegrees) * .pi / 180.0)
            cropped.draw(in: CGRect(x: -drawW * 0.5, y: -drawH * 0.5, width: drawW, height: drawH))
        }
    }

    static func renderArtworkPrint(
        sourceImage: UIImage,
        subjectMaskImage: UIImage?,
        recipe: OneTapeArtworkRecipe,
        shell: OneTapeAppearance.TapeStyle,
        targetSize: CGSize
    ) throws -> UIImage {
        let composed = renderComposedSource(
            sourceImage: sourceImage,
            subjectMaskImage: subjectMaskImage,
            recipe: recipe,
            targetSize: targetSize
        )
        guard let composedCG = composed.cgImage else {
            throw OneTapeArtworkError.unreadable
        }

        switch recipe.mode {
        case .lineInk:
            return try renderLineInk(composedCG: composedCG, recipe: recipe, shell: shell)
        case .halftone:
            return try renderHalftone(composedCG: composedCG, recipe: recipe, shell: shell)
        }
    }

    // MARK: - Line-Art Extraction (1000eac60)

    private static func renderLineInk(
        composedCG: CGImage,
        recipe: OneTapeArtworkRecipe,
        shell: OneTapeAppearance.TapeStyle
    ) throws -> UIImage {
        let w = composedCG.width
        let h = composedCG.height
        guard var rgba = OneTapeDrawingPaperInkExtractor.extractRGBA(
            from: composedCG,
            targetSize: CGSize(width: w, height: h)
        ) else {
            throw OneTapeArtworkError.unreadable
        }

        // Estimate plain paper brightness from upper luminance pixels so shadows stay steady.
        let total = w * h
        let strideStep = max(1, total / 16_000)
        var lumaSum: Float = 0
        var lumaCount: Float = 0
        var idx = 0
        while idx < total {
            let b = idx * 4
            let a = Float(rgba[b + 3]) / 255.0
            if a > 0.5 {
                let l = luminance(rgba: rgba, offset: b)
                if l > 0.62 {
                    lumaSum += l
                    lumaCount += 1
                }
            }
            idx += strideStep
        }
        let paperLuma = lumaCount >= 16 ? min(0.98, lumaSum / lumaCount) : 0.92
        let threshold = Float(0.055 + recipe.cleanup * 0.22)
        let strengthGain = Float(0.65 + recipe.strength * 0.85)
        let inkRGB = recipe.primaryInk.rgb(for: shell)
        let rByte = UInt8(clamping: Int(inkRGB.r * 255.0))
        let gByte = UInt8(clamping: Int(inkRGB.g * 255.0))
        let bByte = UInt8(clamping: Int(inkRGB.b * 255.0))

        var inkCount = 0
        for px in 0..<total {
            let b = px * 4
            let srcAlpha = Float(rgba[b + 3]) / 255.0
            guard srcAlpha > 0.02 else {
                rgba[b] = 0; rgba[b + 1] = 0; rgba[b + 2] = 0; rgba[b + 3] = 0
                continue
            }
            let l = luminance(rgba: rgba, offset: b)
            let diff = max(0, paperLuma - l)
            guard diff > threshold else {
                rgba[b] = 0; rgba[b + 1] = 0; rgba[b + 2] = 0; rgba[b + 3] = 0
                continue
            }
            let inkAlpha = min(1.0, ((diff - threshold) / max(0.08, paperLuma - threshold)) * strengthGain * srcAlpha)
            let outA = UInt8(clamping: Int(inkAlpha * 255.0))
            rgba[b] = rByte
            rgba[b + 1] = gByte
            rgba[b + 2] = bByte
            rgba[b + 3] = outA
            if outA >= 25 {
                inkCount += 1
            }
        }

        guard inkCount >= max(4, total / 10_000) else {
            throw OneTapeArtworkError.noClearInk
        }
        guard let outCG = OneTapeDrawingPaperInkExtractor.makeCGImage(fromRGBA: rgba, width: w, height: h) else {
            throw OneTapeArtworkError.unreadable
        }
        return UIImage(cgImage: outCG)
    }

    // MARK: - Halftone Dot & Paper-Wear Engine (1000f26b4 + 1000f4a74)

    private static func renderHalftone(
        composedCG: CGImage,
        recipe: OneTapeArtworkRecipe,
        shell: OneTapeAppearance.TapeStyle
    ) throws -> UIImage {
        let w = composedCG.width
        let h = composedCG.height
        guard let srcRGBA = OneTapeDrawingPaperInkExtractor.extractRGBA(
            from: composedCG,
            targetSize: CGSize(width: w, height: h)
        ) else {
            throw OneTapeArtworkError.unreadable
        }

        let maxEdge = CGFloat(max(w, h))
        let resolutionScale = max(0.25, maxEdge / 1200.0)
        let basePitch: CGFloat = (recipe.halftoneStyle == .botanical ? 5.0 : 7.0)
        let pitch = max(3.5, (basePitch + CGFloat(recipe.dotSize) * 13.0) * 1.25 * resolutionScale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let canvasSize = CGSize(width: w, height: h)

        var rendered = UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            let cg = context.cgContext
            switch recipe.halftoneStyle {
            case .mono:
                let positiveLightInk = (recipe.primaryInk == .tapeInk && shell.usesLightInk)
                drawHalftoneScreen(
                    in: cg,
                    rgba: srcRGBA,
                    width: w,
                    height: h,
                    pitch: pitch,
                    angleDegrees: -15,
                    color: recipe.primaryInk.rgb(for: shell),
                    recipe: recipe,
                    blendMode: .normal,
                    seedOffset: 17,
                    densityExtractor: { r, g, b in
                        let l = 0.2126 * r + 0.7152 * g + 0.0722 * b
                        return positiveLightInk ? l : (1.0 - l)
                    }
                )
            case .overprint:
                drawHalftoneScreen(
                    in: cg,
                    rgba: srcRGBA,
                    width: w,
                    height: h,
                    pitch: pitch,
                    angleDegrees: -15,
                    color: recipe.primaryInk.rgb(for: shell),
                    recipe: recipe,
                    blendMode: .normal,
                    seedOffset: 31,
                    densityExtractor: { r, g, b in
                        let l = 0.2126 * r + 0.7152 * g + 0.0722 * b
                        let warmShadow = max(0, (1.0 - l) * (0.72 + 0.28 * (r - b)))
                        return min(1.0, warmShadow)
                    }
                )
                drawHalftoneScreen(
                    in: cg,
                    rgba: srcRGBA,
                    width: w,
                    height: h,
                    pitch: pitch,
                    angleDegrees: 15,
                    color: recipe.secondaryInk.rgb(for: shell),
                    recipe: recipe,
                    blendMode: .multiply,
                    seedOffset: 97,
                    densityExtractor: { r, g, b in
                        let l = 0.2126 * r + 0.7152 * g + 0.0722 * b
                        let coolMid = max(0, (1.0 - l) * (0.62 + 0.38 * (b - r + 0.3)))
                        return min(1.0, coolMid)
                    }
                )
            case .botanical:
                let ink1 = recipe.primaryInk.rgb(for: shell)
                let ink2 = OneTapeArtworkInk.olive.rgb(for: shell)
                let ink3 = OneTapeArtworkInk.amber.rgb(for: shell)
                drawHalftoneScreen(
                    in: cg,
                    rgba: srcRGBA,
                    width: w,
                    height: h,
                    pitch: pitch,
                    angleDegrees: -15,
                    color: ink1,
                    recipe: recipe,
                    blendMode: .normal,
                    seedOffset: 11,
                    densityExtractor: { r, g, b in
                        let l = 0.2126 * r + 0.7152 * g + 0.0722 * b
                        return max(0, (1.0 - l) * 0.92 - max(0, g - max(r, b)) * 0.35)
                    }
                )
                drawHalftoneScreen(
                    in: cg,
                    rgba: srcRGBA,
                    width: w,
                    height: h,
                    pitch: pitch,
                    angleDegrees: 15,
                    color: ink2,
                    recipe: recipe,
                    blendMode: .multiply,
                    seedOffset: 53,
                    densityExtractor: { r, g, b in
                        let greenness = max(0, g - 0.5 * (r + b))
                        let l = 0.2126 * r + 0.7152 * g + 0.0722 * b
                        return min(1.0, greenness * 1.45 + (1.0 - l) * 0.32)
                    }
                )
                drawHalftoneScreen(
                    in: cg,
                    rgba: srcRGBA,
                    width: w,
                    height: h,
                    pitch: pitch,
                    angleDegrees: 45,
                    color: ink3,
                    recipe: recipe,
                    blendMode: .multiply,
                    seedOffset: 89,
                    densityExtractor: { r, g, b in
                        let warmth = max(0, (r * 0.8 + g * 0.45) - b * 1.1)
                        return min(1.0, warmth * 0.72)
                    }
                )
            }
        }

        if recipe.inkWear > 0.02, let wornCG = rendered.cgImage {
            rendered = applyPaperWearPostPass(to: wornCG, wear: Float(recipe.inkWear), scaleFactor: Float(resolutionScale))
        }
        return rendered
    }

    private static func drawHalftoneScreen(
        in cg: CGContext,
        rgba: [UInt8],
        width: Int,
        height: Int,
        pitch: CGFloat,
        angleDegrees: CGFloat,
        color: (r: Double, g: Double, b: Double),
        recipe: OneTapeArtworkRecipe,
        blendMode: CGBlendMode,
        seedOffset: Int,
        densityExtractor: (_ r: Float, _ g: Float, _ b: Float) -> Float
    ) {
        cg.saveGState()
        cg.setBlendMode(blendMode)
        cg.setFillColor(red: color.r, green: color.g, blue: color.b, alpha: 1)

        let angle = angleDegrees * .pi / 180.0
        let cosA = cos(angle)
        let sinA = sin(angle)
        let cx = CGFloat(width) * 0.5
        let cy = CGFloat(height) * 0.5
        let halfDiag = hypot(CGFloat(width), CGFloat(height)) * 0.5 + pitch
        let minGrid = Int(floor(-halfDiag / pitch))
        let maxGrid = Int(ceil(halfDiag / pitch))

        let sampleStep = max(1.0, pitch / 3.0)
        let gamma = Float(1.65 - recipe.strength * 0.95)
        let wearJitter = CGFloat(recipe.inkWear) * 0.24

        for gy in minGrid...maxGrid {
            let uy = CGFloat(gy) * pitch
            for gx in minGrid...maxGrid {
                let ux = CGFloat(gx) * pitch
                let centerX = cx + ux * cosA - uy * sinA
                let centerY = cy + ux * sinA + uy * cosA
                guard centerX > -pitch && centerX < CGFloat(width) + pitch,
                      centerY > -pitch && centerY < CGFloat(height) + pitch else {
                    continue
                }

                // 3x3 cell supersampling around dot center.
                var densitySum: Float = 0
                var alphaSum: Float = 0
                for sy in -1...1 {
                    for sx in -1...1 {
                        let px = Int(round(centerX + CGFloat(sx) * sampleStep))
                        let py = Int(round(centerY + CGFloat(sy) * sampleStep))
                        guard px >= 0, px < width, py >= 0, py < height else { continue }
                        let base = (py * width + px) * 4
                        let a = Float(rgba[base + 3]) / 255.0
                        guard a > 0.02 else { continue }
                        let r = Float(rgba[base]) / 255.0
                        let g = Float(rgba[base + 1]) / 255.0
                        let b = Float(rgba[base + 2]) / 255.0
                        densitySum += densityExtractor(r, g, b) * a
                        alphaSum += a
                    }
                }
                guard alphaSum > 0.05 else { continue }

                let avgDensity = min(1.0, max(0.0, powf(densitySum / 9.0, gamma)))
                guard avgDensity > 0.015 else { continue }

                let radius = sqrt(CGFloat(avgDensity)) * pitch * 0.55
                guard radius > 0.35 else { continue }

                // Deterministic 12-gon organic ink dot avoiding sterile computer circles.
                let cellHash = hashCell(gx: gx, gy: gy, seed: seedOffset)
                cg.beginPath()
                for vertex in 0..<12 {
                    let theta = (CGFloat(vertex) / 12.0) * (.pi * 2.0)
                    let jitter = 1.0 + wearJitter * hashSigned(hash: cellHash ^ (vertex &* 2654435761))
                    let vr = radius * jitter
                    let vx = centerX + cos(theta) * vr
                    let vy = centerY + sin(theta) * vr
                    if vertex == 0 {
                        cg.move(to: CGPoint(x: vx, y: vy))
                    } else {
                        cg.addLine(to: CGPoint(x: vx, y: vy))
                    }
                }
                cg.closePath()
                cg.fillPath()
            }
        }
        cg.restoreGState()
    }

    private static func applyPaperWearPostPass(to cgImage: CGImage, wear: Float, scaleFactor: Float) -> UIImage {
        let w = cgImage.width
        let h = cgImage.height
        guard var rgba = OneTapeDrawingPaperInkExtractor.extractRGBA(
            from: cgImage,
            targetSize: CGSize(width: w, height: h)
        ) else {
            return UIImage(cgImage: cgImage)
        }
        let invScale = 1.0 / max(0.35, scaleFactor)
        for y in 0..<h {
            let fy = Float(y) * invScale
            for x in 0..<w {
                let base = (y * w + x) * 4
                let a = rgba[base + 3]
                guard a > 0 else { continue }
                let fx = Float(x) * invScale
                let wave = sinf(fx * 0.21 + sinf(fy * 0.14) * 1.35) * cosf(fy * 0.19 - fx * 0.07)
                let keepFactor = max(0.22, min(1.0, 1.0 - wear * 0.42 * (0.5 - 0.5 * wave)))
                rgba[base + 3] = UInt8(clamping: Int(Float(a) * keepFactor))
            }
        }
        guard let outCG = OneTapeDrawingPaperInkExtractor.makeCGImage(fromRGBA: rgba, width: w, height: h) else {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(cgImage: outCG)
    }

    // MARK: - Helpers

    private static func cropImage(_ image: UIImage, normalizedRect: OneTapeNormalizedRect) -> UIImage {
        let rect = normalizedRect.clamped
        guard let cg = image.cgImage else { return image }
        let pixelRect = CGRect(
            x: rect.x * Double(cg.width),
            y: rect.y * Double(cg.height),
            width: rect.width * Double(cg.width),
            height: rect.height * Double(cg.height)
        ).integral
        guard let croppedCG = cg.cropping(to: pixelRect) else { return image }
        return UIImage(cgImage: croppedCG)
    }

    private static func countVisibleAlphaPixels(in cgImage: CGImage, threshold: UInt8) -> Int {
        guard let rgba = OneTapeDrawingPaperInkExtractor.extractRGBA(
            from: cgImage,
            targetSize: CGSize(width: cgImage.width, height: cgImage.height)
        ) else {
            return 0
        }
        var count = 0
        for idx in 0..<(rgba.count / 4) where rgba[idx * 4 + 3] >= threshold {
            count += 1
        }
        return count
    }

    private static func luminance(rgba: [UInt8], offset: Int) -> Float {
        let r = Float(rgba[offset]) / 255.0
        let g = Float(rgba[offset + 1]) / 255.0
        let b = Float(rgba[offset + 2]) / 255.0
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private static func hashCell(gx: Int, gy: Int, seed: Int) -> Int {
        var h = gx &* 374761393 &+ gy &* 668265263 &+ seed &* 1442695041
        h = (h ^ (h >> 13)) &* 1274126177
        return h ^ (h >> 16)
    }

    private static func hashSigned(hash: Int) -> CGFloat {
        let low = UInt32(truncatingIfNeeded: hash)
        let norm = CGFloat(low & 0xFFFF) / 65535.0
        return norm * 2.0 - 1.0
    }
}
