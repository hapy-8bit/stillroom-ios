import SwiftUI

/// Decorative studies have their own slow visual time. They may drift without
/// audio; unlike the scope and spectrum, their marks do not claim to be samples.
struct OneTapeAtmosphereScreens: View {
    let style: OneTapeAppearance.ScreenStyle
    let phase: Double
    let response: OneTapeScreenResponse

    var body: some View {
        Canvas { context, size in
            switch style {
            case .ink: ink(context, size: size)
            case .rain: rain(context, size: size)
            case .trails: trails(context, size: size)
            default: break
            }
            OneTapeScreenArt.finish(context, size: size, grain: 330)
        }
    }

    private func ink(_ context: GraphicsContext, size: CGSize) {
        OneTapeScreenArt.background(context, size: size,
                                    top: Color(red: 0.79, green: 0.83, blue: 0.81),
                                    bottom: Color(red: 0.57, green: 0.65, blue: 0.64))
        let unit = min(size.width, size.height)
        let center = CGPoint(x: size.width * (0.48 + sin(phase * 0.09) * 0.035),
                             y: size.height * 0.51)
        for wash in (0..<15).reversed() {
            let layer = Double(wash)
            let points = (0..<80).map { index -> CGPoint in
                let angle = Double(index) / 80 * 2 * .pi
                let bloom = sin(angle * 3 + phase * 0.13) * 0.13
                    + cos(angle * 5 - phase * 0.08 + layer * 0.04) * 0.09
                    + sin(angle * 9 + phase * 0.05) * 0.025
                let radius = unit * (0.27 + layer * 0.0055) * (1 + bloom)
                return CGPoint(x: center.x + cos(angle) * radius * 1.18,
                               y: center.y + sin(angle) * radius)
            }
            let path = OneTapeScreenArt.closedSpline(points)
            let shade = Color(red: 0.07 + layer * 0.004,
                              green: 0.13 + layer * 0.006, blue: 0.15 + layer * 0.006)
            context.fill(path, with: .color(shade.opacity(wash == 0 ? 0.97 : 0.10)))
            context.stroke(path, with: .color(shade.opacity(0.12)), lineWidth: 0.5)
        }
        // Curved pigment streams are deliberately sparse, like wet ink on paper.
        var currents = Path()
        for index in 0..<28 {
            let seed = Double(index)
            let angle = seed / 28 * .pi * 2 + phase * 0.025
            let outer = CGPoint(x: center.x + cos(angle) * unit * 0.42,
                                y: center.y + sin(angle) * unit * 0.34)
            let inner = CGPoint(x: center.x + cos(angle + 0.5) * unit * 0.13,
                                y: center.y + sin(angle + 0.5) * unit * 0.1)
            currents.move(to: outer)
            currents.addCurve(to: inner,
                              control1: CGPoint(x: outer.x - sin(angle) * 17, y: outer.y + cos(angle) * 15),
                              control2: CGPoint(x: inner.x + sin(angle) * 24, y: inner.y - cos(angle) * 17))
        }
        context.stroke(currents, with: .color(Color(red: 0.08, green: 0.17, blue: 0.18).opacity(0.18)),
                       style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
        for index in 0..<35 {
            let seed = Double(index)
            let angle = OneTapeScreenArt.noise(seed * 3.11) * .pi * 2
            let radius = unit * (0.37 + OneTapeScreenArt.noise(seed * 1.61) * 0.16)
            let side = 0.6 + OneTapeScreenArt.noise(seed) * 2
            let point = CGPoint(x: center.x + cos(angle) * radius * 1.2,
                                y: center.y + sin(angle) * radius)
            context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: side, height: side)),
                         with: .color(Color(red: 0.12, green: 0.23, blue: 0.24).opacity(0.22)))
        }
    }

    private func rain(_ context: GraphicsContext, size: CGSize) {
        OneTapeScreenArt.background(context, size: size,
                                    top: Color(red: 0.075, green: 0.13, blue: 0.16),
                                    bottom: Color(red: 0.025, green: 0.065, blue: 0.085))
        context.drawLayer { mist in
            mist.addFilter(.blur(radius: 18))
            for index in 0..<4 {
                let seed = Double(index)
                let x = size.width * (0.18 + seed * 0.24 + sin(phase * 0.05 + seed) * 0.035)
                let color = index == 3 ? OneTapeScreenArt.copper : OneTapeScreenArt.teal
                mist.fill(Path(ellipseIn: CGRect(x: x, y: -25 + seed * 18,
                                                 width: 18 + seed * 5, height: size.height * 1.3)),
                          with: .color(color.opacity(index == 3 ? 0.18 : 0.13)))
            }
        }
        for index in 0..<27 {
            let seed = Double(index)
            let x = (0.035 + OneTapeScreenArt.noise(seed * 8.31) * 0.93) * size.width
            let speed = 1.2 + OneTapeScreenArt.noise(seed * 3.17) * 3
            let y = (OneTapeScreenArt.noise(seed * 7.3) * (size.height + 60) + phase * speed)
                .truncatingRemainder(dividingBy: size.height + 60) - 30
            let width = 2.8 + OneTapeScreenArt.noise(seed * 2.1) * 4
            let height = width * (1.6 + OneTapeScreenArt.noise(seed + 1) * 1.6)
            let drop = droplet(center: CGPoint(x: x, y: y), width: width, height: height)
            let trail = Path(CGRect(x: x - 0.35, y: y - 42 - height,
                                    width: 0.7, height: 44))
            context.fill(trail, with: .linearGradient(
                Gradient(colors: [.clear, OneTapeScreenArt.silver.opacity(0.12)]),
                startPoint: CGPoint(x: x, y: y - 42 - height), endPoint: CGPoint(x: x, y: y)))
            context.fill(drop, with: .linearGradient(
                Gradient(stops: [.init(color: .white.opacity(0.23), location: 0),
                                 .init(color: .black.opacity(0.2), location: 0.28),
                                 .init(color: OneTapeScreenArt.teal.opacity(0.1), location: 0.7),
                                 .init(color: .white.opacity(0.26), location: 1)]),
                startPoint: CGPoint(x: x - width, y: y - height / 2),
                endPoint: CGPoint(x: x + width / 2, y: y + height / 2)))
            context.stroke(drop, with: .color(OneTapeScreenArt.silver.opacity(0.23)), lineWidth: 0.55)
            var highlight = Path()
            highlight.move(to: CGPoint(x: x - width * 0.23, y: y - height * 0.13))
            highlight.addQuadCurve(to: CGPoint(x: x - width * 0.15, y: y + height * 0.22),
                                   control: CGPoint(x: x - width * 0.45, y: y + height * 0.07))
            context.stroke(highlight, with: .color(.white.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        }
        for index in 0..<100 {
            let seed = Double(index)
            let x = OneTapeScreenArt.noise(seed * 1.7) * size.width
            let y = OneTapeScreenArt.noise(seed * 2.1) * size.height
            context.stroke(Path(ellipseIn: CGRect(x: x, y: y, width: 1.3, height: 1.8)),
                           with: .color(.white.opacity(0.1)), lineWidth: 0.35)
        }
    }

    private func droplet(center: CGPoint, width: Double, height: Double) -> Path {
        Path { path in
            path.move(to: CGPoint(x: center.x, y: center.y - height * 0.55))
            path.addCurve(to: CGPoint(x: center.x, y: center.y + height * 0.5),
                          control1: CGPoint(x: center.x + width * 0.48, y: center.y - height * 0.3),
                          control2: CGPoint(x: center.x + width * 0.74, y: center.y + height * 0.48))
            path.addCurve(to: CGPoint(x: center.x, y: center.y - height * 0.55),
                          control1: CGPoint(x: center.x - width * 0.74, y: center.y + height * 0.48),
                          control2: CGPoint(x: center.x - width * 0.48, y: center.y - height * 0.3))
            path.closeSubpath()
        }
    }

    private func trails(_ context: GraphicsContext, size: CGSize) {
        OneTapeScreenArt.background(context, size: size,
                                    top: Color(red: 0.065, green: 0.08, blue: 0.09),
                                    bottom: Color(red: 0.018, green: 0.023, blue: 0.03))
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let unit = min(size.width, size.height)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [OneTapeScreenArt.copper.opacity(0.1), .clear]), center: center,
            startRadius: 0, endRadius: unit * 0.6))
        for ribbon in 0..<28 {
            let strand = Double(ribbon)
            var points: [CGPoint] = []
            for index in 0...170 {
                let t = Double(index) / 170 * .pi * 2
                let twist = t * 3 + strand * 0.055 + phase * 0.14
                let radius = unit * (0.29 + cos(t * 2 - phase * 0.09) * 0.105)
                let depth = sin(t + phase * 0.07)
                let x = center.x + cos(t + phase * 0.035) * radius * 1.42
                    + cos(twist) * unit * 0.10
                let y = center.y + sin(t + phase * 0.035) * radius * 0.65
                    + sin(twist) * unit * 0.13 + depth * strand * 0.24
                points.append(CGPoint(x: x, y: y))
            }
            let path = OneTapeScreenArt.line(points)
            let alpha = 0.12 + sin(strand / 27 * .pi) * 0.43
            context.stroke(path, with: .linearGradient(
                Gradient(colors: [OneTapeScreenArt.copper.opacity(alpha),
                                  OneTapeScreenArt.silver.opacity(alpha * 0.9),
                                  OneTapeScreenArt.teal.opacity(alpha * 0.45)]),
                startPoint: CGPoint(x: 0, y: size.height), endPoint: CGPoint(x: size.width, y: 0)),
                           style: StrokeStyle(lineWidth: ribbon % 7 == 0 ? 0.85 : 0.38,
                                              lineCap: .round, lineJoin: .round))
        }
        let angle = phase * 0.16
        let point = CGPoint(x: center.x + cos(angle) * unit * 0.43,
                            y: center.y + sin(angle * 2) * unit * 0.15)
        var halo = context
        halo.addFilter(.blur(radius: 3))
        halo.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                  with: .color(OneTapeScreenArt.copper.opacity(0.5)))
        context.fill(Path(ellipseIn: CGRect(x: point.x - 0.7, y: point.y - 0.7, width: 1.4, height: 1.4)),
                     with: .color(OneTapeScreenArt.silver.opacity(0.8)))
    }
}
