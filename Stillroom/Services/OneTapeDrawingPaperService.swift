import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit
import Vision

enum OneTapeDrawingPaperService {
    static func paperFileName(for style: OneTapeAppearance.TapeStyle) -> String {
        "Cassette paper - \(style.customizationTitle).png"
    }

    @MainActor
    static func renderMaskPixels(for style: OneTapeAppearance.TapeStyle) -> [UInt8]? {
        let size = CGSize(width: 1129, height: 1728)
        let maskView = OneTapeShellPrintMask(tapeStyle: style)
            .frame(width: 376.33, height: 576)
        let renderer = ImageRenderer(content: maskView)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(OneTapeDrawingGeometry.cassettePortraitSize)
        guard let cgMask = renderer.cgImage else { return nil }
        return OneTapeDrawingPaperInkExtractor.extractRGBA(from: cgMask, targetSize: size)
    }

    @MainActor
    static func generatePaperImage(for style: OneTapeAppearance.TapeStyle) -> UIImage? {
        guard let maskRGBA = renderMaskPixels(for: style) else { return nil }
        return generatePaperImage(fromPortraitMaskRGBA: maskRGBA, width: 1129, height: 1728)
    }

    /// Pure geometry + color template composer for both runtime UI export and deterministic unit tests.
    static func generatePaperImage(fromPortraitMaskRGBA maskRGBA: [UInt8], width maskW: Int, height maskH: Int) -> UIImage? {
        let canvasSize = OneTapeDrawingGeometry.paperCanvasPixelSize
        let margin = OneTapeDrawingGeometry.paperMarginPixels
        let innerRect = CGRect(
            x: margin,
            y: margin,
            width: canvasSize.width - margin * 2,
            height: canvasSize.height - margin * 2
        )

        let landscapeAspect = CGFloat(maskH) / CGFloat(maskW)
        let fittedHeight = innerRect.width / landscapeAspect
        let fittedRect = CGRect(
            x: innerRect.minX,
            y: innerRect.minY + (innerRect.height - fittedHeight) * 0.5,
            width: innerRect.width,
            height: fittedHeight
        )

        guard let landscapeCutoutImage = buildLandscapeCutoutOverlay(
            fromPortraitMaskRGBA: maskRGBA,
            maskWidth: maskW,
            maskHeight: maskH
        ) else {
            return nil
        }

        let cream = OneTapeDrawingPaperInkExtractor.paperCream
        let guide = OneTapeDrawingPaperInkExtractor.guideBlue
        let creamColor = UIColor(red: CGFloat(cream.r), green: CGFloat(cream.g), blue: CGFloat(cream.b), alpha: 1)
        let guideColor = UIColor(red: CGFloat(guide.r), green: CGFloat(guide.g), blue: CGFloat(guide.b), alpha: 1)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            let cg = context.cgContext
            creamColor.setFill()
            cg.fill(CGRect(origin: .zero, size: canvasSize))

            UIImage(cgImage: landscapeCutoutImage).draw(in: fittedRect)

            guideColor.withAlphaComponent(0.35).setStroke()
            let border = UIBezierPath(rect: fittedRect)
            border.lineWidth = 2
            border.stroke()

            drawCornerBrackets(in: innerRect, color: guideColor)

            let instruction = "在画纸上绘画。蓝色区域是磁带上的镂空部分。画好后，到“自定义 → 印花”中导入。"
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .medium),
                .foregroundColor: guideColor,
                .paragraphStyle: paragraph
            ]
            let textRect = CGRect(
                x: margin,
                y: canvasSize.height - margin + 42,
                width: canvasSize.width - margin * 2,
                height: 60
            )
            NSString(string: instruction).draw(in: textRect, withAttributes: attrs)
        }
    }

    static func writeTemporaryPaperFile(for image: UIImage, style: OneTapeAppearance.TapeStyle) throws -> URL {
        guard let data = image.pngData() else {
            throw OneTapeDrawingPaperError.saveFailed
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneTapePaperExports", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let url = dir.appendingPathComponent(paperFileName(for: style))
        try data.write(to: url, options: .atomic)
        return url
    }

    static func suggestedInkMode(for portraitImage: UIImage) -> OneTapeDrawingInkMode {
        guard let cgImage = portraitImage.cgImage,
              let rgba = OneTapeDrawingPaperInkExtractor.extractRGBA(from: cgImage, targetSize: CGSize(width: 120, height: 184)) else {
            return .tapeInk
        }
        var saturationSum: Float = 0
        var weightedCount: Float = 0
        for idx in 0..<(rgba.count / 4) {
            let base = idx * 4
            let a = Float(rgba[base + 3]) / 255.0
            guard a > 0.25 else { continue }
            let r = Float(rgba[base]) / 255.0
            let g = Float(rgba[base + 1]) / 255.0
            let b = Float(rgba[base + 2]) / 255.0
            let hi = max(r, max(g, b))
            let lo = min(r, min(g, b))
            let sat = hi > 0.001 ? (hi - lo) / hi : 0
            saturationSum += sat
            weightedCount += 1
        }
        guard weightedCount > 0 else { return .tapeInk }
        return (saturationSum / weightedCount) > 0.20 ? .originalColors : .tapeInk
    }

    static func extractImportedDrawingAsync(fromData data: Data) async throws -> OneTapeImportedPaper {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            guard let image = UIImage(data: data) else {
                throw OneTapeDrawingPaperError.unreadable
            }
            return try extractImportedDrawing(from: image)
        }.value
    }

    static func extractImportedDrawingAsync(fromFileURL url: URL) async throws -> OneTapeImportedPaper {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let secured = url.startAccessingSecurityScopedResource()
            defer {
                if secured { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url)
            guard let image = UIImage(data: data) else {
                throw OneTapeDrawingPaperError.unreadable
            }
            return try extractImportedDrawing(from: image)
        }.value
    }

    static func extractImportedDrawing(from sourceImage: UIImage) throws -> OneTapeImportedPaper {
        guard let normalized = OneTapeDrawingPaperInkExtractor.normalizeUpOrientation(sourceImage, maxDimension: 2604),
              let cgSource = normalized.cgImage else {
            throw OneTapeDrawingPaperError.unreadable
        }

        if let transparentResult = OneTapeDrawingPaperInkExtractor.tryExtractTransparentArtworkIfApplicable(from: normalized, cgImage: cgSource) {
            return transparentResult
        }

        let (workingImage, recognizedPaper) = detectAndCropTemplatePaperIfPresent(normalized, cgImage: cgSource)
        guard let workingCG = workingImage.cgImage else {
            throw OneTapeDrawingPaperError.unreadable
        }

        let width = workingCG.width
        let height = workingCG.height
        guard var rgba = OneTapeDrawingPaperInkExtractor.extractRGBA(from: workingCG, targetSize: CGSize(width: width, height: height)) else {
            throw OneTapeDrawingPaperError.unreadable
        }

        let paperColor = OneTapeDrawingPaperInkExtractor.estimatePaperBackgroundColor(rgba: rgba, width: width, height: height)
        let inkCount = OneTapeDrawingPaperInkExtractor.stripBackgroundAndBlueCutouts(rgba: &rgba, paper: paperColor)
        let totalPixels = width * height
        guard inkCount >= max(4, totalPixels / 10_000) else {
            throw OneTapeDrawingPaperError.noDrawing
        }

        guard let extractedCG = OneTapeDrawingPaperInkExtractor.makeCGImage(fromRGBA: rgba, width: width, height: height) else {
            throw OneTapeDrawingPaperError.unreadable
        }

        let extractedUI = UIImage(cgImage: extractedCG)
        let portraitImage = OneTapeDrawingPaperInkExtractor.orientExtractedToPortrait(extractedUI)
        return OneTapeImportedPaper(image: portraitImage, recognizedPaper: recognizedPaper)
    }

    private static func buildLandscapeCutoutOverlay(
        fromPortraitMaskRGBA maskRGBA: [UInt8],
        maskWidth: Int,
        maskHeight: Int
    ) -> CGImage? {
        let outW = maskHeight
        let outH = maskWidth
        guard maskRGBA.count >= maskWidth * maskHeight * 4 else { return nil }

        var outRGBA = [UInt8](repeating: 0, count: outW * outH * 4)
        let cutout = OneTapeDrawingPaperInkExtractor.cutoutBlue
        let blueR = UInt8(clamping: Int(cutout.r * 255))
        let blueG = UInt8(clamping: Int(cutout.g * 255))
        let blueB = UInt8(clamping: Int(cutout.b * 255))

        for py in 0..<maskHeight {
            for px in 0..<maskWidth {
                let srcIndex = (py * maskWidth + px) * 4
                let maskAlpha = maskRGBA[srcIndex + 3]
                if maskAlpha < 128 {
                    let lx = py
                    let ly = maskWidth - 1 - px
                    let dstIndex = (ly * outW + lx) * 4
                    outRGBA[dstIndex] = blueR
                    outRGBA[dstIndex + 1] = blueG
                    outRGBA[dstIndex + 2] = blueB
                    outRGBA[dstIndex + 3] = 255 - maskAlpha
                }
            }
        }
        return OneTapeDrawingPaperInkExtractor.makeCGImage(fromRGBA: outRGBA, width: outW, height: outH)
    }

    private static func drawCornerBrackets(in innerRect: CGRect, color: UIColor) {
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: innerRect.minX, y: innerRect.minY), 1, 1),
            (CGPoint(x: innerRect.maxX, y: innerRect.minY), -1, 1),
            (CGPoint(x: innerRect.minX, y: innerRect.maxY), 1, -1),
            (CGPoint(x: innerRect.maxX, y: innerRect.maxY), -1, -1)
        ]
        let path = UIBezierPath()
        for (origin, sx, sy) in corners {
            path.move(to: CGPoint(x: origin.x + sx * 24, y: origin.y))
            path.addLine(to: CGPoint(x: origin.x + sx * 110, y: origin.y))
            path.move(to: CGPoint(x: origin.x, y: origin.y + sy * 24))
            path.addLine(to: CGPoint(x: origin.x, y: origin.y + sy * 110))
        }
        path.lineWidth = 4
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }

    private static func detectAndCropTemplatePaperIfPresent(
        _ image: UIImage,
        cgImage: CGImage
    ) -> (UIImage, Bool) {
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let aspect = w / max(1, h)
        let expectedAspect = OneTapeDrawingGeometry.paperCanvasPixelSize.width / OneTapeDrawingGeometry.paperCanvasPixelSize.height

        if abs(aspect - expectedAspect) < 0.08, OneTapeDrawingPaperInkExtractor.containsTemplateBlue(in: cgImage) {
            let cropRect = CGRect(
                x: (w / 2604.0) * 150.0,
                y: (h / 1836.0) * 150.0,
                width: (w / 2604.0) * 2304.0,
                height: (h / 1836.0) * 1536.0
            ).integral
            if let cropped = cgImage.cropping(to: cropRect) {
                return (UIImage(cgImage: cropped), true)
            }
        }

        if let rectified = detectAndRectifyDocument(from: cgImage),
           let rectifiedCG = rectified.cgImage,
           OneTapeDrawingPaperInkExtractor.containsTemplateBlue(in: rectifiedCG) {
            let rw = CGFloat(rectifiedCG.width)
            let rh = CGFloat(rectifiedCG.height)
            let cropRect = CGRect(
                x: (rw / 2604.0) * 150.0,
                y: (rh / 1836.0) * 150.0,
                width: (rw / 2604.0) * 2304.0,
                height: (rh / 1836.0) * 1536.0
            ).integral
            if let cropped = rectifiedCG.cropping(to: cropRect) {
                return (UIImage(cgImage: cropped), true)
            }
        }

        return (image, false)
    }

    private static func detectAndRectifyDocument(from cgImage: CGImage) -> UIImage? {
        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        guard let observation = request.results?.first else {
            return nil
        }

        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        let scalePoint: (CGPoint) -> CGPoint = { normalized in
            CGPoint(x: normalized.x * extent.width, y: normalized.y * extent.height)
        }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciImage
        filter.topLeft = scalePoint(observation.topLeft)
        filter.topRight = scalePoint(observation.topRight)
        filter.bottomRight = scalePoint(observation.bottomRight)
        filter.bottomLeft = scalePoint(observation.bottomLeft)

        guard var output = filter.outputImage else { return nil }
        if output.extent.height > output.extent.width {
            output = output.transformed(by: CGAffineTransform(rotationAngle: -.pi / 2))
        }

        let context = CIContext()
        guard let rectifiedCG = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: rectifiedCG)
    }
}
