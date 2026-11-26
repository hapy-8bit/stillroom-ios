import CoreGraphics
import Metal
import SwiftUI

/// GPU Metal optical & dynamic body renderers built for the iPhone 393×852 chassis:
/// - `.holoFoil`: seamless diagonal micro-brushed pearlescent holographic foil
/// - `.silverFoil`: raw diagonal brushed aluminum foil with restrained edge iridescence
/// - `.disco`: high-density beveled silver micro-mirror mosaic with 60fps GPU glints
/// - `.circuitGlow`: ultra-dark satin FR-4 PCB + tone-on-tone SMD components + quiet
///   warm amber-gold outer-perimeter traces driven by GPU current pulses & audio energy
/// - `.seeThrough`: smoked translucent polycarbonate shell exposing baked internal
///   batteries, green PCB, switch linkages, motor & gears.
@MainActor
enum OneTapeFoilAndOpticBodyRenderer {
    @ViewBuilder
    static func view(
        for material: OneTapeBodyMaterial,
        tilt: CGSize,
        energy: Double,
        animatePulse: Bool
    ) -> some View {
        switch material {
        case .holoFoil:
            OneTapeMetalBodyView(program: .holoFoil, tilt: tilt)
                .frame(width: 393, height: 852)
        case .silverFoil:
            OneTapeMetalBodyView(program: .silverFoil, tilt: tilt)
                .frame(width: 393, height: 852)
        case .disco:
            OneTapeMetalBodyView(
                program: .disco,
                tilt: tilt,
                energy: energy,
                animatePulse: animatePulse
            )
            .frame(width: 393, height: 852)
        case .circuitGlow:
            let smd = circuitSMDTexture()
            let trace = circuitTraceTexture()
            OneTapeMetalBodyView(
                program: .circuitGlow,
                tilt: tilt,
                energy: energy,
                animatePulse: animatePulse,
                texture0: smd,
                texture1: trace
            )
            .frame(width: 393, height: 852)
        case .seeThrough:
            let internals = OneTapeSeeThroughBaker.internalsTexture()
            OneTapeMetalBodyView(
                program: .seeThrough,
                tilt: tilt,
                energy: energy,
                animatePulse: animatePulse,
                texture0: internals
            )
            .frame(width: 393, height: 852)
        default:
            material.palette().shell.materialColor
                .frame(width: 393, height: 852)
        }
    }

    static func previewSnapshot(
        for material: OneTapeBodyMaterial,
        tilt: CGSize,
        energy: Double,
        pulsePhase: Double
    ) -> UIImage? {
        let uniforms = OneTapeBodyUniforms(
            designSize: SIMD2(393, 852),
            uvOffset: SIMD2(0, 608.0 / 852.0),
            uvScale: SIMD2(1, 244.0 / 852.0),
            tilt: SIMD2(Float(tilt.width), Float(tilt.height)),
            phase: Float(pulsePhase),
            energy: Float(energy),
            grain: 0.018
        )
        let size = CGSize(width: 393 * 2, height: 244 * 2)
        switch material {
        case .holoFoil:
            return OneTapeBodyMetalEngine.shared.cachedSnapshot(
                key: "preview.holoFoil.v2", program: .holoFoil, pixelSize: size, uniforms: uniforms
            )
        case .silverFoil:
            return OneTapeBodyMetalEngine.shared.cachedSnapshot(
                key: "preview.silverFoil.v2", program: .silverFoil, pixelSize: size, uniforms: uniforms
            )
        case .disco:
            return OneTapeBodyMetalEngine.shared.cachedSnapshot(
                key: "preview.disco.v1", program: .disco, pixelSize: size, uniforms: uniforms
            )
        case .circuitGlow:
            return OneTapeBodyMetalEngine.shared.cachedSnapshot(
                key: "preview.circuitGlow.v2",
                program: .circuitGlow,
                pixelSize: size,
                uniforms: uniforms,
                texture0: circuitSMDTexture(),
                texture1: circuitTraceTexture()
            )
        case .seeThrough:
            return OneTapeBodyMetalEngine.shared.cachedSnapshot(
                key: "preview.seeThrough.v3",
                program: .seeThrough,
                pixelSize: size,
                uniforms: uniforms,
                texture0: OneTapeSeeThroughBaker.internalsTexture()
            )
        default:
            return nil
        }
    }

