import CoreGraphics
import Metal

/// Bakes deterministic 2× (786×1704) crafted tactile shell textures once per session:
/// - `.linen`: coarse oatmeal woven flax burlap, tailored dashed border stitching,
///   and raised hand-embroidered retro music patches (`DuoFrontLinenThumb` craft).
/// - `.stickerBomb`: pebbled matte charcoal housing layered with overlapping vibrant
///   hand-illustrated die-cut retro vinyl decals (`DuoFrontStickerThumb` craft).
@MainActor
enum OneTapeCraftedTextureBakers {

    // MARK: - 1. Woven Oatmeal Linen + Embroidered Music Patches

    static func linenBaseTexture() -> MTLTexture? {
        OneTapeBodyMetalEngine.shared.cachedTexture(key: "body.linen.base.v1") { ctx, rect in
            drawWovenFlaxBase(in: ctx, rect: rect)
            drawTailoredStitching(in: ctx, rect: rect)
            drawEmbroideredPatches(in: ctx)
        }
    }

    private static func drawWovenFlaxBase(in ctx: CGContext, rect: CGRect) {
        ctx.setFillColor(red: 0.775, green: 0.705, blue: 0.595, alpha: 1.0)
        ctx.fill(rect)

        // Coarse horizontal weft threads with natural oatmeal flax slub tone variation.
        var y: CGFloat = 0
        var row = 0
        while y < rect.height {
            let n = hash(row * 13 + 7)
            let bright = (n - 0.5) * 0.13
            ctx.setFillColor(red: 0.79 + bright, green: 0.72 + bright * 0.92, blue: 0.61 + bright * 0.85, alpha: 0.72)
            ctx.fill(CGRect(x: 0, y: y, width: rect.width, height: 1.45))
            ctx.setFillColor(red: 0.44, green: 0.36, blue: 0.27, alpha: 0.16)
            ctx.fill(CGRect(x: 0, y: y + 1.45, width: rect.width, height: 0.65))
            y += 2.6
            row += 1
        }

        // Interlocking vertical warp threads creating authentic cross-woven burlap relief.
        var x: CGFloat = 0
        var col = 0
        while x < rect.width {
            let n = hash(col * 19 + 3)
            let bright = (n - 0.5) * 0.12
            ctx.setFillColor(red: 0.81 + bright, green: 0.745 + bright * 0.92, blue: 0.635 + bright * 0.84, alpha: 0.52)
            ctx.fill(CGRect(x: x, y: 0, width: 1.35, height: rect.height))
            ctx.setFillColor(red: 0.42, green: 0.34, blue: 0.25, alpha: 0.15)
            ctx.fill(CGRect(x: x + 1.35, y: 0, width: 0.65, height: rect.height))
            x += 2.6
            col += 1
        }

        // Subtle organic flax flecks scattered naturally through the weave.
        for i in 0..<240 {
            let fx = hash(i * 11 + 1) * rect.width
            let fy = hash(i * 11 + 2) * rect.height
            let len = 3.5 + hash(i * 11 + 3) * 9.0
            let horizontal = i % 2 == 0
            ctx.setFillColor(red: 0.50, green: 0.41, blue: 0.30, alpha: 0.20)
            ctx.fill(CGRect(x: fx, y: fy, width: horizontal ? len : 1.1, height: horizontal ? 1.1 : len))
        }
    }

    private static func drawTailoredStitching(in ctx: CGContext, rect: CGRect) {
        let stitchPaths: [CGPath] = [
            CGPath(roundedRect: rect.insetBy(dx: 4.5, dy: 4.5), cornerWidth: 54.5, cornerHeight: 54.5, transform: nil),
            CGPath(roundedRect: OneTapeCassettePocketMask.openingFrame.insetBy(dx: -5.2, dy: -5.2),
                   cornerWidth: 23.5, cornerHeight: 23.5, transform: nil)
        ]

        ctx.setLineCap(.round)
        ctx.setLineDash(phase: 0, lengths: [3.6, 3.2])
        for path in stitchPaths {
            ctx.saveGState()
            ctx.translateBy(x: 0.6, y: 0.8)
            ctx.setStrokeColor(red: 1, green: 0.96, blue: 0.88, alpha: 0.34)
            ctx.setLineWidth(1.3)
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()

            ctx.setStrokeColor(red: 0.36, green: 0.27, blue: 0.18, alpha: 0.78)
            ctx.setLineWidth(1.35)
            ctx.addPath(path)
            ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: [])
    }

