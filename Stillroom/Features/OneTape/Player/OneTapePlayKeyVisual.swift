import SwiftUI

/// Only the cap's interior illuminates. Its photographed rim and padding stay
/// identical before, during and after playback, including iOS 26 glass systems.
struct OneTapePlayKeyVisual: View {
    let illuminated: Bool
    let quarterTurns: Int
    var graphite = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.26),
                    Color(red: 0.92, green: 0.85, blue: 0.66).opacity(0.12), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 49))
                .padding(6)
                .blendMode(.screen)
                .opacity(illuminated ? 1 : 0)
            // Match the triangle in the source photo's 65.33-point crop.
            // A mark overlay changes ink only, never the cap's outer geometry.
            Path { path in
                path.move(to: CGPoint(x: 22.7, y: 20.1))
                path.addLine(to: CGPoint(x: 39.3, y: 29))
                path.addLine(to: CGPoint(x: 22.7, y: 37.9))
                path.closeSubpath()
            }
            .fill(graphite ? Color(red: 0.86, green: 0.27, blue: 0.14) : .white)
            .rotationEffect(.degrees(Double(quarterTurns) * 90))
            .opacity(graphite || illuminated ? 1 : 0)
        }
        .frame(width: OneTapeTransportGeometry.visualDiameter,
               height: OneTapeTransportGeometry.visualDiameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}