    // MARK: - Baked Circuit Glow GPU Textures (393×852 @2x, baked once per session)

    static func circuitSMDTexture() -> MTLTexture? {
        OneTapeBodyMetalEngine.shared.cachedTexture(key: "body.circuit.smd.v2") { ctx, _ in
            let chips: [CGRect] = [
                CGRect(x: 92, y: 12, width: 22, height: 14),
                CGRect(x: 124, y: 18, width: 32, height: 16),
                CGRect(x: 238, y: 14, width: 26, height: 16),
                CGRect(x: 274, y: 19, width: 20, height: 13),
                CGRect(x: 304, y: 12, width: 18, height: 18),
                CGRect(x: 330, y: 26, width: 28, height: 14),
                CGRect(x: 377, y: 132, width: 11, height: 22),
                CGRect(x: 378, y: 248, width: 10, height: 16),
                CGRect(x: 377, y: 394, width: 11, height: 26),
                CGRect(x: 378, y: 526, width: 10, height: 18),
                CGRect(x: 376, y: 696, width: 12, height: 24),
                CGRect(x: 377, y: 760, width: 10, height: 16),
                CGRect(x: 5, y: 170, width: 10, height: 22),
                CGRect(x: 6, y: 344, width: 9, height: 18),
                CGRect(x: 5, y: 492, width: 10, height: 24),
                CGRect(x: 124, y: 630, width: 22, height: 10),
                CGRect(x: 220, y: 631, width: 28, height: 9),
                CGRect(x: 302, y: 630, width: 16, height: 10),
                CGRect(x: 118, y: 826, width: 28, height: 13),
                CGRect(x: 194, y: 827, width: 20, height: 12),
                CGRect(x: 266, y: 825, width: 34, height: 14),
                CGRect(x: 318, y: 828, width: 18, height: 11)
            ]

            for chip in chips {
                let path = CGPath(roundedRect: chip, cornerWidth: 1.6, cornerHeight: 1.6, transform: nil)
                ctx.setFillColor(red: 0.032, green: 0.032, blue: 0.036, alpha: 0.96)
                ctx.addPath(path)
                ctx.fillPath()

                ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.075)
                ctx.setLineWidth(0.6)
                ctx.addPath(path)
                ctx.strokePath()

                if chip.width >= 16 && chip.height >= 12 {
                    let inner = CGPath(roundedRect: chip.insetBy(dx: 3, dy: 3), cornerWidth: 0.8, cornerHeight: 0.8, transform: nil)
                    ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.028)
                    ctx.setLineWidth(0.5)
                    ctx.addPath(inner)
                    ctx.strokePath()
                }
            }

