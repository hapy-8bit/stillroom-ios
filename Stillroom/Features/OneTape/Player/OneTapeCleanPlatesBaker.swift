import CoreGraphics
import Metal

/// Bakes the deterministic 2× (786×1704) anodized gunmetal CNC plate layout
/// for `.cleanPlates` (`DuoFrontCleanPlatesThumb` craft, adapted cleanly to
/// the iPhone 393×852 deck with concentric top-left CNC rings, recessed dark
/// key bay, clean middle bridge, and modular lower indicator blocks).
@MainActor
enum OneTapeCleanPlatesBaker {
    static func baseTexture() -> MTLTexture? {
        OneTapeBodyMetalEngine.shared.cachedTexture(key: "body.cleanPlates.base.v1") { ctx, rect in
            drawAnodizedGunmetalBase(in: ctx, rect: rect)
            drawTopConcentricCornerPlate(in: ctx)
            drawTopMainPlateAndSlot(in: ctx)
            drawRightRailSplitAndKnurl(in: ctx)
            drawSteppedKeyWell(in: ctx)
            drawBottomModularPlates(in: ctx)
            drawTorxScrews(in: ctx)
        }
    }

    private static func drawAnodizedGunmetalBase(in ctx: CGContext, rect: CGRect) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let colors = [
            CGColor(colorSpace: cs, components: [0.465, 0.478, 0.490, 1])!,
            CGColor(colorSpace: cs, components: [0.415, 0.428, 0.440, 1])!,
            CGColor(colorSpace: cs, components: [0.375, 0.388, 0.400, 1])!
        ] as CFArray
        if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 0.52, 1]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 20, y: 0), end: CGPoint(x: 373, y: 852), options: [])
        }
    }

    private static func drawTopConcentricCornerPlate(in ctx: CGContext) {
        // Dedicated top-left CNC-lathed plate framing the playback mode button.
        let plateRect = CGRect(x: 0, y: 0, width: 88, height: 63)
        ctx.saveGState()
        ctx.clip(to: plateRect)

        ctx.setFillColor(red: 0.41, green: 0.42, blue: 0.435, alpha: 1.0)
        ctx.fill(plateRect)

        // Subtle fine concentric lathe grooves radiating cleanly around the mode key.
        let center = CGPoint(x: OneTapeTransportGeometry.centerX, y: 34)
        for ring in 10..<42 {
            let r = CGFloat(ring) * 2.2
            let circle = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.16)
            ctx.setLineWidth(0.95)
            ctx.strokeEllipse(in: circle)

            ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.085)
            ctx.setLineWidth(0.55)
            ctx.strokeEllipse(in: circle.insetBy(dx: -0.75, dy: -0.75))
        }
        ctx.restoreGState()

        // Crisp dark vertical & horizontal CNC plate parting seams.
        drawMachinedSeam(in: ctx, from: CGPoint(x: 88, y: 0), to: CGPoint(x: 88, y: 63))
        drawMachinedSeam(in: ctx, from: CGPoint(x: 0, y: 63), to: CGPoint(x: 88, y: 63))
    }

    private static func drawTopMainPlateAndSlot(in ctx: CGContext) {
        let topPlate = CGRect(x: 89.2, y: 0, width: 303.8, height: 63)
        ctx.setFillColor(red: 0.47, green: 0.482, blue: 0.495, alpha: 1.0)
        ctx.fill(topPlate)

        // Subtle recessed horizontal milled ear-slot accent on the top plate.
        let slot = CGRect(x: 174, y: 26.5, width: 78, height: 4.4)
        let slotPath = CGPath(roundedRect: slot, cornerWidth: 2.2, cornerHeight: 2.2, transform: nil)
        ctx.setFillColor(red: 0.24, green: 0.25, blue: 0.26, alpha: 0.92)
        ctx.addPath(slotPath)
        ctx.fillPath()
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.22)
        ctx.setLineWidth(0.7)
        ctx.move(to: CGPoint(x: slot.minX + 2, y: slot.maxY + 0.6))
        ctx.addLine(to: CGPoint(x: slot.maxX - 2, y: slot.maxY + 0.6))
        ctx.strokePath()

        drawMachinedSeam(in: ctx, from: CGPoint(x: 89, y: 63), to: CGPoint(x: 393, y: 63))
    }

    private static func drawRightRailSplitAndKnurl(in ctx: CGContext) {
        // Subtle recessed micro-knurled lower right rail plate matching Cassette's tactile side block.
        let knurlPlate = CGRect(x: 375, y: 346, width: 18, height: 472)
        ctx.saveGState()
        ctx.clip(to: knurlPlate)
        ctx.setFillColor(red: 0.37, green: 0.382, blue: 0.394, alpha: 1.0)
        ctx.fill(knurlPlate)

        ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.075)
        ctx.setLineWidth(0.6)
        for y in stride(from: knurlPlate.minY - 20, through: knurlPlate.maxY + 20, by: 3.2) {
            ctx.move(to: CGPoint(x: knurlPlate.minX, y: y))
            ctx.addLine(to: CGPoint(x: knurlPlate.maxX, y: y + 18))
            ctx.move(to: CGPoint(x: knurlPlate.maxX, y: y))
            ctx.addLine(to: CGPoint(x: knurlPlate.minX, y: y + 18))
        }
        ctx.strokePath()
        ctx.restoreGState()

        drawMachinedSeam(in: ctx, from: CGPoint(x: 374, y: 346), to: CGPoint(x: 393, y: 346))
    }

    private static func drawSteppedKeyWell(in ctx: CGContext) {
        // Iconic recessed matte charcoal pill cavity housing the 3 gunmetal keys.
        let well = CGRect(x: 13.5, y: 632.0, width: 69.2, height: 204.0)
        let path = CGPath(roundedRect: well, cornerWidth: 34.6, cornerHeight: 34.6, transform: nil)

        // Outer beveled aluminum catch-light along bottom-right edge.
        ctx.saveGState()
        ctx.translateBy(x: 0.8, y: 1.0)
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.24)
        ctx.setLineWidth(1.5)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        // Deep charcoal anodized cavity interior.
        ctx.setFillColor(red: 0.165, green: 0.172, blue: 0.180, alpha: 1.0)
        ctx.addPath(path)
        ctx.fillPath()

        // Inner top-left shadow lip.
        ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.56)
        ctx.setLineWidth(1.6)
        ctx.addPath(path)
        ctx.strokePath()
    }

    private static func drawBottomModularPlates(in ctx: CGContext) {
        // Top seam separating the LCD bottom bezel from the three interlocking CNC bottom plates.
        drawMachinedSeam(in: ctx, from: CGPoint(x: 96, y: 820.5), to: CGPoint(x: 393, y: 820.5))

        // Block 1: Lighter brushed anodized silver-grey plate.
        let block1 = CGRect(x: 98, y: 821.8, width: 112, height: 27.5)
        let b1Path = CGPath(roundedRect: block1, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
        ctx.saveGState()
        ctx.addPath(b1Path)
        ctx.clip()
        ctx.setFillColor(red: 0.54, green: 0.552, blue: 0.565, alpha: 1.0)
        ctx.fill(block1)
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.06)
        ctx.setLineWidth(0.5)
        for x in stride(from: block1.minX, through: block1.maxX, by: 2.0) {
            ctx.move(to: CGPoint(x: x, y: block1.minY))
            ctx.addLine(to: CGPoint(x: x, y: block1.maxY))
        }
        ctx.strokePath()
        ctx.restoreGState()
        drawPlateOutline(in: ctx, path: b1Path)

        // Block 2: Medium gunmetal plate with twin dark recessed pinholes + circular brushed dial cap.
        let block2 = CGRect(x: 213, y: 821.8, width: 114, height: 27.5)
        let b2Path = CGPath(roundedRect: block2, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
        ctx.setFillColor(red: 0.445, green: 0.456, blue: 0.470, alpha: 1.0)
        ctx.addPath(b2Path)
        ctx.fillPath()
        drawPlateOutline(in: ctx, path: b2Path)

        // Twin recessed acoustic/sensor pinholes.
        for x in [CGFloat(238), 252] {
            let hole = CGRect(x: x - 2.7, y: 832.8, width: 5.4, height: 5.4)
            ctx.setFillColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 1.0)
            ctx.fillEllipse(in: hole)
            ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.24)
            ctx.setLineWidth(0.6)
            ctx.strokeEllipse(in: hole.insetBy(dx: -0.4, dy: -0.4))
        }

        // Machined circular brushed aluminum cap (signature detail from DuoFrontCleanPlatesThumb).
        let capCenter = CGPoint(x: 304, y: 835.5)
        let capRect = CGRect(x: capCenter.x - 9.0, y: capCenter.y - 9.0, width: 18.0, height: 18.0)
        let cs = CGColorSpaceCreateDeviceRGB()
        ctx.saveGState()
        ctx.addEllipse(in: capRect)
        ctx.clip()
        let capColors = [
            CGColor(colorSpace: cs, components: [0.68, 0.70, 0.72, 1])!,
            CGColor(colorSpace: cs, components: [0.46, 0.47, 0.49, 1])!,
            CGColor(colorSpace: cs, components: [0.62, 0.64, 0.66, 1])!
        ] as CFArray
        if let grad = CGGradient(colorsSpace: cs, colors: capColors, locations: [0, 0.5, 1]) {
            ctx.drawLinearGradient(
                grad,
                start: CGPoint(x: capRect.minX, y: capRect.minY),
                end: CGPoint(x: capRect.maxX, y: capRect.maxY),
                options: []
            )
        }
        ctx.restoreGState()
        ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.34)
        ctx.setLineWidth(0.75)
        ctx.strokeEllipse(in: capRect)

        // Block 3: Darker micro-textured status block with crisp vermilion-red square indicator.
        let block3 = CGRect(x: 330, y: 821.8, width: 34, height: 27.5)
        let b3Path = CGPath(roundedRect: block3, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
        ctx.setFillColor(red: 0.285, green: 0.295, blue: 0.308, alpha: 1.0)
        ctx.addPath(b3Path)
        ctx.fillPath()
        drawPlateOutline(in: ctx, path: b3Path)

        let redDot = CGRect(x: block3.midX - 2.3, y: block3.midY - 2.3, width: 4.6, height: 4.6)
        ctx.setFillColor(red: 0.84, green: 0.21, blue: 0.17, alpha: 1.0)
        ctx.fill(redDot)
    }

    private static func drawPlateOutline(in ctx: CGContext, path: CGPath) {
        ctx.setStrokeColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 0.78)
        ctx.setLineWidth(1.0)
        ctx.addPath(path)
        ctx.strokePath()
    }

    private static func drawMachinedSeam(in ctx: CGContext, from a: CGPoint, to b: CGPoint) {
        ctx.setStrokeColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 0.85)
        ctx.setLineWidth(1.1)
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()

        let dx: CGFloat = a.x == b.x ? 1.0 : 0
        let dy: CGFloat = a.y == b.y ? 1.0 : 0
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.16)
        ctx.setLineWidth(0.65)
        ctx.move(to: CGPoint(x: a.x + dx, y: a.y + dy))
        ctx.addLine(to: CGPoint(x: b.x + dx, y: b.y + dy))
        ctx.strokePath()
    }

    private static func drawTorxScrews(in ctx: CGContext) {
        for center in [CGPoint(x: 102, y: 20), CGPoint(x: 368, y: 20), CGPoint(x: 379, y: 834)] {
            let well = CGRect(x: center.x - 4.4, y: center.y - 4.4, width: 8.8, height: 8.8)
            ctx.setFillColor(red: 0.14, green: 0.15, blue: 0.16, alpha: 0.85)
            ctx.fillEllipse(in: well)

            let head = CGRect(x: center.x - 3.3, y: center.y - 3.3, width: 6.6, height: 6.6)
            ctx.setFillColor(red: 0.62, green: 0.64, blue: 0.66, alpha: 1.0)
            ctx.fillEllipse(in: head)

            // 6-point star Torx recess.
            ctx.setStrokeColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 0.88)
            ctx.setLineWidth(0.7)
            for i in 0..<3 {
                let angle = CGFloat(i) * .pi / 3
                let dx = cos(angle) * 1.9
                let dy = sin(angle) * 1.9
                ctx.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
                ctx.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
            }
            ctx.strokePath()
        }
    }
}
