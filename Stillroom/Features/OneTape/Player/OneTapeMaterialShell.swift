import SwiftUI

/// Static 393×852 logical-point surface. The caller masks out the cassette,
/// screen and source switch; optical effects never cover those live contents.
struct OneTapeMaterialShell: View {
    let material: OneTapeBodyMaterial
    var color: OneTapeAppearance.BodyColor = .black

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 393, y: size.height / 852)
            let palette = material.palette(color: color)
            let rect = CGRect(x: 0, y: 0, width: 393, height: 852)
            context.fill(Path(rect), with: .color(palette.shell.materialColor))
            if material.isGlass {
                glass(in: &context, palette: palette, rect: rect)
            } else {
                metal(in: &context, palette: palette, rect: rect)
            }
            edges(in: &context, palette: palette, rect: rect)
            fittings(in: &context, palette: palette)
        }
        .frame(width: 393, height: 852)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glass(in context: inout GraphicsContext,
                       palette: OneTapeBodyMaterialPalette, rect: CGRect) {
        let frosted = material == .frostedGlass
        let base = palette.shell
        context.fill(Path(rect), with: .linearGradient(
            Gradient(stops: [
                .init(color: base.mixed(with: .init(1, 1, 1), fraction: frosted ? 0.38 : 0.12).materialColor,
                      location: 0),
                .init(color: base.materialColor, location: 0.32),
                .init(color: base.mixed(with: .init(0, 0, 0), fraction: 0.40).materialColor, location: 1)
            ]), startPoint: .zero, endPoint: CGPoint(x: 393, y: 852)))

        // A shallow inner chassis gives glass something to transmit. These
        // rails/components are decorative; none represent user/audio state.
        var inner = context
        inner.opacity = frosted ? 0.30 : 0.65
        if frosted { inner.addFilter(.blur(radius: 0.65)) }
        let rail = Path(roundedRect: rect.insetBy(dx: 9, dy: 9), cornerRadius: 51)
        inner.stroke(rail, with: .color(.black.opacity(0.65)), lineWidth: 4)
        inner.stroke(Path(roundedRect: rect.insetBy(dx: 13, dy: 13), cornerRadius: 47),
                     with: .color(.white.opacity(0.32)), lineWidth: 0.6)
        for (index, x) in [125.0, 175.0, 226.0, 280.0, 329.0].enumerated() {
            let component = CGRect(x: x, y: 26 + Double(index % 2) * 7,
                                   width: index % 2 == 0 ? 29 : 17, height: 17)
            inner.fill(Path(roundedRect: component, cornerRadius: 2.5),
                       with: .color(Color(red: 0.08, green: 0.13, blue: 0.15).opacity(0.8)))
            inner.stroke(Path(roundedRect: component.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 1),
                         with: .color(.white.opacity(0.25)), lineWidth: 0.5)
            for pin in 0..<4 {
                let y = component.minY + 3 + CGFloat(pin) * 3.5
                var path = Path()
                path.move(to: CGPoint(x: component.minX - 4, y: y))
                path.addLine(to: CGPoint(x: component.minX + 1, y: y))
                path.move(to: CGPoint(x: component.maxX - 1, y: y))
                path.addLine(to: CGPoint(x: component.maxX + 4, y: y))
                inner.stroke(path, with: .color(Color(red: 0.75, green: 0.65, blue: 0.42).opacity(0.75)),
                             lineWidth: 0.8)
            }
        }
        for index in 0..<3 {
            var trace = Path()
            let y = 51 + CGFloat(index) * 3
            trace.move(to: CGPoint(x: 107, y: y))
            trace.addLine(to: CGPoint(x: 208 + CGFloat(index) * 7, y: y))
            trace.addLine(to: CGPoint(x: 224 + CGFloat(index) * 7, y: y - 12))
            trace.addLine(to: CGPoint(x: 350, y: y - 12))
            inner.stroke(trace, with: .color(.white.opacity(0.32)), lineWidth: 0.5)
        }

        // Two offset highlights and a darker return edge suggest the thickness
        // of a glass slab. The mask clips them at each real opening.
        var reflection = Path()
        reflection.move(to: CGPoint(x: -80, y: 245))
        reflection.addLine(to: CGPoint(x: -80, y: 135))
        reflection.addLine(to: CGPoint(x: 430, y: 696))
        reflection.addLine(to: CGPoint(x: 430, y: 776))
        reflection.closeSubpath()
        context.fill(reflection, with: .linearGradient(
            Gradient(colors: [.white.opacity(frosted ? 0.26 : 0.14), .white.opacity(0.025)]),
            startPoint: CGPoint(x: 20, y: 150), endPoint: CGPoint(x: 360, y: 760)))
        var thinReflection = Path()
        thinReflection.move(to: CGPoint(x: 255, y: -30))
        thinReflection.addLine(to: CGPoint(x: 286, y: -30))
        thinReflection.addLine(to: CGPoint(x: 410, y: 174))
        thinReflection.addLine(to: CGPoint(x: 410, y: 231))
        thinReflection.closeSubpath()
        context.fill(thinReflection, with: .color(.white.opacity(frosted ? 0.22 : 0.16)))

        // Fixed seeds keep grain completely still when playback updates the
        // parent view. Texture does not need a TimelineView or a sensor listener.
        for index in 0..<1900 {
            let x = Self.noise(index * 3) * 393
            let y = Self.noise(index * 3 + 1) * 852
            let dot = CGRect(x: x, y: y, width: 0.30, height: 0.30)
            context.fill(Path(ellipseIn: dot),
                         with: .color(.white.opacity(frosted ? 0.16 : 0.06)))
        }
    }

    private func metal(in context: inout GraphicsContext,
                       palette: OneTapeBodyMaterialPalette, rect: CGRect) {
        let aluminum = material == .brushedAluminum
        let base = palette.shell
        let values: [(Double, Double)] = aluminum
            ? [(0, -0.30), (0.12, 0.30), (0.31, -0.10), (0.51, 0.34), (0.69, -0.17), (1, 0.13)]
            : [(0, -0.25), (0.16, 0.12), (0.44, -0.02), (0.72, 0.15), (1, -0.15)]
        let stops = values.map { location, value in
            Gradient.Stop(color: base.mixed(with: value > 0 ? .init(1, 1, 1) : .init(0, 0, 0),
                                            fraction: abs(value)).materialColor, location: location)
        }
        context.fill(Path(rect), with: .linearGradient(Gradient(stops: stops),
            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 393, y: 80)))
        context.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [.white.opacity(aluminum ? 0.16 : 0.035), .clear, .black.opacity(0.15)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: 852)))

        // Sub-point strokes are rasterized at the actual screen scale. Their
        // pitch is in design points, with no assumptions about a device's pixels.
        let count = aluminum ? 1350 : 1000
        for index in 0..<count {
            let y = CGFloat(index) * 852 / CGFloat(count)
            let light = Self.noise(index * 5) > 0.53
            let alpha = (aluminum ? 0.035 : 0.022) + Self.noise(index * 5 + 1) * 0.04
            let start = Self.noise(index * 5 + 2) * 55 - 30
            var hairline = Path()
            hairline.move(to: CGPoint(x: start, y: y))
            hairline.addLine(to: CGPoint(x: 393 - Self.noise(index * 5 + 3) * 40, y: y + 0.12))
            context.stroke(hairline, with: .color((light ? Color.white : .black).opacity(alpha)),
                           lineWidth: aluminum ? 0.24 : 0.20)
        }
    }

    private func edges(in context: inout GraphicsContext,
                       palette: OneTapeBodyMaterialPalette, rect: CGRect) {
        let outer = Path(roundedRect: rect.insetBy(dx: 1.4, dy: 1.4), cornerRadius: 57.6)
        let inset = Path(roundedRect: rect.insetBy(dx: 4.3, dy: 4.3), cornerRadius: 54.7)
        context.stroke(outer, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.85), .white.opacity(0.16), .black.opacity(0.55),
                              .white.opacity(0.34)]),
            startPoint: .zero, endPoint: CGPoint(x: 393, y: 852)), lineWidth: material.isGlass ? 2.4 : 1.8)
        context.stroke(inset, with: .linearGradient(
            Gradient(colors: [.black.opacity(0.24), .white.opacity(material.isGlass ? 0.52 : 0.35)]),
            startPoint: CGPoint(x: 393, y: 0), endPoint: CGPoint(x: 0, y: 852)), lineWidth: 0.8)

        let apertures: [(CGRect, CGFloat)] = [
            (CGRect(x: 96.5, y: 647.3, width: 272.05, height: 173.3), 6.3)
        ]
        // The cassette module supplies its own fixed frame. Adding another
        // broad dark stroke outside it creates a double border on light bodies.
        for (rect, radius) in apertures {
            let path = Path(roundedRect: rect, cornerRadius: radius)
            context.stroke(path, with: .color(.black.opacity(material.isGlass ? 0.34 : 0.48)), lineWidth: 5.4)
            context.stroke(path, with: .linearGradient(
                Gradient(colors: [.white.opacity(0.78), .white.opacity(0.08), .black.opacity(0.36)]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)), lineWidth: 1.1)
        }
        for y in OneTapeTransportGeometry.centersY {
            let seat = CGRect(x: OneTapeTransportGeometry.centerX - 30.8, y: y - 30.8,
                              width: 61.6, height: 61.6)
            context.stroke(Path(ellipseIn: seat), with: .linearGradient(
                Gradient(colors: [.black.opacity(0.5), .white.opacity(0.48)]),
                startPoint: CGPoint(x: seat.minX, y: seat.minY),
                endPoint: CGPoint(x: seat.maxX, y: seat.maxY)), lineWidth: 1.3)
        }
    }

    private func fittings(in context: inout GraphicsContext, palette: OneTapeBodyMaterialPalette) {
        for center in [CGPoint(x: 13.5, y: 63), CGPoint(x: 379.5, y: 63),
                       CGPoint(x: 13.5, y: 637), CGPoint(x: 379.5, y: 637)] {
            let rect = CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)
            context.fill(Path(ellipseIn: rect), with: .linearGradient(
                Gradient(colors: [.white.opacity(0.65), .black.opacity(0.50)]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
            var slot = Path()
            slot.move(to: CGPoint(x: center.x - 0.7, y: center.y))
            slot.addLine(to: CGPoint(x: center.x + 0.7, y: center.y))
            context.stroke(slot, with: .color(.black.opacity(0.5)), lineWidth: 0.5)
        }
        let text = Text(material.engraving)
            .font(.system(size: 4.3, weight: .medium, design: .monospaced))
            .kerning(1.5).foregroundStyle(palette.ink.materialColor.opacity(0.35))
        context.draw(context.resolve(text), at: CGPoint(x: 234, y: 837), anchor: .center)
    }

    private static func noise(_ index: Int) -> Double {
        var bits = UInt64(truncatingIfNeeded: index) &+ 0x9E3779B97F4A7C15
        bits = (bits ^ (bits >> 30)) &* 0xBF58476D1CE4E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D049BB133111EB
        return Double((bits ^ (bits >> 31)) & 65535) / 65535
    }
}

extension OneTapeTransportMaterial.RGB {
    var materialColor: Color { Color(red: red, green: green, blue: blue) }
}