            // Passive micro-SMDs & subtle dark copper micro-vias.
            for index in 0..<110 {
                let x = 6 + hash(index * 7 + 1) * 381
                let y = 10 + hash(index * 7 + 2) * 832
                if x > 18 && x < 375 && y > 66 && y < 624 { continue }
                if x > 96 && x < 369 && y > 647 && y < 821 { continue }
                if x > 16 && x < 80 && y > 635 && y < 834 { continue }
                if x > 22 && x < 74 && y > 8 && y < 60 { continue }

                if index % 3 == 0 {
                    let pad = CGRect(x: x - 1.15, y: y - 1.15, width: 2.3, height: 2.3)
                    ctx.setFillColor(red: 0.40, green: 0.26, blue: 0.12, alpha: 0.26)
                    ctx.fillEllipse(in: pad)
                    ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 0.78)
                    ctx.fillEllipse(in: pad.insetBy(dx: 0.55, dy: 0.55))
                } else {
                    let smd = CGRect(x: x - 2.2, y: y - 1.1, width: 4.4, height: 2.2)
                    let p = CGPath(roundedRect: smd, cornerWidth: 0.5, cornerHeight: 0.5, transform: nil)
                    ctx.setFillColor(red: 0.042, green: 0.043, blue: 0.048, alpha: 0.92)
                    ctx.addPath(p)
                    ctx.fillPath()
                    ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.05)
                    ctx.setLineWidth(0.4)
                    ctx.addPath(p)
                    ctx.strokePath()
                }
            }
        }
    }

    static func circuitTraceTexture() -> MTLTexture? {
        OneTapeBodyMetalEngine.shared.cachedTexture(key: "body.circuit.trace.v2") { ctx, _ in
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            // Outer-perimeter-only warm copper-amber signal runs framing the entire
            // player as one unified chassis (no bar cutting across the middle bridge
            // between cassette and LCD, matching Cassette 1.0.5's restrained circuit).
            let routes: [(CGPath, Bool)] = [
                // Primary outer bus: top bezel -> right outer edge -> bottom bezel under LCD
                (roundedPolyline([
                    CGPoint(x: 92, y: 55.5),
                    CGPoint(x: 383.5, y: 55.5),
                    CGPoint(x: 383.5, y: 834.5),
                    CGPoint(x: 112, y: 834.5)
                ], radius: 22), true),
                // Parallel inner companion hairline spaced cleanly 3pt inward
                (roundedPolyline([
                    CGPoint(x: 110, y: 58.6),
                    CGPoint(x: 380.4, y: 58.6),
                    CGPoint(x: 380.4, y: 831.4),
                    CGPoint(x: 132, y: 831.4)
                ], radius: 19), false),
                // Quiet outer left-margin run framing the cassette left edge (stops before bridge)
                (roundedPolyline([
                    CGPoint(x: 9.5, y: 82),
                    CGPoint(x: 9.5, y: 604)
                ], radius: 12), false),
                // Subtle lower-left corner accent trace framing the key column bottom
                (roundedPolyline([
                    CGPoint(x: 11.5, y: 742),
                    CGPoint(x: 11.5, y: 822),
                    CGPoint(x: 34, y: 836),
                    CGPoint(x: 84, y: 836)
                ], radius: 13), false)
            ]

            for (path, primary) in routes {
                // Soft warm amber halo.
                ctx.setStrokeColor(red: 0.88, green: 0.40, blue: 0.10, alpha: primary ? 0.22 : 0.14)
                ctx.setLineWidth(primary ? 4.6 : 3.0)
                ctx.addPath(path)
                ctx.strokePath()

                // Delicate amber-copper conductor body.
                ctx.setStrokeColor(red: 0.98, green: 0.56, blue: 0.18, alpha: primary ? 0.58 : 0.38)
                ctx.setLineWidth(primary ? 1.45 : 1.05)
                ctx.addPath(path)
                ctx.strokePath()

                // Razor-fine warm gold core hairline.
                ctx.setStrokeColor(red: 1.00, green: 0.78, blue: 0.46, alpha: primary ? 0.86 : 0.64)
                ctx.setLineWidth(primary ? 0.65 : 0.50)
                ctx.addPath(path)
                ctx.strokePath()
            }

            let vias: [CGPoint] = [
                CGPoint(x: 92, y: 55.5), CGPoint(x: 110, y: 58.6),
                CGPoint(x: 112, y: 834.5), CGPoint(x: 132, y: 831.4),
                CGPoint(x: 9.5, y: 82), CGPoint(x: 9.5, y: 604),
                CGPoint(x: 11.5, y: 742), CGPoint(x: 84, y: 836)
            ]
            for pt in vias {
                ctx.setFillColor(red: 0.90, green: 0.44, blue: 0.12, alpha: 0.38)
                ctx.fillEllipse(in: CGRect(x: pt.x - 2.2, y: pt.y - 2.2, width: 4.4, height: 4.4))
                ctx.setFillColor(red: 1.0, green: 0.80, blue: 0.50, alpha: 0.92)
                ctx.fillEllipse(in: CGRect(x: pt.x - 1.2, y: pt.y - 1.2, width: 2.4, height: 2.4))
            }
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

    private static func hash(_ seed: Int) -> CGFloat {
        var bits = UInt64(truncatingIfNeeded: seed) &+ 0x9E3779B97F4A7C15
        bits = (bits ^ (bits >> 30)) &* 0xBF58476D1CE4E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D049BB133111EB
        return CGFloat((bits ^ (bits >> 31)) & 65535) / 65535
    }
}
