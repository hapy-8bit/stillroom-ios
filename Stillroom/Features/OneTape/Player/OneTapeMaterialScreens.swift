import SwiftUI

/// Procedural water surface. The photographic materials have their own renderer;
/// this remaining effect consumes measured response and the caller-owned clock.
struct OneTapeMaterialScreens: View {
    let style: OneTapeAppearance.ScreenStyle
    let phase: Double
    let response: OneTapeScreenResponse

    var body: some View {
        Canvas { context, size in
            switch style {
            case .water: water(context, size: size)
            default: break
            }
            OneTapeScreenArt.finish(context, size: size)
        }
    }

    private func water(_ context: GraphicsContext, size: CGSize) {
        OneTapeScreenArt.background(context, size: size,
                                    top: Color(red: 0.08, green: 0.20, blue: 0.22),
                                    bottom: Color(red: 0.025, green: 0.075, blue: 0.095))
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [OneTapeScreenArt.teal.opacity(0.25), .clear]),
            center: CGPoint(x: size.width * 0.62, y: size.height * 0.3),
            startRadius: 0, endRadius: size.width * 0.68))
        for row in 0..<52 {
            let baseY = Double(row) / 51 * size.height
            var points: [CGPoint] = []
            var slope = 0.0
            for column in 0...100 {
                let x = Double(column) / 100 * size.width
                var height = sin(x * 0.034 + phase * 0.27 + Double(row) * 0.19) * 0.55
                for drop in 0..<3 {
                    let seed = Double(drop)
                    let cx = size.width * (0.27 + seed * 0.25 + sin(seed + phase * 0.07) * 0.05)
                    let cy = size.height * (0.38 + Double(drop % 2) * 0.31)
                    let distance = hypot(x - cx, (baseY - cy) * 1.65)
                    let wave = sin(distance * 0.17 - phase * 1.5 - seed * 2.1)
                    height += wave * exp(-distance / 96) * (2 + response.intensity * 3)
                }
                slope += abs(height)
                points.append(CGPoint(x: x, y: baseY + height))
            }
            let path = OneTapeScreenArt.line(points)
            let sheen = 0.10 + min(0.28, slope / 700)
            context.stroke(path.offsetBy(dx: 0, dy: 1.2),
                           with: .color(.black.opacity(0.34)), lineWidth: 1.4)
            context.stroke(path, with: .linearGradient(
                Gradient(colors: [OneTapeScreenArt.teal.opacity(sheen),
                                  OneTapeScreenArt.silver.opacity(sheen + 0.18),
                                  OneTapeScreenArt.teal.opacity(sheen * 0.6)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height * 0.7)),
                           lineWidth: 0.7)
        }
        for index in 0..<18 {
            let seed = Double(index)
            let x = size.width * (0.58 + sin(seed * 2.3 + phase * 0.16) * 0.13)
            let y = OneTapeScreenArt.noise(seed * 3.1) * size.height
            let alpha = 0.06 + pow(max(0, sin(seed + phase * 0.4)), 6) * 0.18
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.5, height: 0.7)),
                         with: .color(OneTapeScreenArt.silver.opacity(alpha)))
        }
    }

}
