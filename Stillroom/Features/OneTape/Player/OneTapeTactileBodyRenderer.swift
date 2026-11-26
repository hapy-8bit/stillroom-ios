import SwiftUI

/// Renders tactile and graphic Cassette 1.0.5 body finishes in 393×852 logical
/// design points: Woven Linen, Digital Camo, Stealth Camo, Sticker Bomb,
/// Grey Tracks, and Clean Plates.
enum OneTapeTactileBodyRenderer {
    static func draw(
        material: OneTapeBodyMaterial,
        in context: inout GraphicsContext,
        palette: OneTapeBodyMaterialPalette,
        rect: CGRect
    ) {
        switch material {
        case .linen:
            drawLinen(in: &context, palette: palette, rect: rect)
        case .camoDigital:
            drawCamo(in: &context, palette: palette, rect: rect, stealth: false)
        case .camoStealth:
            drawCamo(in: &context, palette: palette, rect: rect, stealth: true)
        case .stickerBomb:
            drawStickerBomb(in: &context, palette: palette, rect: rect)
        case .greyTracks:
            drawGreyTracks(in: &context, palette: palette, rect: rect)
        case .cleanPlates:
            drawCleanPlates(in: &context, palette: palette, rect: rect)
        default:
            break
        }
    }

    // MARK: - Woven Linen (亚麻织布)

