import SwiftUI

/// Renders optical and dynamic Cassette 1.0.5 body finishes in 393×852 logical
/// design points: Holo Foil, Silver Foil, Disco Mirror, Circuit Glow, and
/// See-Through mechanical chassis.
enum OneTapeFoilAndOpticBodyRenderer {
    static func draw(
        material: OneTapeBodyMaterial,
        in context: inout GraphicsContext,
        palette: OneTapeBodyMaterialPalette,
        rect: CGRect,
        tilt: CGSize,
        energy: Double
    ) {
        switch material {
        case .holoFoil:
            drawHoloFoil(in: &context, palette: palette, rect: rect, tilt: tilt)
        case .silverFoil:
            drawSilverFoil(in: &context, palette: palette, rect: rect, tilt: tilt)
        case .disco:
            drawDisco(in: &context, palette: palette, rect: rect, tilt: tilt, energy: energy)
        case .circuitGlow:
            drawCircuitGlow(in: &context, palette: palette, rect: rect, tilt: tilt, energy: energy)
        case .seeThrough:
            drawSeeThrough(in: &context, palette: palette, rect: rect)
        default:
            break
        }
    }

    // MARK: - Holo Foil (全息箔)

    private static func drawHoloFoil(
        in context: inout GraphicsContext,
        palette: OneTapeBodyMaterialPalette,
        rect: CGRect,
        tilt: CGSize
    ) {
        let phase = Double(tilt.width) * 0.48 + Double(tilt.height) * 0.34
        let shiftX = CGFloat(tilt.width) * 140
        let shiftY = CGFloat(tilt.height) * 180

        let stops = (0..<11).map { idx -> Gradient.Stop in
            let t = Double(idx) / 10.0
            var hue = (t * 1.25 + phase).truncatingRemainder(dividingBy: 1.0)
            if hue < 0 { hue += 1.0 }
            let color = Color(hue: hue, saturation: 0.56, brightness: 0.93)
            return Gradient.Stop(color: color, location: t)
        }
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(stops: stops),
                startPoint: CGPoint(x: -70 + shiftX, y: -40 + shiftY),
                endPoint: CGPoint(x: rect.width + 70 + shiftX * 0.4, y: rect.height + 40 - shiftY * 0.5)
            )
        )

        // Secondary cross-diffraction sheen blended softly with shell tint.
        var cross = context
        cross.opacity = 0.45
        let crossStops = (0..<7).map { idx -> Gradient.Stop in
            let t = Double(idx) / 6.0
            var hue = (0.55 - t * 0.95 - phase * 1.15).truncatingRemainder(dividingBy: 1.0)
            if hue < 0 { hue += 1.0 }
            return Gradient.Stop(color: Color(hue: hue, saturation: 0.48, brightness: 0.98), location: t)
        }
        cross.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(stops: crossStops),
                startPoint: CGPoint(x: rect.width + 40 - shiftX * 0.6, y: 0),
                endPoint: CGPoint(x: -40 - shiftX * 0.3, y: rect.height)
            )
        )

        // Subtle metallic silver base + user tint unification.
        var tintLayer = context
        tintLayer.opacity = 0.24
        tintLayer.fill(Path(rect), with: .color(palette.shell.materialColor))

        drawBrushedLines(in: &context, rect: rect, count: 680, alpha: 0.055, vertical: false)
        drawSpecularBand(in: &context, rect: rect, tilt: tilt, intensity: 0.46)
    }

    // MARK: - Silver Foil (金属箔)

    private static func drawSilverFoil(
        in context: inout GraphicsContext,
        palette: OneTapeBodyMaterialPalette,
        rect: CGRect,
        tilt: CGSize
    ) {
        let base = palette.shell
        let shift = CGFloat(tilt.width) * 120 + CGFloat(tilt.height) * 60
        let bands: [(Double, Double)] = [
            (0.00, -0.34), (0.14, 0.38), (0.29, -0.22), (0.48, 0.50),
            (0.66, -0.26), (0.83, 0.36), (1.00, -0.18)
        ]
        let stops = bands.map { loc, delta in
            Gradient.Stop(
                color: base.mixed(with: delta > 0 ? .init(1, 1, 1) : .init(0, 0, 0), fraction: abs(delta)).materialColor,
                location: loc
            )
        }
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(stops: stops),
                startPoint: CGPoint(x: -80 + shift, y: -40),
                endPoint: CGPoint(x: rect.width + 80 + shift, y: rect.height * 0.72)
            )
        )
        drawBrushedLines(in: &context, rect: rect, count: 820, alpha: 0.065, vertical: false)
        drawSpecularBand(in: &context, rect: rect, tilt: tilt, intensity: 0.55)
    }

    // MARK: - Disco Mirror (迪斯科镜球)

    private static func drawDisco(
        in context: inout GraphicsContext,
        palette: OneTapeBodyMaterialPalette,
        rect: CGRect,
        tilt: CGSize,
        energy: Double
    ) {
        context.fill(Path(rect), with: .color(Color(red: 0.06, green: 0.065, blue: 0.08)))
        let tile: CGFloat = 15.5
        let gap: CGFloat = 1.2
        let cols = Int(ceil(rect.width / tile))
        let rows = Int(ceil(rect.height / tile))
        let lightX = Double(tilt.width) * 1.15
        let lightY = Double(tilt.height) * 1.15
        let pulse = min(1.0, max(0.0, energy))

        for row in 0..<rows {
            let y = CGFloat(row) * tile
            for col in 0..<cols {
                let x = CGFloat(col) * tile
                // Skip regions completely hidden behind cassette pocket & LCD
                // so the mosaic stays blazing fast at 60fps.
                if x > 24 && x < 368 && y > 74 && y < 616 { continue }
                if x > 104 && x < 360 && y > 655 && y < 812 { continue }

                let seed = row * 73 + col * 31
                let nx = (noise(seed) - 0.5) * 1.65
                let ny = (noise(seed + 7) - 0.5) * 1.65
                let warmth = noise(seed + 19)
                let align = max(0.0, 1.0 - hypot(nx - lightX, ny - lightY) * 0.72)
                let sparkle = pow(align, 3.2) * (0.78 + pulse * 0.45)
                let baseLum = 0.14 + align * 0.46 + sparkle * 0.42

                let tileRGB: OneTapeTransportMaterial.RGB
                if sparkle > 0.45 {
                    let accent: OneTapeTransportMaterial.RGB = warmth > 0.52
                        ? .init(1.00, 0.90, 0.72)
                        : .init(0.84, 0.92, 1.00)
                    tileRGB = palette.shell.mixed(with: accent, fraction: min(1.0, 0.55 + sparkle * 0.45))
                } else {
                    let tone = OneTapeTransportMaterial.RGB(baseLum, baseLum * 1.01, baseLum * 1.05)
                    tileRGB = tone.mixed(with: palette.shell, fraction: 0.28)
                }

                let cell = CGRect(x: x + gap * 0.5, y: y + gap * 0.5, width: tile - gap, height: tile - gap)
                let path = Path(roundedRect: cell, cornerRadius: 1.4)
                context.fill(path, with: .color(tileRGB.materialColor))

                if sparkle > 0.52 {
                    context.stroke(path, with: .color(Color.white.opacity(min(0.95, sparkle))), lineWidth: 0.75)
                } else {
                    context.stroke(path, with: .color(Color.white.opacity(0.10)), lineWidth: 0.35)
                }
            }
        }
    }

    // MARK: - Circuit Glow (荧光电路)

    private static func drawCircuitGlow(
        in context: inout GraphicsContext,
        palette: OneTapeBodyMaterialPalette,
        rect: CGRect,
        tilt: CGSize,
        energy: Double
    ) {
        let base = palette.shell
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    base.mixed(with: .init(0.03, 0.05, 0.05), fraction: 0.45).materialColor,
                    base.materialColor,
                    base.mixed(with: .init(0.01, 0.02, 0.02), fraction: 0.55).materialColor
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: rect.width, y: rect.height)
            )
        )

        let glowStrength = 0.55 + min(0.45, energy * 0.55) + Double(abs(tilt.width)) * 0.14
        let traceColor = Color(red: 0.24, green: 0.96, blue: 0.68)
        let copperColor = Color(red: 0.68, green: 0.60, blue: 0.36)

        // Subtle PCB grid dots in the visible lower/top margins.
        for gy in stride(from: CGFloat(16), to: rect.height - 12, by: 18) {
            for gx in stride(from: CGFloat(14), to: rect.width - 10, by: 18) {
                if gx > 22 && gx < 370 && gy > 72 && gy < 618 { continue }
                let dot = CGRect(x: gx - 0.6, y: gy - 0.6, width: 1.2, height: 1.2)
                context.fill(Path(ellipseIn: dot), with: .color(traceColor.opacity(0.09)))
            }
        }

        // Routed 45° top & lower-edge signal buses (visible around cassette & LCD).
        let routes: [[CGPoint]] = [
            // Top bezel buses
            [CGPoint(x: 42, y: 18), CGPoint(x: 138, y: 18), CGPoint(x: 156, y: 36), CGPoint(x: 348, y: 36)],
            [CGPoint(x: 68, y: 27), CGPoint(x: 184, y: 27), CGPoint(x: 202, y: 45), CGPoint(x: 324, y: 45)],
            [CGPoint(x: 112, y: 54), CGPoint(x: 256, y: 54), CGPoint(x: 274, y: 40), CGPoint(x: 360, y: 40)],
            // Left vertical bus beside cassette & transport keys
            [CGPoint(x: 10, y: 88), CGPoint(x: 10, y: 590), CGPoint(x: 19, y: 602), CGPoint(x: 19, y: 650)],
            [CGPoint(x: 383, y: 92), CGPoint(x: 383, y: 618), CGPoint(x: 374, y: 632), CGPoint(x: 374, y: 818)],
            // Lower bridge between cassette pocket and LCD/keys
            [CGPoint(x: 24, y: 633), CGPoint(x: 162, y: 633), CGPoint(x: 176, y: 642), CGPoint(x: 356, y: 642)],
            [CGPoint(x: 84, y: 644), CGPoint(x: 84, y: 742), CGPoint(x: 92, y: 750), CGPoint(x: 92, y: 828)],
            // Bottom edge signal traces
            [CGPoint(x: 36, y: 834), CGPoint(x: 148, y: 834), CGPoint(x: 160, y: 826), CGPoint(x: 344, y: 826)],
            [CGPoint(x: 74, y: 842), CGPoint(x: 288, y: 842), CGPoint(x: 300, y: 833), CGPoint(x: 362, y: 833)]
        ]

        for (index, points) in routes.enumerated() {
            var path = Path()
            guard let first = points.first else { continue }
            path.move(to: first)
            for pt in points.dropFirst() { path.addLine(to: pt) }

            let isGlowing = index % 2 == 0
            if isGlowing {
                context.stroke(path, with: .color(traceColor.opacity(0.22 * glowStrength)),
                               style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(traceColor.opacity(0.86 * glowStrength)),
                               style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round))
            } else {
                context.stroke(path, with: .color(copperColor.opacity(0.45)),
                               style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
            }

            // Gold via pads at trace endpoints.
            for end in [first, points.last!] {
                let pad = CGRect(x: end.x - 2.6, y: end.y - 2.6, width: 5.2, height: 5.2)
                context.fill(Path(ellipseIn: pad), with: .color(copperColor.opacity(0.85)))
                context.fill(Path(ellipseIn: pad.insetBy(dx: 1.3, dy: 1.3)), with: .color(.black.opacity(0.75)))
            }
        }

        // Top SMD IC packages.
        for x in [120.0, 212.0, 294.0] {
            let chip = CGRect(x: x, y: 20, width: 26, height: 14)
            context.fill(Path(roundedRect: chip, cornerRadius: 2), with: .color(Color(white: 0.05)))
            context.stroke(Path(roundedRect: chip, cornerRadius: 2), with: .color(traceColor.opacity(0.32)), lineWidth: 0.6)
            for pin in 0..<4 {
                let px = chip.minX + 4 + CGFloat(pin) * 5.8
                let leg = CGRect(x: px, y: chip.maxY, width: 2.2, height: 3.2)
                context.fill(Path(leg), with: .color(copperColor.opacity(0.82)))
            }
        }
    }

    // MARK: - See-Through Mechanical Chassis (透明机械)

    private static func drawSeeThrough(
        in context: inout GraphicsContext,
        palette: OneTapeBodyMaterialPalette,
        rect: CGRect
    ) {
        let base = palette.shell
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    base.mixed(with: .init(0.05, 0.06, 0.08), fraction: 0.55).materialColor,
                    base.mixed(with: .init(0.16, 0.19, 0.22), fraction: 0.35).materialColor,
                    base.mixed(with: .init(0.04, 0.05, 0.07), fraction: 0.65).materialColor
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: rect.width, y: rect.height)
            )
        )

        // Internal structural ribs & acrylic wall depth.
        let innerWall = Path(roundedRect: rect.insetBy(dx: 8, dy: 8), cornerRadius: 52)
        context.stroke(innerWall, with: .color(.black.opacity(0.65)), lineWidth: 4.5)
        context.stroke(innerWall, with: .color(.white.opacity(0.22)), lineWidth: 0.8)

        // Internal ribbon cable bus along top and bottom margins.
        for strip in 0..<5 {
            let y = CGFloat(24 + strip * 4)
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: 92, y: y))
            ribbon.addLine(to: CGPoint(x: 344, y: y))
            context.stroke(ribbon, with: .color(Color(red: 0.82, green: 0.56, blue: 0.28).opacity(0.38)), lineWidth: 1.5)
        }

        // Precision internal brass flywheel & gear train visible along top/lower deck.
        drawInternalGear(in: &context, center: CGPoint(x: 154, y: 42), radius: 20, teeth: 14, brass: true)
        drawInternalGear(in: &context, center: CGPoint(x: 192, y: 48), radius: 13, teeth: 10, brass: false)
        drawInternalGear(in: &context, center: CGPoint(x: 298, y: 44), radius: 18, teeth: 12, brass: false)
        drawInternalGear(in: &context, center: CGPoint(x: 54, y: 636), radius: 17, teeth: 12, brass: true)
        drawInternalGear(in: &context, center: CGPoint(x: 344, y: 834), radius: 22, teeth: 16, brass: false)

        // Drive belt connecting top pulley to secondary spindle.
        var belt = Path()
        belt.move(to: CGPoint(x: 154, y: 24))
        belt.addLine(to: CGPoint(x: 298, y: 28))
        belt.move(to: CGPoint(x: 154, y: 60))
        belt.addLine(to: CGPoint(x: 298, y: 60))
        context.stroke(belt, with: .color(.black.opacity(0.75)), lineWidth: 2.2)

        // Clear polycarbonate top-coat glare.
        var glare = Path()
        glare.move(to: CGPoint(x: -50, y: 220))
        glare.addLine(to: CGPoint(x: -50, y: 120))
        glare.addLine(to: CGPoint(x: 420, y: 640))
        glare.addLine(to: CGPoint(x: 420, y: 720))
        glare.closeSubpath()
        context.fill(
            glare,
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.18), .white.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 140),
                endPoint: CGPoint(x: 393, y: 700)
            )
        )
    }

    private static func drawInternalGear(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        teeth: Int,
        brass: Bool
    ) {
        let metal = brass
            ? Color(red: 0.76, green: 0.64, blue: 0.36)
            : Color(red: 0.68, green: 0.72, blue: 0.76)
        var gearPath = Path()
        let step = (.pi * 2) / CGFloat(teeth * 2)
        for i in 0..<(teeth * 2) {
            let r = i % 2 == 0 ? radius : radius - 2.6
            let angle = CGFloat(i) * step
            let pt = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if i == 0 { gearPath.move(to: pt) } else { gearPath.addLine(to: pt) }
        }
        gearPath.closeSubpath()
        context.fill(gearPath, with: .color(metal.opacity(0.36)))
        context.stroke(gearPath, with: .color(metal.opacity(0.68)), lineWidth: 0.7)
        let hub = CGRect(x: center.x - radius * 0.32, y: center.y - radius * 0.32,
                         width: radius * 0.64, height: radius * 0.64)
        context.fill(Path(ellipseIn: hub), with: .color(.black.opacity(0.65)))
        context.stroke(Path(ellipseIn: hub), with: .color(metal.opacity(0.55)), lineWidth: 0.7)
    }

    // MARK: - Shared Optical Primitives

    private static func drawBrushedLines(
        in context: inout GraphicsContext,
        rect: CGRect,
        count: Int,
        alpha: Double,
        vertical: Bool
    ) {
        for index in 0..<count {
            let n = noise(index * 5 + 3)
            let shade = n > 0.5 ? Color.white : Color.black
            var path = Path()
            if vertical {
                let x = CGFloat(index) * rect.width / CGFloat(count)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + 0.15, y: rect.height))
            } else {
                let y = CGFloat(index) * rect.height / CGFloat(count)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: rect.width, y: y + 0.15))
            }
            context.stroke(path, with: .color(shade.opacity(alpha * (0.4 + n * 0.6))), lineWidth: 0.25)
        }
    }

    private static func drawSpecularBand(
        in context: inout GraphicsContext,
        rect: CGRect,
        tilt: CGSize,
        intensity: Double
    ) {
        let centerY = rect.height * (0.48 + CGFloat(tilt.height) * 0.35 + CGFloat(tilt.width) * 0.18)
        let half: CGFloat = 155
        let stops: [Gradient.Stop] = [
            .init(color: .clear, location: 0.0),
            .init(color: .white.opacity(intensity * 0.28), location: 0.35),
            .init(color: .white.opacity(intensity), location: 0.50),
            .init(color: .white.opacity(intensity * 0.25), location: 0.65),
            .init(color: .clear, location: 1.0)
        ]
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(stops: stops),
                startPoint: CGPoint(x: 0, y: centerY - half - 55),
                endPoint: CGPoint(x: rect.width, y: centerY + half + 55)
            )
        )
    }

    private static func noise(_ index: Int) -> Double {
        var bits = UInt64(truncatingIfNeeded: index) &+ 0x9E3779B97F4A7C15
        bits = (bits ^ (bits >> 30)) &* 0xBF58476D1CE4E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D049BB133111EB
        return Double((bits ^ (bits >> 31)) & 65535) / 65535
    }
}
