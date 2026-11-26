import SwiftUI

/// Iridescent holographic / metallic foil layer on the 376.33×576 portrait
/// cassette canvas. Strictly masked by the active shell's cutout mask so reels,
/// drive gears and windows stay sharp and unobstructed.
struct OneTapeHoloFoilOverlay: View {
    let appearance: OneTapeAppearance
    var tilt: CGSize = OneTapeTiltMonitor.restingTilt

    private var style: OneTapeAppearance.TapeFoilStyle {
        appearance.tapeFoilStyle ?? .holo
    }

    var body: some View {
        let isDark = appearance.tapeStyle.usesLightInk
        ZStack {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let shift = Double(tilt.width) * 0.42 + Double(tilt.height) * 0.31
                let sweep = Double(tilt.width) * 0.55 - Double(tilt.height) * 0.35

                if style == .holo {
                    drawHoloSpectrum(in: &context, rect: rect, shift: shift, isDark: isDark)
                } else {
                    drawSilverFoil(in: &context, rect: rect, shift: shift, isDark: isDark)
                }
                drawBrushedMicroSheen(in: &context, rect: rect, sweep: sweep, isDark: isDark)
                drawSpecularSweep(in: &context, rect: rect, sweep: sweep, isDark: isDark)
            }
            if !appearance.tapeStyle.isSculpted {
                Image("OneTapeDoodleClassicLight")
                    .renderingMode(.original)
                    .resizable()
                    .frame(width: 376.33, height: 576)
                    .blendMode(.softLight)
                    .opacity(isDark ? 0.24 : 0.32)
            }
        }
        .frame(width: 376.33, height: 576)
        .blendMode(isDark ? .screen : .overlay)
        .opacity(isDark ? 0.80 : 0.72)
        .overlay {
            // Add a crisp top-coat prism glint that reads clearly even on bright
            // white or ivory shells where .overlay alone softens pastel hues.
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let phase = Double(tilt.width) * 0.48 + Double(tilt.height) * 0.26
                let stops = prismStops(phase: phase + 0.18, saturation: style == .holo ? 0.62 : 0.05, brightness: 0.98)
                let start = CGPoint(x: rect.width * (0.10 + CGFloat(tilt.width) * 0.22),
                                    y: rect.height * (0.04 + CGFloat(tilt.height) * 0.14))
                let end = CGPoint(x: rect.width * (0.90 + CGFloat(tilt.width) * 0.18),
                                  y: rect.height * (0.96 + CGFloat(tilt.height) * 0.12))
                context.fill(Path(rect), with: .linearGradient(Gradient(stops: stops), startPoint: start, endPoint: end))
            }
            .blendMode(isDark ? .plusLighter : .multiply)
            .opacity(isDark ? 0.22 : (style == .holo ? 0.34 : 0.18))
        }
        .compositingGroup()
        .mask {
            OneTapeShellPrintMask(tapeStyle: appearance.tapeStyle)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawHoloSpectrum(in context: inout GraphicsContext, rect: CGRect, shift: Double, isDark: Bool) {
        let primaryStops = prismStops(phase: shift, saturation: isDark ? 0.74 : 0.68, brightness: isDark ? 0.94 : 0.96)
        let angleX = CGFloat(tilt.width) * 110
        let angleY = CGFloat(tilt.height) * 140
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(stops: primaryStops),
                startPoint: CGPoint(x: -40 + angleX, y: -30 + angleY),
                endPoint: CGPoint(x: rect.width + 40 + angleX * 0.6, y: rect.height + 30 - angleY * 0.5)
            )
        )

        // Cross-angle diffraction interference wave for authentic rainbow foil depth.
        let secondaryStops = prismStops(phase: -shift * 1.35 + 0.38, saturation: 0.58, brightness: 0.95)
        var cross = context
        cross.opacity = 0.42
        cross.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(stops: secondaryStops),
                startPoint: CGPoint(x: rect.width + 20 - angleX * 0.8, y: 0),
                endPoint: CGPoint(x: -20 - angleX * 0.4, y: rect.height)
            )
        )
    }

    private func drawSilverFoil(in context: inout GraphicsContext, rect: CGRect, shift: Double, isDark: Bool) {
        let offset = CGFloat(shift) * 90
        let stops: [Gradient.Stop] = [
            .init(color: Color(white: isDark ? 0.44 : 0.68), location: 0.00),
            .init(color: Color(white: isDark ? 0.86 : 0.98), location: 0.22),
            .init(color: Color(white: isDark ? 0.36 : 0.56), location: 0.48),
            .init(color: Color(white: isDark ? 0.92 : 1.00), location: 0.74),
            .init(color: Color(white: isDark ? 0.48 : 0.72), location: 1.00)
        ]
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(stops: stops),
                startPoint: CGPoint(x: -50 + offset, y: 0),
                endPoint: CGPoint(x: rect.width + 50 + offset, y: rect.height)
            )
        )
    }

    private func drawBrushedMicroSheen(in context: inout GraphicsContext, rect: CGRect, sweep: Double, isDark: Bool) {
        // Horizontal hairlines in portrait canvas correspond to longitudinal
        // brushed grain along the cassette label's long axis.
        let lineCount = 260
        let baseAlpha = isDark ? 0.085 : 0.065
        for index in 0..<lineCount {
            let y = CGFloat(index) * rect.height / CGFloat(lineCount)
            let n = Self.noise(index * 7 + 13)
            let wave = 0.5 + 0.5 * sin(Double(index) * 0.19 + sweep * 5.2)
            let alpha = baseAlpha * (0.35 + n * 0.65) * (0.45 + wave * 0.55)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y + 0.15))
            context.stroke(path, with: .color((n > 0.48 ? Color.white : Color.black).opacity(alpha)), lineWidth: 0.38)
        }
    }

    private func drawSpecularSweep(in context: inout GraphicsContext, rect: CGRect, sweep: Double, isDark: Bool) {
        let centerY = rect.height * (0.50 + CGFloat(sweep) * 0.34)
        let bandHalf: CGFloat = 115
        let stops: [Gradient.Stop] = [
            .init(color: .clear, location: 0.0),
            .init(color: Color.white.opacity(isDark ? 0.16 : 0.22), location: 0.34),
            .init(color: Color.white.opacity(isDark ? 0.54 : 0.66), location: 0.50),
            .init(color: Color.white.opacity(isDark ? 0.14 : 0.20), location: 0.66),
            .init(color: .clear, location: 1.0)
        ]
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(stops: stops),
                startPoint: CGPoint(x: 0, y: centerY - bandHalf - 46),
                endPoint: CGPoint(x: rect.width, y: centerY + bandHalf + 46)
            )
        )
    }

    private func prismStops(phase: Double, saturation: Double, brightness: Double) -> [Gradient.Stop] {
        let count = 9
        return (0..<count).map { index in
            let t = Double(index) / Double(count - 1)
            let hue = (t * 1.18 + phase).truncatingRemainder(dividingBy: 1.0)
            let normalizedHue = hue < 0 ? hue + 1.0 : hue
            return Gradient.Stop(
                color: Color(hue: normalizedHue, saturation: saturation, brightness: brightness),
                location: t
            )
        }
    }

    private static func noise(_ index: Int) -> Double {
        var bits = UInt64(truncatingIfNeeded: index) &+ 0x9E3779B97F4A7C15
        bits = (bits ^ (bits >> 30)) &* 0xBF58476D1CE4E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D049BB133111EB
        return Double((bits ^ (bits >> 31)) & 65535) / 65535
    }
}