    private static func drawLinen(
        in context: inout GraphicsContext,
        palette: OneTapeBodyMaterialPalette,
        rect: CGRect
    ) {
        let base = palette.shell
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    base.mixed(with: .init(1, 0.98, 0.94), fraction: 0.14).materialColor,
                    base.materialColor,
                    base.mixed(with: .init(0.28, 0.23, 0.17), fraction: 0.24).materialColor
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: rect.width, y: rect.height)
            )
        )

        // Fine alternating warp (vertical) and weft (horizontal) flax threads.
        let warpCount = 155
        for i in 0..<warpCount {
            let x = CGFloat(i) * rect.width / CGFloat(warpCount)
            let n = noise(i * 11 + 5)
            let light = n > 0.52
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: rect.height))
            context.stroke(
                line,
                with: .color((light ? Color.white : Color(red: 0.34, green: 0.28, blue: 0.20))
                    .opacity(0.05 + n * 0.085)),
                lineWidth: n > 0.85 ? 1.1 : 0.55
            )
        }

        let weftCount = 310
        for j in 0..<weftCount {
            let y = CGFloat(j) * rect.height / CGFloat(weftCount)
            let n = noise(j * 17 + 101)
            let light = n > 0.48
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: rect.width, y: y))
            context.stroke(
                line,
                with: .color((light ? Color(red: 0.98, green: 0.96, blue: 0.90) : Color(red: 0.30, green: 0.24, blue: 0.17))
                    .opacity(0.045 + n * 0.09)),
                lineWidth: n > 0.88 ? 1.2 : 0.55
            )
        }

        // Subtle perimeter tailored stitch line around the shell silhouette.
        let stitchRect = rect.insetBy(dx: 7.5, dy: 7.5)
        context.stroke(
            Path(roundedRect: stitchRect, cornerRadius: 51.5),
            with: .color(Color(red: 0.34, green: 0.28, blue: 0.21).opacity(0.28)),
            style: StrokeStyle(lineWidth: 0.9, dash: [4, 3])
        )
    }

    // MARK: - Digital & Stealth Camo (数码迷彩 / 暗夜迷彩)

    private static func drawCamo(
        in context: inout GraphicsContext,
        palette: OneTapeBodyMaterialPalette,
        rect: CGRect,
        stealth: Bool
    ) {
        let base = palette.shell
        let swatches: [OneTapeTransportMaterial.RGB] = stealth
            ? [
                base.mixed(with: .init(0.07, 0.075, 0.08), fraction: 0.65),
                base.mixed(with: .init(0.14, 0.15, 0.16), fraction: 0.55),
                base.mixed(with: .init(0.22, 0.23, 0.25), fraction: 0.55),
                base.mixed(with: .init(0.30, 0.32, 0.34), fraction: 0.50)
            ]
            : [
                base.mixed(with: .init(0.20, 0.24, 0.18), fraction: 0.65),
                base.mixed(with: .init(0.36, 0.42, 0.31), fraction: 0.65),
                base.mixed(with: .init(0.56, 0.54, 0.43), fraction: 0.60),
                base.mixed(with: .init(0.14, 0.15, 0.13), fraction: 0.65)
            ]

        context.fill(Path(rect), with: .color(swatches[0].materialColor))

        // Multi-scale crisp pixelated blocks give authentic digital camo clustering.
        let coarse: CGFloat = 22
        let cols = Int(ceil(rect.width / coarse))
        let rows = Int(ceil(rect.height / coarse))
        for r in 0..<rows {
            for c in 0..<cols {
                let cluster = noise((r / 2) * 37 + (c / 2) * 19 + (stealth ? 9 : 3))
                let local = noise(r * 53 + c * 29 + 17)
                let idx = min(swatches.count - 1, Int((cluster * 0.65 + local * 0.35) * Double(swatches.count)))
                let cell = CGRect(x: CGFloat(c) * coarse, y: CGFloat(r) * coarse, width: coarse + 0.5, height: coarse + 0.5)
                context.fill(Path(cell), with: .color(swatches[idx].materialColor))
            }
        }

        // Fine pixel micro-patches breaking straight block edges.
        let fine: CGFloat = 9.5
        for i in 0..<320 {
            let fx = floor(noise(i * 13 + 1) * Double(rect.width / fine)) * fine
            let fy = floor(noise(i * 13 + 2) * Double(rect.height / fine)) * fine
            let w = (noise(i * 13 + 3) > 0.5 ? 2.0 : 1.0) * fine
            let h = (noise(i * 13 + 4) > 0.6 ? 2.0 : 1.0) * fine
            let idx = Int(noise(i * 13 + 5) * Double(swatches.count)) % swatches.count
            context.fill(Path(CGRect(x: fx, y: fy, width: w, height: h)),
                         with: .color(swatches[idx].materialColor))
        }

        // Subtle matte directional lighting so the polymer reads three-dimensional.
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(stealth ? 0.08 : 0.10), .clear, .black.opacity(0.24)]),
                startPoint: .zero,
                endPoint: CGPoint(x: rect.width, y: rect.height)
            )
        )
    }

    // MARK: - Sticker Bomb (贴纸拼贴)

    private struct DecalSpec {
        let label: String
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let degrees: Double
        let bg: Color
        let fg: Color
        let capsule: Bool
    }

    private static func drawStickerBomb(
        in context: inout GraphicsContext,
        palette: OneTapeBodyMaterialPalette,
        rect: CGRect
    ) {
        context.fill(Path(rect), with: .color(palette.shell.materialColor))

        // Curated vintage audio/cassette decals placed specifically in the
        // visible frame around the cassette pocket, keys and LCD readout.
        let decals: [DecalSpec] = [
            // Top frame strip
            .init(label: "HI-FI", x: 118, y: 26, width: 64, height: 24, degrees: -8,
                  bg: Color(red: 0.94, green: 0.30, blue: 0.20), fg: .white, capsule: false),
            .init(label: "STEREO", x: 184, y: 40, width: 78, height: 22, degrees: 5,
                  bg: Color(red: 0.98, green: 0.78, blue: 0.18), fg: .black, capsule: true),
            .init(label: "C-90", x: 256, y: 24, width: 58, height: 24, degrees: -4,
                  bg: Color(red: 0.16, green: 0.56, blue: 0.96), fg: .white, capsule: false),
            .init(label: "120µs", x: 318, y: 42, width: 66, height: 22, degrees: 11,
                  bg: Color(red: 0.14, green: 0.72, blue: 0.48), fg: .black, capsule: true),
            .init(label: "SIDE A", x: 364, y: 20, width: 62, height: 20, degrees: -14,
                  bg: Color(red: 0.96, green: 0.94, blue: 0.88), fg: .black, capsule: false),

            // Left & right narrow side margins peeking out around cassette
            .init(label: "REC ●", x: 12, y: 170, width: 56, height: 20, degrees: -86,
                  bg: Color(red: 0.90, green: 0.18, blue: 0.24), fg: .white, capsule: true),
            .init(label: "ANALOG", x: 382, y: 215, width: 68, height: 20, degrees: 88,
                  bg: Color(red: 0.98, green: 0.80, blue: 0.22), fg: .black, capsule: false),
            .init(label: "TAPE", x: 11, y: 425, width: 54, height: 20, degrees: 92,
                  bg: Color(red: 0.58, green: 0.36, blue: 0.94), fg: .white, capsule: false),
            .init(label: "LO-FI", x: 383, y: 478, width: 58, height: 20, degrees: -87,
                  bg: Color(red: 0.18, green: 0.78, blue: 0.72), fg: .black, capsule: true),

            // Lower deck bridge & bottom corners around LCD + transport buttons
            .init(label: "PLAY ▶", x: 58, y: 634, width: 70, height: 22, degrees: -6,
                  bg: Color(red: 0.98, green: 0.48, blue: 0.14), fg: .black, capsule: true),
            .init(label: "ONE TAPE", x: 152, y: 636, width: 86, height: 21, degrees: 3,
                  bg: Color(red: 0.96, green: 0.95, blue: 0.90), fg: .black, capsule: false),
            .init(label: "DOLBY", x: 244, y: 635, width: 68, height: 21, degrees: -5,
                  bg: Color(red: 0.18, green: 0.44, blue: 0.92), fg: .white, capsule: false),
            .init(label: "CHROME", x: 332, y: 636, width: 74, height: 21, degrees: 7,
                  bg: Color(red: 0.95, green: 0.34, blue: 0.56), fg: .white, capsule: true),

            // Between keys and LCD + bottom margin
            .init(label: "CLUB", x: 86, y: 702, width: 52, height: 20, degrees: 84,
                  bg: Color(red: 0.98, green: 0.82, blue: 0.20), fg: .black, capsule: false),
            .init(label: "MIX", x: 16, y: 768, width: 46, height: 22, degrees: -18,
                  bg: Color(red: 0.22, green: 0.78, blue: 0.46), fg: .black, capsule: true),
            .init(label: "★ STEREO ★", x: 146, y: 834, width: 92, height: 22, degrees: -3,
                  bg: Color(red: 0.94, green: 0.28, blue: 0.22), fg: .white, capsule: true),
            .init(label: "TYPE II", x: 246, y: 833, width: 72, height: 21, degrees: 5,
                  bg: Color(red: 0.96, green: 0.94, blue: 0.88), fg: .black, capsule: false),
            .init(label: "45 RPM", x: 334, y: 830, width: 68, height: 22, degrees: -9,
                  bg: Color(red: 0.26, green: 0.58, blue: 0.96), fg: .white, capsule: true),
            .init(label: "BPM", x: 378, y: 740, width: 48, height: 20, degrees: 86,
                  bg: Color(red: 0.98, green: 0.54, blue: 0.18), fg: .black, capsule: false)
        ]

        for decal in decals {
            var local = context
            local.translateBy(x: decal.x, y: decal.y)
            local.rotate(by: .degrees(decal.degrees))
            let box = CGRect(x: -decal.width / 2, y: -decal.height / 2, width: decal.width, height: decal.height)
            let radius = decal.capsule ? decal.height / 2 : 4.0
            let borderPath = Path(roundedRect: box.insetBy(dx: -2.2, dy: -2.2), cornerRadius: radius + 2.0)
            let fillPath = Path(roundedRect: box, cornerRadius: radius)

            // Crisp white die-cut sticker border + subtle shadow.
            local.fill(borderPath.offsetBy(dx: 0.8, dy: 1.4), with: .color(.black.opacity(0.38)))
            local.fill(borderPath, with: .color(Color(white: 0.96)))
            local.fill(fillPath, with: .color(decal.bg))
            let text = Text(decal.label)
                .font(.system(size: 8.8, weight: .black, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(decal.fg)
            local.draw(local.resolve(text), at: .zero, anchor: .center)
        }

        // Subtle satin laminate sheen over the collage.
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.10), .clear, .black.opacity(0.16)]),
                startPoint: .zero,
                endPoint: CGPoint(x: rect.width, y: rect.height)
            )
        )
    }

    // MARK: - Grey Tracks (灰轨纹理)

    private static func drawGreyTracks(
        in context: inout GraphicsContext,
        palette: OneTapeBodyMaterialPalette,
        rect: CGRect
    ) {
        let base = palette.shell
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    base.mixed(with: .init(1, 1, 1), fraction: 0.16).materialColor,
                    base.materialColor,
                    base.mixed(with: .init(0, 0, 0), fraction: 0.22).materialColor
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: rect.width, y: rect.height)
            )
        )

        // Machined parallel horizontal magnetic-track grooves with shadow/highlight ribs.
        let pitch: CGFloat = 8.0
        for y in stride(from: CGFloat(6), to: rect.height, by: pitch) {
            var groove = Path()
            groove.move(to: CGPoint(x: 0, y: y))
            groove.addLine(to: CGPoint(x: rect.width, y: y))
            context.stroke(groove, with: .color(.black.opacity(0.24)), lineWidth: 1.4)

            var ridge = Path()
            ridge.move(to: CGPoint(x: 0, y: y + 1.3))
            ridge.addLine(to: CGPoint(x: rect.width, y: y + 1.3))
            context.stroke(ridge, with: .color(.white.opacity(0.18)), lineWidth: 0.75)
        }

        // Subtle vertical milled guide rails.
        for x in [92.0, 301.0] {
            var rail = Path()
            rail.move(to: CGPoint(x: x, y: 0))
            rail.addLine(to: CGPoint(x: x, y: rect.height))
            context.stroke(rail, with: .color(.black.opacity(0.18)), lineWidth: 1.0)
            context.stroke(rail.offsetBy(dx: 1, dy: 0), with: .color(.white.opacity(0.16)), lineWidth: 0.6)
        }
    }

    // MARK: - Clean Plates (极简面板)

    private static func drawCleanPlates(
        in context: inout GraphicsContext,
        palette: OneTapeBodyMaterialPalette,
        rect: CGRect
    ) {
        let base = palette.shell
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    base.mixed(with: .init(1, 1, 1), fraction: 0.12).materialColor,
                    base.materialColor,
                    base.mixed(with: .init(0, 0, 0), fraction: 0.08).materialColor
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: rect.width, y: rect.height)
            )
        )

        // Modular ceramic-matte sub-plates separated by razor-fine recessed seams.
        let lowerPlate = CGRect(x: 0, y: 632, width: rect.width, height: rect.height - 632)
        context.fill(
            Path(lowerPlate),
            with: .color(base.mixed(with: .init(0, 0, 0), fraction: 0.045).materialColor)
        )

        let seams: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 0, y: 632), CGPoint(x: rect.width, y: 632)),
            (CGPoint(x: 91, y: 632), CGPoint(x: 91, y: rect.height)),
            (CGPoint(x: 0, y: 60), CGPoint(x: rect.width, y: 60)),
            (CGPoint(x: 294, y: 0), CGPoint(x: 294, y: 60))
        ]
        for (a, b) in seams {
            var dark = Path()
            dark.move(to: a)
            dark.addLine(to: b)
            context.stroke(dark, with: .color(.black.opacity(0.24)), lineWidth: 1.1)

            let dx: CGFloat = a.x == b.x ? 1.0 : 0
            let dy: CGFloat = a.y == b.y ? 1.0 : 0
            context.stroke(dark.offsetBy(dx: dx, dy: dy), with: .color(.white.opacity(0.55)), lineWidth: 0.8)
        }

        // Matte mineral grain for tactile ceramic finish.
        for index in 0..<950 {
            let x = noise(index * 3) * Double(rect.width)
            let y = noise(index * 3 + 1) * Double(rect.height)
            let dot = CGRect(x: x, y: y, width: 0.45, height: 0.45)
            context.fill(Path(ellipseIn: dot), with: .color(.black.opacity(0.035)))
        }
    }

    private static func noise(_ index: Int) -> Double {
        var bits = UInt64(truncatingIfNeeded: index) &+ 0x9E3779B97F4A7C15
        bits = (bits ^ (bits >> 30)) &* 0xBF58476D1CE4E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D049BB133111EB
        return Double((bits ^ (bits >> 31)) & 65535) / 65535
    }
}