    private static func drawEmbroideredPatches(in ctx: CGContext) {
        // Top bezel embroidered music patches (right of top-left mode key).
        drawEmbroideredCassette(in: ctx, center: CGPoint(x: 118, y: 34), angle: -0.09, scale: 0.95)
        drawEmbroideredNote(in: ctx, center: CGPoint(x: 168, y: 35), double: true,
                            rgb: (0.19, 0.35, 0.22), angle: 0.06, scale: 0.92)
        drawEmbroideredHeadphones(in: ctx, center: CGPoint(x: 218, y: 34), angle: -0.04, scale: 0.96)
        drawEmbroideredVinyl(in: ctx, center: CGPoint(x: 274, y: 34), radius: 15.5)
        drawEmbroideredNote(in: ctx, center: CGPoint(x: 326, y: 34), double: true,
                            rgb: (0.68, 0.19, 0.16), angle: -0.10, scale: 0.92)

        // Bottom bezel embroidered music patches (below LCD; bridge stays clean).
        drawEmbroideredHeadphones(in: ctx, center: CGPoint(x: 122, y: 834), angle: -0.05, scale: 0.74)
        drawEmbroideredNote(in: ctx, center: CGPoint(x: 156, y: 834), double: false,
                            rgb: (0.68, 0.19, 0.16), angle: 0.08, scale: 0.74)
        drawEmbroideredVinyl(in: ctx, center: CGPoint(x: 192, y: 834), radius: 11.8)
        drawEmbroideredNote(in: ctx, center: CGPoint(x: 226, y: 834), double: false,
                            rgb: (0.19, 0.35, 0.22), angle: -0.06, scale: 0.72)
        drawEmbroideredCassette(in: ctx, center: CGPoint(x: 270, y: 834), angle: -0.05, scale: 0.74)
        drawEmbroideredNote(in: ctx, center: CGPoint(x: 312, y: 834), double: false,
                            rgb: (0.80, 0.58, 0.18), angle: 0.10, scale: 0.72)
        drawEmbroideredBoombox(in: ctx, center: CGPoint(x: 348, y: 834), angle: -0.05, scale: 0.76)

        // Small embroidered accent notes tucked beside lower-left key margin.
        drawEmbroideredNote(in: ctx, center: CGPoint(x: 86, y: 700), double: false,
                            rgb: (0.68, 0.19, 0.16), angle: 0.12, scale: 0.62)
        drawEmbroideredNote(in: ctx, center: CGPoint(x: 86, y: 768), double: false,
                            rgb: (0.19, 0.35, 0.22), angle: -0.10, scale: 0.62)
    }

