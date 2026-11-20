import SwiftUI

/// Material-only drawing. The cover label, spindle and stickers are separate layers so
/// changing a material never changes the record's album identity or media state.
struct OrbitVinylSurface: View {
    let track: Track
    let artwork: UIImage?
    let material: OrbitRecordMaterial

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            ZStack {
                switch material {
                case .smoke:
                    smoke(side: side)
                case .silver:
                    Circle().fill(AngularGradient(colors: [Color(white: 0.74), Color(white: 0.91),
                        Color(white: 0.62), Color(white: 0.83), Color(white: 0.74)], center: .center))
                    Circle().fill(RadialGradient(colors: [.black.opacity(0.07), .clear, .white.opacity(0.12)],
                        center: .center, startRadius: 0, endRadius: side / 2))
                case .radial:
                    Circle().fill(Color(hex: 0x343C42))
                    radialFlutes(side: side)
                    Circle().fill(RadialGradient(colors: [.black.opacity(0.5), .clear, .white.opacity(0.12)],
                        center: .center, startRadius: 0, endRadius: side / 2))
                default:
                    Circle().fill(RadialGradient(colors: [Color(white: 0.07), Color(white: 0.035),
                        Color(white: 0.11), Color(white: 0.035)], center: .center, startRadius: 0, endRadius: side / 2))
                    Circle().fill(AngularGradient(colors: [.clear, .white.opacity(0.095), .clear,
                        .white.opacity(0.075), .clear], center: .center))
                }
                if side > 120 { grain(side: side) }
            }.frame(width: side, height: side).clipShape(Circle())
        }.accessibilityHidden(true)
    }

    private func smoke(side: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(hex: 0x25333E))
            ArtworkView(track: track, image: artwork)
                .saturation(0.18).blur(radius: side * 0.045).opacity(0.14)
            Canvas { context, size in
                context.addFilter(.blur(radius: max(0.5, side * 0.009)))
                for index in 0..<15 {
                    let phase = Double(index) * 1.37 + seed
                    let start = CGFloat(sin(phase)) * size.width * 0.38
                    var vein = Path()
                    vein.move(to: CGPoint(x: start, y: -size.height * 0.1))
                    vein.addCurve(to: CGPoint(x: size.width * 0.76 - start, y: size.height * 1.1),
                        control1: CGPoint(x: size.width * 0.9 + start, y: size.height * 0.28),
                        control2: CGPoint(x: -size.width * 0.1 - start, y: size.height * 0.67))
                    context.stroke(vein, with: .color(index.isMultiple(of: 3) ?
                        Color(hex: 0x968B7D).opacity(0.12) : .black.opacity(0.13)),
                        lineWidth: side * (index.isMultiple(of: 3) ? 0.009 : 0.02))
                }
            }
            Circle().fill(AngularGradient(colors: [.white.opacity(0.12), .clear, .black.opacity(0.16),
                .clear, .white.opacity(0.12)], center: .center, angle: .degrees(-36)))
        }
    }

    private func radialFlutes(side: CGFloat) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for index in 0..<96 {
                let angle = Double(index) * .pi / 48
                let radius = side / 2
                var ray = Path()
                ray.move(to: CGPoint(x: center.x + cos(angle) * radius * 0.48,
                                    y: center.y + sin(angle) * radius * 0.48))
                ray.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
                context.stroke(ray, with: .color(index.isMultiple(of: 2) ? .white.opacity(0.24) : .black.opacity(0.25)),
                               lineWidth: side * 0.007)
            }
        }
    }

    private func grain(side: CGFloat) -> some View {
        Canvas { context, size in
            // Stable inexpensive grain belongs to the cached full-size print. Tiny picker
            // swatches omit it because these subpixel marks cannot be resolved there.
            for index in 0..<1_300 {
                let x = fraction(index, salt: 17) * size.width
                let y = fraction(index, salt: 53) * size.height
                let diameter = side * (index.isMultiple(of: 5) ? 0.0014 : 0.0007)
                let box = CGRect(x: x, y: y, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: box), with: .color(index.isMultiple(of: 2) ?
                    .white.opacity(0.10) : .black.opacity(0.15)))
            }
        }.blendMode(.overlay)
    }

    private var seed: Double { Double(track.id.utf8.reduce(UInt64(19)) { $0 &* 31 &+ UInt64($1) } % 10_007) / 1_001 }
    private func fraction(_ index: Int, salt: Int) -> Double {
        let value = sin(Double(index * salt + salt) * 12.9898 + seed) * 43_758.5453
        return value - floor(value)
    }
}
