import SwiftUI

struct VinylRecord: View {
    let track: Track
    var artwork: UIImage?
    var running = false
    var reducedMotion = false
    var studio = false

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size.width
            ZStack {
                Group {
                    if studio {
                        Image("StudioVinylSurface").resizable().interpolation(.high)
                    } else {
                        Canvas { context, dimensions in
                            let bounds = CGRect(origin: .zero, size: dimensions)
                            context.fill(Path(ellipseIn: bounds), with: .radialGradient(
                                Gradient(colors: [Color(hex: 0x1C2424), Color(hex: 0x070B0D), Color(hex: 0x242B2A)]),
                                center: CGPoint(x: size / 2, y: size / 2), startRadius: 0, endRadius: size / 2))
                            // Room grooves retain the original normalized drawing; the studio uses a baked surface.
                            for index in 0..<112 {
                                let inset = size * (0.018 + Double(index) * 0.0027)
                                context.stroke(Path(ellipseIn: bounds.insetBy(dx: inset, dy: inset)),
                                               with: .color(index.isMultiple(of: 3) ? .white.opacity(0.07) : .black.opacity(0.6)),
                                               lineWidth: max(0.3, size * 0.001))
                            }
                        }.drawingGroup()
                    }
                }.shadow(color: .black.opacity(0.55), radius: 16, x: 4, y: 14)
                Circle().fill(AngularGradient(colors: [.clear, .white.opacity(0.10), .clear, .black.opacity(0.15),
                                                      .clear, .white.opacity(0.08), .clear], center: .center))
                RecordLabelSurface(track: track, artwork: artwork, running: running && !reducedMotion)
                    .frame(width: size * 0.32, height: size * 0.32)
                    .overlay(Color.black.opacity(0.12)).clipShape(Circle())
                    .overlay(Circle().strokeBorder(RoomStyle.paper.opacity(0.45), lineWidth: 0.7))
                Circle().fill(Color(hex: 0x101B1B)).frame(width: size * 0.025, height: size * 0.025)
                    .overlay(Circle().strokeBorder(RoomStyle.paper.opacity(0.5), lineWidth: 1))
            }.overlay(Circle().strokeBorder(.white.opacity(0.13), lineWidth: 1))
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }
}
