import CoreGraphics
import Metal
import SwiftUI

/// Industrial & tactile GPU-lit body renderers built for the iPhone 393×852 chassis:
/// - `.greyTracks`: warm-bone matte chassis with sculpted asymmetric slate-grey milled conduit
/// - `.cleanPlates`: gunmetal anodized CNC modular plates, recessed key bay & micro indicators
/// - `.camoStealth`: carbon matte charcoal with raised clear-coat stealth camo islands
/// - `.camoDigital`: cool urban-slate multi-scale digital pixel camouflage
/// - `.linen`: coarse oatmeal woven flax burlap, perimeter stitching & embroidered patches
/// - `.stickerBomb`: dark pebbled shell covered in hand-illustrated die-cut retro vinyl decals.
@MainActor
enum OneTapeTactileBodyRenderer {
    @ViewBuilder
    static func view(
        for material: OneTapeBodyMaterial,
        tilt: CGSize
    ) -> some View {
        switch material {
        case .camoStealth:
            OneTapeMetalBodyView(program: .stealthCamo, tilt: tilt)
                .frame(width: 393, height: 852)
        case .camoDigital:
            OneTapeMetalBodyView(program: .digitalCamo, tilt: tilt)
                .frame(width: 393, height: 852)
        case .greyTracks:
            let baseTex = greyTracksBaseTexture()
            OneTapeMetalBodyView(program: .directionalRelief, tilt: tilt, grain: 0.018, texture0: baseTex)
                .frame(width: 393, height: 852)
        case .cleanPlates:
            let baseTex = OneTapeCleanPlatesBaker.baseTexture()
            OneTapeMetalBodyView(program: .directionalRelief, tilt: tilt, grain: 0.014, texture0: baseTex)
                .frame(width: 393, height: 852)
        case .linen:
            let baseTex = OneTapeCraftedTextureBakers.linenBaseTexture()
            OneTapeMetalBodyView(program: .directionalRelief, tilt: tilt, grain: 0.022, texture0: baseTex)
                .frame(width: 393, height: 852)
        case .stickerBomb:
            let baseTex = OneTapeCraftedTextureBakers.stickerBombBaseTexture()
            OneTapeMetalBodyView(program: .directionalRelief, tilt: tilt, grain: 0.014, texture0: baseTex)
                .frame(width: 393, height: 852)
        default:
            material.palette().shell.materialColor
                .frame(width: 393, height: 852)
        }
    }

    static func previewSnapshot(
        for material: OneTapeBodyMaterial,
        tilt: CGSize
    ) -> UIImage? {
        func makeUniforms(grain: Float = 0.018) -> OneTapeBodyUniforms {
            OneTapeBodyUniforms(
                designSize: SIMD2(393, 852),
                uvOffset: SIMD2(0, 608.0 / 852.0),
                uvScale: SIMD2(1, 244.0 / 852.0),
                tilt: SIMD2(Float(tilt.width), Float(tilt.height)),
                phase: 0,
                energy: 0,
                grain: grain
            )
        }
        let size = CGSize(width: 393 * 2, height: 244 * 2)
        switch material {
        case .camoStealth:
            return OneTapeBodyMetalEngine.shared.cachedSnapshot(
                key: "preview.camoStealth.v2", program: .stealthCamo, pixelSize: size, uniforms: makeUniforms()
            )
        case .camoDigital:
            return OneTapeBodyMetalEngine.shared.cachedSnapshot(
                key: "preview.camoDigital.v1", program: .digitalCamo, pixelSize: size, uniforms: makeUniforms()
            )
        case .greyTracks:
            return OneTapeBodyMetalEngine.shared.cachedSnapshot(
                key: "preview.greyTracks.v2",
                program: .directionalRelief,
                pixelSize: size,
                uniforms: makeUniforms(grain: 0.018),
                texture0: greyTracksBaseTexture()
            )
        case .cleanPlates:
            return OneTapeBodyMetalEngine.shared.cachedSnapshot(
                key: "preview.cleanPlates.v1",
                program: .directionalRelief,
                pixelSize: size,
                uniforms: makeUniforms(grain: 0.014),
                texture0: OneTapeCleanPlatesBaker.baseTexture()
            )
        case .linen:
            return OneTapeBodyMetalEngine.shared.cachedSnapshot(
                key: "preview.linen.v1",
                program: .directionalRelief,
                pixelSize: size,
                uniforms: makeUniforms(grain: 0.022),
                texture0: OneTapeCraftedTextureBakers.linenBaseTexture()
            )
        case .stickerBomb:
            return OneTapeBodyMetalEngine.shared.cachedSnapshot(
                key: "preview.stickerBomb.v1",
                program: .directionalRelief,
                pixelSize: size,
                uniforms: makeUniforms(grain: 0.014),
                texture0: OneTapeCraftedTextureBakers.stickerBombBaseTexture()
            )
        default:
            return nil
        }
    }

