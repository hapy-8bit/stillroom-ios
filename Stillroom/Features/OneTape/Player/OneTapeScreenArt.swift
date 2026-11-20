import SwiftUI

/// A restrained palette shared by the small displays: smoked glass, brushed
/// silver and a little warm copper. These clocks never represent media time.
enum OneTapeScreenArt {
    static let charcoal = Color(red: 0.045, green: 0.060, blue: 0.066)
    static let silver = Color(red: 0.82, green: 0.86, blue: 0.83)
    static let copper = Color(red: 0.76, green: 0.49, blue: 0.27)
    static let teal = Color(red: 0.34, green: 0.59, blue: 0.57)
    static let paper = Color(red: 0.85, green: 0.87, blue: 0.85)

    static func background(_ context: GraphicsContext, size: CGSize,
                           top: Color = charcoal, bottom: Color = .black) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [top, bottom]), startPoint: .zero,
            endPoint: CGPoint(x: size.width * 0.8, y: size.height)))
    }

    static func finish(_ context: GraphicsContext, size: CGSize, grain: Int = 280) {
        for index in 0..<grain {
            let seed = Double(index)
            let point = CGPoint(x: noise(seed * 1.73) * size.width,
                                y: noise(seed * 5.21) * size.height)
            let side = 0.3 + noise(seed * 2.91) * 0.45
            context.fill(Path(CGRect(x: point.x, y: point.y, width: side, height: side)),
                         with: .color(.white.opacity(0.025 + noise(seed) * 0.035)))
        }
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(stops: [.init(color: .clear, location: 0.35),
                             .init(color: .black.opacity(0.32), location: 1)]),
            center: CGPoint(x: size.width * 0.5, y: size.height * 0.45),
            startRadius: 0, endRadius: max(size.width, size.height) * 0.68))
    }

    static func noise(_ seed: Double) -> Double {
        let value = sin(seed * 12.9898 + 78.233) * 43_758.5453
        return value - floor(value)
    }

    static func line(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
        }
    }

    static func closedSpline(_ points: [CGPoint]) -> Path {
        Path { path in
            guard points.count > 3 else { return }
            path.move(to: points[0])
            for index in points.indices {
                let before = points[(index + points.count - 1) % points.count]
                let start = points[index]
                let end = points[(index + 1) % points.count]
                let after = points[(index + 2) % points.count]
                path.addCurve(to: end,
                              control1: CGPoint(x: start.x + (end.x - before.x) / 6,
                                                y: start.y + (end.y - before.y) / 6),
                              control2: CGPoint(x: end.x - (after.x - start.x) / 6,
                                                y: end.y - (after.y - start.y) / 6))
            }
            path.closeSubpath()
        }
    }

    static func glow(_ path: Path, context: GraphicsContext, color: Color,
                     width: CGFloat, radius: CGFloat = 3) {
        var glow = context
        glow.addFilter(.blur(radius: radius))
        glow.stroke(path, with: .color(color.opacity(0.32)), lineWidth: width * 3)
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}
