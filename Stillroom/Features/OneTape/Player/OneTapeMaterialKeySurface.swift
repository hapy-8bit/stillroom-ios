import SwiftUI

/// Material optics fit the existing 58-point key. Neither the rim nor the
/// visible outline depends on touch/playback state; only the caller's lamp does.
struct OneTapeMaterialKeySurface: View {
    let material: OneTapeBodyMaterial
    let palette: OneTapeBodyMaterialPalette

    var body: some View {
        Canvas { context, _ in
            let rect = CGRect(x: 0, y: 0, width: 58, height: 58)
            let rim = Path(ellipseIn: rect.insetBy(dx: 0.8, dy: 0.8))
            let cap = Path(ellipseIn: rect.insetBy(dx: 4, dy: 4))
            let base = palette.key
            context.fill(rim, with: .linearGradient(
                Gradient(stops: [
                    .init(color: base.mixed(with: .init(1, 1, 1), fraction: 0.62).materialColor, location: 0),
                    .init(color: base.mixed(with: .init(0, 0, 0), fraction: 0.65).materialColor, location: 0.36),
                    .init(color: base.materialColor, location: 0.65),
                    .init(color: base.mixed(with: .init(1, 1, 1), fraction: 0.50).materialColor, location: 1)
                ]), startPoint: CGPoint(x: 5, y: 0), endPoint: CGPoint(x: 46, y: 58)))
            context.fill(cap, with: .radialGradient(
                Gradient(colors: [
                    base.mixed(with: .init(1, 1, 1), fraction: material.isGlass ? 0.15 : 0.09).materialColor,
                    base.materialColor,
                    base.mixed(with: .init(0, 0, 0), fraction: 0.15).materialColor
                ]), center: CGPoint(x: 20, y: 13), startRadius: 0, endRadius: 49))
            var face = context
            face.clip(to: cap)
            if material.isGlass {
                var reflection = Path()
                reflection.move(to: CGPoint(x: 3, y: 17))
                reflection.addQuadCurve(to: CGPoint(x: 42, y: 5), control: CGPoint(x: 14, y: -2))
                reflection.addQuadCurve(to: CGPoint(x: 14, y: 29), control: CGPoint(x: 25, y: 10))
                reflection.closeSubpath()
                face.fill(reflection, with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.46), .white.opacity(0.025)]),
                    startPoint: .zero, endPoint: CGPoint(x: 24, y: 31)))
            } else {
                for index in 0..<100 {
                    let y = CGFloat(index) * 0.58
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: 58, y: y))
                    face.stroke(line, with: .color((index % 3 == 0 ? Color.white : .black)
                        .opacity(material == .brushedAluminum ? 0.06 : 0.04)), lineWidth: 0.18)
                }
            }
            context.stroke(cap, with: .linearGradient(
                Gradient(colors: [.white.opacity(0.66), .clear, .black.opacity(0.32)]),
                startPoint: .zero, endPoint: CGPoint(x: 58, y: 58)), lineWidth: 0.75)
            var glare = Path()
            glare.addArc(center: CGPoint(x: 29, y: 29), radius: 26,
                         startAngle: .degrees(192), endAngle: .degrees(272), clockwise: false)
            context.stroke(glare, with: .color(.white.opacity(material.isGlass ? 0.78 : 0.48)),
                           style: StrokeStyle(lineWidth: material.isGlass ? 1.6 : 0.85, lineCap: .round))
            var returnLight = Path()
            returnLight.addArc(center: CGPoint(x: 29, y: 29), radius: 25.5,
                startAngle: .degrees(8), endAngle: .degrees(72), clockwise: false)
            context.stroke(returnLight, with: .color(.white.opacity(0.24)), lineWidth: 0.7)
        }
        .frame(width: 58, height: 58)
        .clipShape(Circle())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