    // MARK: - Baked Grey Tracks Precision Chassis Texture (393×852 @2x)

    static func greyTracksBaseTexture() -> MTLTexture? {
        OneTapeBodyMetalEngine.shared.cachedTexture(key: "body.greyTracks.base.v2") { ctx, rect in
            drawWarmBoneChassis(in: ctx, rect: rect)
            drawMilledGreyTracks(in: ctx)
            drawColorMarkers(in: ctx)
            drawChassisScrews(in: ctx)
        }
    }

    private static func drawWarmBoneChassis(in ctx: CGContext, rect: CGRect) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let colors = [
            CGColor(colorSpace: cs, components: [0.895, 0.885, 0.850, 1])!,
            CGColor(colorSpace: cs, components: [0.858, 0.848, 0.812, 1])!,
            CGColor(colorSpace: cs, components: [0.822, 0.810, 0.775, 1])!
        ] as CFArray
        if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 0.5, 1]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 40, y: 0), end: CGPoint(x: 360, y: 852), options: [])
        }

        // Subtle recessed molding plate on top bezel only — leave the middle bridge
        // between cassette pocket and LCD completely clean and uncluttered.
        let topPanel = CGPath(roundedRect: CGRect(x: 84, y: 8, width: 226, height: 48), cornerWidth: 10, cornerHeight: 10, transform: nil)
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.14)
        ctx.addPath(topPanel)
        ctx.fillPath()
        ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.085)
        ctx.setLineWidth(0.75)
        ctx.addPath(topPanel)
        ctx.strokePath()
    }

    private static func drawMilledGreyTracks(in ctx: CGContext) {
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        // Single continuous sculptural slate-grey perimeter track (matching Cassette
        // 1.0.5's asymmetric outer conduit — never cutting across the middle bridge
        // or boxing in the LCD).
        let outerConduit = roundedPolyline([
            CGPoint(x: 108, y: 53),
            CGPoint(x: 356, y: 53),
            CGPoint(x: 382.5, y: 78),
            CGPoint(x: 382.5, y: 814),
            CGPoint(x: 362, y: 834),
            CGPoint(x: 106, y: 834)
        ], radius: 18)

        // 1. Lower-right bone catch highlight.
        ctx.saveGState()
        ctx.translateBy(x: 0.9, y: 1.0)
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.68)
        ctx.setLineWidth(11.4)
        ctx.addPath(outerConduit)
        ctx.strokePath()
        ctx.restoreGState()

        // 2. Recessed outer trench wall shadow.
        ctx.setStrokeColor(red: 0.24, green: 0.25, blue: 0.26, alpha: 0.56)
        ctx.setLineWidth(11.2)
        ctx.addPath(outerConduit)
        ctx.strokePath()

        // 3. Satin slate-grey recessed track body.
        ctx.setStrokeColor(red: 0.445, green: 0.460, blue: 0.478, alpha: 1.0)
        ctx.setLineWidth(9.2)
        ctx.addPath(outerConduit)
        ctx.strokePath()

        // 4. Inner shadow groove beside center guide wire.
        ctx.saveGState()
        ctx.translateBy(x: -0.45, y: -0.45)
        ctx.setStrokeColor(red: 0.18, green: 0.19, blue: 0.20, alpha: 0.56)
        ctx.setLineWidth(1.9)
        ctx.addPath(outerConduit)
        ctx.strokePath()
        ctx.restoreGState()

        // 5. Crisp pale-silver raised centerline guide wire.
        ctx.setStrokeColor(red: 0.84, green: 0.85, blue: 0.84, alpha: 0.84)
        ctx.setLineWidth(1.05)
        ctx.addPath(outerConduit)
        ctx.strokePath()
    }

    private static func drawColorMarkers(in ctx: CGContext) {
        // Restrained Teenage Engineering / Braun color-coded recessed micro-indicators.
        drawRecessedMarker(in: ctx, rect: CGRect(x: 82, y: 50.5, width: 15, height: 4.5),
                           radius: 2.2, rgb: (0.80, 0.24, 0.18))
        drawRecessedMarker(in: ctx, rect: CGRect(x: 10.5, y: 656, width: 6.5, height: 9.0),
                           radius: 1.8, rgb: (0.88, 0.65, 0.16))
        drawRecessedMarker(in: ctx, rect: CGRect(x: 34, y: 834, width: 14, height: 4.0),
                           radius: 2.0, rgb: (0.22, 0.36, 0.56))
    }

    private static func drawRecessedMarker(
        in ctx: CGContext,
        rect: CGRect,
        radius: CGFloat,
        rgb: (CGFloat, CGFloat, CGFloat)
    ) {
        let p = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.setFillColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1.0)
        ctx.addPath(p)
        ctx.fillPath()
        ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.28)
        ctx.setLineWidth(0.7)
        ctx.addPath(p)
        ctx.strokePath()
    }

    private static func drawChassisScrews(in ctx: CGContext) {
        let positions: [CGPoint] = [
            CGPoint(x: 96, y: 20), CGPoint(x: 300, y: 20),
            CGPoint(x: 378, y: 46), CGPoint(x: 11, y: 348),
            CGPoint(x: 14, y: 818), CGPoint(x: 372, y: 834)
        ]
        let cs = CGColorSpaceCreateDeviceRGB()
        let screwColors = [
            CGColor(colorSpace: cs, components: [0.88, 0.88, 0.87, 1])!,
            CGColor(colorSpace: cs, components: [0.54, 0.55, 0.56, 1])!,
            CGColor(colorSpace: cs, components: [0.74, 0.74, 0.73, 1])!
        ] as CFArray
        let screwGrad = CGGradient(colorsSpace: cs, colors: screwColors, locations: [0, 0.55, 1])

        for center in positions {
            let well = CGRect(x: center.x - 4.4, y: center.y - 4.4, width: 8.8, height: 8.8)
            ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 0.24)
            ctx.fillEllipse(in: well)

            let head = CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7.0, height: 7.0)
            ctx.saveGState()
            ctx.addEllipse(in: head)
            ctx.clip()
            if let screwGrad {
                ctx.drawLinearGradient(
                    screwGrad,
                    start: CGPoint(x: head.minX, y: head.minY),
                    end: CGPoint(x: head.maxX, y: head.maxY),
                    options: []
                )
            }
            ctx.restoreGState()

            ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.36)
            ctx.setLineWidth(0.55)
            ctx.strokeEllipse(in: head)

            ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.56)
            ctx.setLineWidth(0.75)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: center.x - 1.8, y: center.y))
            ctx.addLine(to: CGPoint(x: center.x + 1.8, y: center.y))
            ctx.move(to: CGPoint(x: center.x, y: center.y - 1.8))
            ctx.addLine(to: CGPoint(x: center.x, y: center.y + 1.8))
            ctx.strokePath()
        }
    }

    private static func roundedPolyline(_ points: [CGPoint], radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        guard points.count >= 2 else { return path }
        path.move(to: points[0])
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }
        for i in 1..<(points.count - 1) {
            let prev = points[i - 1]
            let corner = points[i]
            let next = points[i + 1]
            let v1 = CGVector(dx: prev.x - corner.x, dy: prev.y - corner.y)
            let v2 = CGVector(dx: next.x - corner.x, dy: next.y - corner.y)
            let len1 = hypot(v1.dx, v1.dy)
            let len2 = hypot(v2.dx, v2.dy)
            guard len1 > 0.1, len2 > 0.1 else {
                path.addLine(to: corner)
                continue
            }
            let r = min(radius, len1 * 0.45, len2 * 0.45)
            let p1 = CGPoint(x: corner.x + v1.dx / len1 * r, y: corner.y + v1.dy / len1 * r)
            let p2 = CGPoint(x: corner.x + v2.dx / len2 * r, y: corner.y + v2.dy / len2 * r)
            path.addLine(to: p1)
            path.addQuadCurve(to: p2, control: corner)
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}