    private static func withPatchTransform(
        in ctx: CGContext,
        center: CGPoint,
        angle: CGFloat,
        scale: CGFloat,
        draw: () -> Void
    ) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: angle)
        ctx.scaleBy(x: scale, y: scale)
        ctx.setShadow(offset: CGSize(width: 0.8, height: 1.5), blur: 2.2,
                      color: CGColor(red: 0.20, green: 0.14, blue: 0.08, alpha: 0.42))
        draw()
        ctx.restoreGState()
    }

    private static func drawStitchTexture(in ctx: CGContext, rect: CGRect, alpha: CGFloat = 0.14) {
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: alpha)
        ctx.setLineWidth(0.55)
        for x in stride(from: rect.minX - 6, through: rect.maxX + 6, by: 2.2) {
            ctx.move(to: CGPoint(x: x, y: rect.minY))
            ctx.addLine(to: CGPoint(x: x + 3, y: rect.maxY))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawEmbroideredCassette(in ctx: CGContext, center: CGPoint, angle: CGFloat, scale: CGFloat) {
        withPatchTransform(in: ctx, center: center, angle: angle, scale: scale) {
            let body = CGRect(x: -20, y: -12.5, width: 40, height: 25)
            let p = CGPath(roundedRect: body, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
            ctx.setFillColor(red: 0.13, green: 0.22, blue: 0.33, alpha: 1.0)
            ctx.addPath(p)
            ctx.fillPath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            // Cream label & red accent stripe.
            ctx.setFillColor(red: 0.89, green: 0.83, blue: 0.72, alpha: 1.0)
            ctx.fill(CGRect(x: -16, y: -9, width: 32, height: 12))
            ctx.setFillColor(red: 0.72, green: 0.21, blue: 0.17, alpha: 1.0)
            ctx.fill(CGRect(x: -16, y: -4.2, width: 32, height: 3.4))

            // Tape window & spools.
            ctx.setFillColor(red: 0.12, green: 0.14, blue: 0.16, alpha: 1.0)
            ctx.fill(CGRect(x: -9.5, y: -5.8, width: 19, height: 6.2))
            ctx.setFillColor(red: 0.90, green: 0.86, blue: 0.78, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: -7.5, y: -4.8, width: 4.2, height: 4.2))
            ctx.fillEllipse(in: CGRect(x: 3.3, y: -4.8, width: 4.2, height: 4.2))

            drawStitchTexture(in: ctx, rect: body, alpha: 0.14)
        }
    }

    private static func drawEmbroideredHeadphones(in ctx: CGContext, center: CGPoint, angle: CGFloat, scale: CGFloat) {
        withPatchTransform(in: ctx, center: center, angle: angle, scale: scale) {
            ctx.setStrokeColor(red: 0.13, green: 0.22, blue: 0.33, alpha: 1.0)
            ctx.setLineWidth(4.2)
            ctx.setLineCap(.round)
            ctx.addArc(center: CGPoint(x: 0, y: 1.5), radius: 13.5, startAngle: .pi * 1.08, endAngle: -.pi * 0.08, clockwise: false)
            ctx.strokePath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            // Mustard-gold stitched ear cushions.
            for sx in [CGFloat(-1), 1] {
                let cup = CGPath(roundedRect: CGRect(x: sx * 12.2 - 4.0, y: 0.5, width: 8.0, height: 12.5),
                                 cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
                ctx.setFillColor(red: 0.84, green: 0.62, blue: 0.18, alpha: 1.0)
                ctx.addPath(cup)
                ctx.fillPath()
                ctx.setStrokeColor(red: 0.13, green: 0.22, blue: 0.33, alpha: 0.9)
                ctx.setLineWidth(1.5)
                ctx.addPath(cup)
                ctx.strokePath()
            }
        }
    }

    private static func drawEmbroideredVinyl(in ctx: CGContext, center: CGPoint, radius: CGFloat) {
        withPatchTransform(in: ctx, center: center, angle: 0, scale: 1) {
            let outer = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
            ctx.setFillColor(red: 0.12, green: 0.20, blue: 0.30, alpha: 1.0)
            ctx.fillEllipse(in: outer)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            // Concentric embroidered groove rings.
            ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.12)
            ctx.setLineWidth(0.7)
            ctx.strokeEllipse(in: outer.insetBy(dx: 3.0, dy: 3.0))
            ctx.strokeEllipse(in: outer.insetBy(dx: 5.5, dy: 5.5))

            let labelR = radius * 0.36
            ctx.setFillColor(red: 0.88, green: 0.82, blue: 0.72, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: -labelR, y: -labelR, width: labelR * 2, height: labelR * 2))
            ctx.setFillColor(red: 0.72, green: 0.20, blue: 0.17, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: -2.0, y: -2.0, width: 4.0, height: 4.0))
        }
    }

    private static func drawEmbroideredBoombox(in ctx: CGContext, center: CGPoint, angle: CGFloat, scale: CGFloat) {
        withPatchTransform(in: ctx, center: center, angle: angle, scale: scale) {
            // Mustard handle.
            ctx.setStrokeColor(red: 0.84, green: 0.62, blue: 0.18, alpha: 1.0)
            ctx.setLineWidth(2.6)
            ctx.stroke(CGRect(x: -10, y: -15, width: 20, height: 7))

            // Forest-green stitched chassis.
            let box = CGRect(x: -19, y: -9, width: 38, height: 21)
            let p = CGPath(roundedRect: box, cornerWidth: 3.0, cornerHeight: 3.0, transform: nil)
            ctx.setFillColor(red: 0.18, green: 0.32, blue: 0.20, alpha: 1.0)
            ctx.addPath(p)
            ctx.fillPath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            // Twin cream speakers + crimson center cassette door.
            ctx.setFillColor(red: 0.88, green: 0.82, blue: 0.70, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: -15.5, y: -3.5, width: 10.5, height: 10.5))
            ctx.fillEllipse(in: CGRect(x: 5.0, y: -3.5, width: 10.5, height: 10.5))
            ctx.setFillColor(red: 0.72, green: 0.20, blue: 0.16, alpha: 1.0)
            ctx.fill(CGRect(x: -3.5, y: -1.5, width: 7.0, height: 7.0))
            drawStitchTexture(in: ctx, rect: box, alpha: 0.14)
        }
    }

    private static func drawEmbroideredNote(
        in ctx: CGContext,
        center: CGPoint,
        double: Bool,
        rgb: (CGFloat, CGFloat, CGFloat),
        angle: CGFloat,
        scale: CGFloat
    ) {
        withPatchTransform(in: ctx, center: center, angle: angle, scale: scale) {
            ctx.setFillColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1.0)
            ctx.setStrokeColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1.0)
            ctx.setLineWidth(2.8)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            if double {
                ctx.fillEllipse(in: CGRect(x: -10.5, y: 3.5, width: 7.5, height: 5.8))
                ctx.fillEllipse(in: CGRect(x: 2.5, y: 1.5, width: 7.5, height: 5.8))
                ctx.move(to: CGPoint(x: -4.2, y: 5.5))
                ctx.addLine(to: CGPoint(x: -4.2, y: -8.5))
                ctx.addLine(to: CGPoint(x: 8.8, y: -10.5))
                ctx.addLine(to: CGPoint(x: 8.8, y: 3.5))
                ctx.strokePath()
            } else {
                ctx.fillEllipse(in: CGRect(x: -5.5, y: 2.5, width: 7.8, height: 6.0))
                ctx.move(to: CGPoint(x: 1.2, y: 4.5))
                ctx.addLine(to: CGPoint(x: 1.2, y: -10.0))
                ctx.addQuadCurve(to: CGPoint(x: 8.2, y: -4.0), control: CGPoint(x: 7.5, y: -9.5))
                ctx.strokePath()
            }
        }
    }

    // MARK: - 2. Pebbled Charcoal Shell + Illustrated Retro Vinyl Sticker Collage

    static func stickerBombBaseTexture() -> MTLTexture? {
        OneTapeBodyMetalEngine.shared.cachedTexture(key: "body.stickerBomb.base.v1") { ctx, rect in
            drawPebbledCharcoalShell(in: ctx, rect: rect)
            drawIllustratedStickerCollage(in: ctx)
        }
    }

    private static func drawPebbledCharcoalShell(in ctx: CGContext, rect: CGRect) {
        ctx.setFillColor(red: 0.165, green: 0.170, blue: 0.180, alpha: 1.0)
        ctx.fill(rect)
        for i in 0..<420 {
            let x = hash(i * 17 + 5) * rect.width
            let y = hash(i * 17 + 9) * rect.height
            let light = i % 2 == 0
            ctx.setFillColor(red: light ? 1 : 0, green: light ? 1 : 0, blue: light ? 1 : 0, alpha: light ? 0.032 : 0.06)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: 2.2, height: 2.2))
        }
    }

    private static func drawIllustratedStickerCollage(in ctx: CGContext) {
        // Top bezel overlapping retro vinyl decals (matching DuoFrontStickerThumb).
        drawVinylSticker(in: ctx, center: CGPoint(x: 98, y: 31), radius: 22, angle: -0.14)
        drawLightningSticker(in: ctx, center: CGPoint(x: 138, y: 34), angle: 0.12, scale: 0.92)
        drawDaisySticker(in: ctx, center: CGPoint(x: 178, y: 33), petalRGB: (0.95, 0.50, 0.24),
                         angle: 0.18, scale: 0.92)
        drawNoteSticker(in: ctx, center: CGPoint(x: 226, y: 31), rgb: (0.58, 0.34, 0.88),
                        angle: -0.06, scale: 0.95)
        drawCassetteSticker(in: ctx, center: CGPoint(x: 282, y: 33),
                            bodyRGB: (0.90, 0.53, 0.34), angle: 0.12, scale: 0.96)
        drawDaisySticker(in: ctx, center: CGPoint(x: 325, y: 18), petalRGB: (0.94, 0.44, 0.72),
                         angle: -0.22, scale: 0.72)
        drawSmileySticker(in: ctx, center: CGPoint(x: 356, y: 36), radius: 22.5, angle: 0.08)

        // Narrow side margin edge-bleed decals (cleanly clipped by chassis rim).
        drawStarSticker(in: ctx, center: CGPoint(x: 383, y: 138), rgb: (0.28, 0.58, 0.88), angle: 0.20, scale: 0.82)
        drawButtonSticker(in: ctx, center: CGPoint(x: 382, y: 238), radius: 17, angle: -0.18)
        drawDaisySticker(in: ctx, center: CGPoint(x: 384, y: 342), petalRGB: (0.94, 0.44, 0.72), angle: 0.15, scale: 0.78)
        drawNoteSticker(in: ctx, center: CGPoint(x: 381, y: 454), rgb: (0.91, 0.87, 0.76), angle: -0.14, scale: 0.82)
        drawLightningSticker(in: ctx, center: CGPoint(x: 382, y: 556), angle: 0.14, scale: 0.78)
        drawRainbowSticker(in: ctx, center: CGPoint(x: 8, y: 196), radius: 20, angle: 0.35)
        drawDaisySticker(in: ctx, center: CGPoint(x: 7, y: 416), petalRGB: (0.94, 0.44, 0.72), angle: -0.12, scale: 0.75)

        // Key column collage peeking behind & around the 3 black transport buttons.
        drawDaisySticker(in: ctx, center: CGPoint(x: 82, y: 652), petalRGB: (0.92, 0.35, 0.28), angle: -0.15, scale: 0.88)
        drawLightningSticker(in: ctx, center: CGPoint(x: 18, y: 642), angle: -0.18, scale: 0.82)
        drawStarSticker(in: ctx, center: CGPoint(x: 84, y: 706), rgb: (0.28, 0.58, 0.88), angle: 0.18, scale: 0.76)
        drawButtonSticker(in: ctx, center: CGPoint(x: 14, y: 716), radius: 16, angle: 0.20)
        drawDaisySticker(in: ctx, center: CGPoint(x: 86, y: 766), petalRGB: (0.94, 0.44, 0.72), angle: 0.25, scale: 0.84)
        drawRainbowSticker(in: ctx, center: CGPoint(x: 14, y: 782), radius: 20, angle: -0.20)
        drawDaisySticker(in: ctx, center: CGPoint(x: 80, y: 826), petalRGB: (0.95, 0.50, 0.24), angle: 0.10, scale: 0.82)
        drawStarSticker(in: ctx, center: CGPoint(x: 24, y: 834), rgb: (0.94, 0.78, 0.22), angle: -0.22, scale: 0.78)

        // Bottom bezel retro sticker strip beneath LCD.
        drawRainbowSticker(in: ctx, center: CGPoint(x: 118, y: 842), radius: 22, angle: 0.0)
        drawDaisySticker(in: ctx, center: CGPoint(x: 158, y: 836), petalRGB: (0.92, 0.90, 0.85), angle: -0.18, scale: 0.88)
        drawCassetteSticker(in: ctx, center: CGPoint(x: 214, y: 836),
                            bodyRGB: (0.64, 0.46, 0.82), angle: -0.05, scale: 0.90)
        drawRainbowSticker(in: ctx, center: CGPoint(x: 268, y: 842), radius: 20, angle: 0.04)
        drawStarSticker(in: ctx, center: CGPoint(x: 310, y: 836), rgb: (0.94, 0.78, 0.22), angle: 0.12, scale: 0.82)
        drawDaisySticker(in: ctx, center: CGPoint(x: 356, y: 836), petalRGB: (0.94, 0.44, 0.72), angle: -0.14, scale: 0.86)
    }

    private static func withStickerTransform(
        in ctx: CGContext,
        center: CGPoint,
        angle: CGFloat,
        scale: CGFloat = 1,
        draw: () -> Void
    ) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: angle)
        ctx.scaleBy(x: scale, y: scale)
        ctx.setShadow(offset: CGSize(width: 1.0, height: 1.8), blur: 2.6,
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.55))
        draw()
        ctx.restoreGState()
    }

    private static func drawSmileySticker(in ctx: CGContext, center: CGPoint, radius: CGFloat, angle: CGFloat) {
        withStickerTransform(in: ctx, center: center, angle: angle) {
            let dieCut = CGRect(x: -radius - 2.2, y: -radius - 2.2, width: (radius + 2.2) * 2, height: (radius + 2.2) * 2)
            ctx.setFillColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1.0)
            ctx.fillEllipse(in: dieCut)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            let face = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
            ctx.setFillColor(red: 0.95, green: 0.82, blue: 0.18, alpha: 1.0)
            ctx.fillEllipse(in: face)
            ctx.setStrokeColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0)
            ctx.setLineWidth(1.6)
            ctx.strokeEllipse(in: face)

            // Classic retro tall oval eyes & cheerful grin.
            ctx.setFillColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: -radius * 0.36, y: -radius * 0.36, width: 4.0, height: 7.4))
            ctx.fillEllipse(in: CGRect(x: radius * 0.18, y: -radius * 0.36, width: 4.0, height: 7.4))

            ctx.setLineWidth(2.2)
            ctx.setLineCap(.round)
            ctx.addArc(center: CGPoint(x: 0, y: -radius * 0.05), radius: radius * 0.56,
                       startAngle: .pi * 0.16, endAngle: .pi * 0.84, clockwise: false)
            ctx.strokePath()

            // Glossy vinyl glare arc.
            ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.42)
            ctx.setLineWidth(2.0)
            ctx.addArc(center: .zero, radius: radius * 0.78, startAngle: .pi * 1.15, endAngle: .pi * 1.52, clockwise: false)
            ctx.strokePath()
        }
    }

    private static func drawVinylSticker(in ctx: CGContext, center: CGPoint, radius: CGFloat, angle: CGFloat) {
        withStickerTransform(in: ctx, center: center, angle: angle) {
            let die = CGRect(x: -radius - 2, y: -radius - 2, width: (radius + 2) * 2, height: (radius + 2) * 2)
            ctx.setFillColor(red: 0.93, green: 0.92, blue: 0.90, alpha: 1.0)
            ctx.fillEllipse(in: die)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            let disc = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
            ctx.setFillColor(red: 0.13, green: 0.135, blue: 0.145, alpha: 1.0)
            ctx.fillEllipse(in: disc)
            ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.14)
            ctx.setLineWidth(0.8)
            ctx.strokeEllipse(in: disc.insetBy(dx: 4, dy: 4))
            ctx.strokeEllipse(in: disc.insetBy(dx: 8, dy: 8))

            let label = CGRect(x: -radius * 0.38, y: -radius * 0.38, width: radius * 0.76, height: radius * 0.76)
            ctx.setFillColor(red: 0.82, green: 0.30, blue: 0.25, alpha: 1.0)
            ctx.fillEllipse(in: label)
            ctx.setFillColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: -2.2, y: -2.2, width: 4.4, height: 4.4))
        }
    }

    private static func drawDaisySticker(
        in ctx: CGContext,
        center: CGPoint,
        petalRGB: (CGFloat, CGFloat, CGFloat),
        angle: CGFloat,
        scale: CGFloat
    ) {
        withStickerTransform(in: ctx, center: center, angle: angle, scale: scale) {
            // Die-cut white border petals.
            ctx.setFillColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1.0)
            for i in 0..<5 {
                let a = CGFloat(i) * .pi * 2 / 5
                ctx.fillEllipse(in: CGRect(x: cos(a) * 10.5 - 8.5, y: sin(a) * 10.5 - 8.5, width: 17, height: 17))
            }
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            // Vibrant colored petals with ink stroke.
            for i in 0..<5 {
                let a = CGFloat(i) * .pi * 2 / 5
                let petal = CGRect(x: cos(a) * 10.5 - 6.8, y: sin(a) * 10.5 - 6.8, width: 13.6, height: 13.6)
                ctx.setFillColor(red: petalRGB.0, green: petalRGB.1, blue: petalRGB.2, alpha: 1.0)
                ctx.fillEllipse(in: petal)
                ctx.setStrokeColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 0.9)
                ctx.setLineWidth(1.2)
                ctx.strokeEllipse(in: petal)
            }
            // Cheerful yellow center.
            let mid = CGRect(x: -6.2, y: -6.2, width: 12.4, height: 12.4)
            ctx.setFillColor(red: 0.96, green: 0.84, blue: 0.24, alpha: 1.0)
            ctx.fillEllipse(in: mid)
            ctx.setStrokeColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 0.9)
            ctx.setLineWidth(1.2)
            ctx.strokeEllipse(in: mid)
        }
    }

    private static func drawLightningSticker(in ctx: CGContext, center: CGPoint, angle: CGFloat, scale: CGFloat) {
        withStickerTransform(in: ctx, center: center, angle: angle, scale: scale) {
            let pts: [CGPoint] = [
                CGPoint(x: 4, y: -20), CGPoint(x: -11, y: 1), CGPoint(x: -1, y: 1),
                CGPoint(x: -7, y: 20), CGPoint(x: 12, y: -3), CGPoint(x: 1, y: -3)
            ]
            let bolt = CGMutablePath()
            bolt.addLines(between: pts)
            bolt.closeSubpath()

            ctx.setStrokeColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 1.0)
            ctx.setLineWidth(4.5)
            ctx.setLineJoin(.round)
            ctx.addPath(bolt)
            ctx.strokePath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            ctx.setFillColor(red: 0.96, green: 0.85, blue: 0.22, alpha: 1.0)
            ctx.addPath(bolt)
            ctx.fillPath()
            ctx.setStrokeColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 0.95)
            ctx.setLineWidth(1.3)
            ctx.addPath(bolt)
            ctx.strokePath()
        }
    }

    private static func drawCassetteSticker(
        in ctx: CGContext,
        center: CGPoint,
        bodyRGB: (CGFloat, CGFloat, CGFloat),
        angle: CGFloat,
        scale: CGFloat
    ) {
        withStickerTransform(in: ctx, center: center, angle: angle, scale: scale) {
            let die = CGPath(roundedRect: CGRect(x: -24, y: -15.5, width: 48, height: 31),
                             cornerWidth: 5, cornerHeight: 5, transform: nil)
            ctx.setFillColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1.0)
            ctx.addPath(die)
            ctx.fillPath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            let shell = CGPath(roundedRect: CGRect(x: -21.5, y: -13, width: 43, height: 26),
                               cornerWidth: 3.2, cornerHeight: 3.2, transform: nil)
            ctx.setFillColor(red: bodyRGB.0, green: bodyRGB.1, blue: bodyRGB.2, alpha: 1.0)
            ctx.addPath(shell)
            ctx.fillPath()
            ctx.setStrokeColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 0.9)
            ctx.setLineWidth(1.2)
            ctx.addPath(shell)
            ctx.strokePath()

            ctx.setFillColor(red: 0.93, green: 0.89, blue: 0.80, alpha: 1.0)
            ctx.fill(CGRect(x: -17.5, y: -9.5, width: 35, height: 13))
            ctx.setFillColor(red: 0.22, green: 0.24, blue: 0.26, alpha: 1.0)
            ctx.fill(CGRect(x: -11, y: -6, width: 22, height: 7.5))
            ctx.setFillColor(red: 0.94, green: 0.92, blue: 0.88, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: -9, y: -4.8, width: 5, height: 5))
            ctx.fillEllipse(in: CGRect(x: 4, y: -4.8, width: 5, height: 5))
        }
    }

    private static func drawButtonSticker(in ctx: CGContext, center: CGPoint, radius: CGFloat, angle: CGFloat) {
        withStickerTransform(in: ctx, center: center, angle: angle) {
            let die = CGRect(x: -radius - 2.2, y: -radius - 2.2, width: (radius + 2.2) * 2, height: (radius + 2.2) * 2)
            ctx.setFillColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1.0)
            ctx.fillEllipse(in: die)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            let body = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
            ctx.setFillColor(red: 0.20, green: 0.64, blue: 0.62, alpha: 1.0)
            ctx.fillEllipse(in: body)
            ctx.setStrokeColor(red: 0.10, green: 0.34, blue: 0.34, alpha: 0.85)
            ctx.setLineWidth(1.6)
            ctx.strokeEllipse(in: body.insetBy(dx: 3.2, dy: 3.2))

            // Cross-stitched thread in center of retro teal button.
            ctx.setStrokeColor(red: 0.93, green: 0.91, blue: 0.85, alpha: 0.95)
            ctx.setLineWidth(2.0)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: -4.5, y: -4.5))
            ctx.addLine(to: CGPoint(x: 4.5, y: 4.5))
            ctx.move(to: CGPoint(x: 4.5, y: -4.5))
            ctx.addLine(to: CGPoint(x: -4.5, y: 4.5))
            ctx.strokePath()
        }
    }

    private static func drawStarSticker(
        in ctx: CGContext,
        center: CGPoint,
        rgb: (CGFloat, CGFloat, CGFloat),
        angle: CGFloat,
        scale: CGFloat
    ) {
        withStickerTransform(in: ctx, center: center, angle: angle, scale: scale) {
            let star = CGMutablePath()
            for i in 0..<10 {
                let a = CGFloat(i) * .pi / 5 - .pi / 2
                let r: CGFloat = i % 2 == 0 ? 17.0 : 7.5
                let pt = CGPoint(x: cos(a) * r, y: sin(a) * r)
                if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath()

            ctx.setStrokeColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1.0)
            ctx.setLineWidth(4.5)
            ctx.setLineJoin(.round)
            ctx.addPath(star)
            ctx.strokePath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            ctx.setFillColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1.0)
            ctx.addPath(star)
            ctx.fillPath()
            ctx.setStrokeColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 0.9)
            ctx.setLineWidth(1.2)
            ctx.addPath(star)
            ctx.strokePath()
        }
    }

    private static func drawRainbowSticker(in ctx: CGContext, center: CGPoint, radius: CGFloat, angle: CGFloat) {
        withStickerTransform(in: ctx, center: center, angle: angle) {
            ctx.setLineCap(.butt)
            ctx.setStrokeColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1.0)
            ctx.setLineWidth(14.5)
            ctx.addArc(center: .zero, radius: radius - 5, startAngle: .pi, endAngle: 0, clockwise: false)
            ctx.strokePath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            let bands: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.90, 0.28, 0.24, radius),
                (0.96, 0.62, 0.20, radius - 3.2),
                (0.95, 0.84, 0.24, radius - 6.4),
                (0.28, 0.72, 0.56, radius - 9.6)
            ]
            for b in bands {
                ctx.setStrokeColor(red: b.0, green: b.1, blue: b.2, alpha: 1.0)
                ctx.setLineWidth(3.3)
                ctx.addArc(center: .zero, radius: b.3, startAngle: .pi, endAngle: 0, clockwise: false)
                ctx.strokePath()
            }
        }
    }

    private static func drawNoteSticker(
        in ctx: CGContext,
        center: CGPoint,
        rgb: (CGFloat, CGFloat, CGFloat),
        angle: CGFloat,
        scale: CGFloat
    ) {
        withStickerTransform(in: ctx, center: center, angle: angle, scale: scale) {
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            // White die-cut backing silhouette.
            ctx.setStrokeColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1.0)
            ctx.setLineWidth(9.0)
            ctx.move(to: CGPoint(x: -8, y: 9))
            ctx.addLine(to: CGPoint(x: -8, y: -11))
            ctx.addLine(to: CGPoint(x: 11, y: -14))
            ctx.addLine(to: CGPoint(x: 11, y: 6))
            ctx.strokePath()
            ctx.setFillColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: -17, y: 2.5, width: 15, height: 12.5))
            ctx.fillEllipse(in: CGRect(x: 2, y: -0.5, width: 15, height: 12.5))
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            // Colored retro double-note body.
            ctx.setStrokeColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1.0)
            ctx.setLineWidth(4.2)
            ctx.move(to: CGPoint(x: -8, y: 9))
            ctx.addLine(to: CGPoint(x: -8, y: -11))
            ctx.addLine(to: CGPoint(x: 11, y: -14))
            ctx.addLine(to: CGPoint(x: 11, y: 6))
            ctx.strokePath()
            ctx.setFillColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: -14.5, y: 4.5, width: 10.5, height: 8.5))
            ctx.fillEllipse(in: CGRect(x: 4.5, y: 1.5, width: 10.5, height: 8.5))
        }
    }

    private static func hash(_ seed: Int) -> CGFloat {
        var bits = UInt64(truncatingIfNeeded: seed) &+ 0x9E3779B97F4A7C15
        bits = (bits ^ (bits >> 30)) &* 0xBF58476D1CE4E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D049BB133111EB
        return CGFloat((bits ^ (bits >> 31)) & 65535) / 65535
    }
}
