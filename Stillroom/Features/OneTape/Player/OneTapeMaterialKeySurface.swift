import SwiftUI

/// Physical hardware circular key cap decoupled from decorative shell artwork.
/// Follows Cassette 1.0.5's hardware contrast strategy: signature bodies sit
/// beside grounded sculpted black, gunmetal titanium, or machined grey keys.
struct OneTapeMaterialKeySurface: View {
    let finish: OneTapeBodyKeyFinish
    let palette: OneTapeBodyMaterialPalette

    init(finish: OneTapeBodyKeyFinish, palette: OneTapeBodyMaterialPalette) {
        self.finish = finish
        self.palette = palette
    }

    init(material: OneTapeBodyMaterial, palette: OneTapeBodyMaterialPalette) {
        self.finish = material.keyFinish
        self.palette = palette
    }

    var body: some View {
        Canvas { context, _ in
            let rect = CGRect(x: 0, y: 0, width: 58, height: 58)
            switch finish {
            case .blackHardware:
                drawBlackHardwareKey(in: &context, rect: rect)
            case .graphiteHardware:
                drawGraphiteHardwareKey(in: &context, rect: rect)
            case .cleanPlateHardware:
                drawMachinedPlateKey(in: &context, rect: rect, base: palette.key)
            case .seeThroughHardware:
                drawSmokedMechanicalKey(in: &context, rect: rect)
            case .paintedHardware:
                drawMachinedPlateKey(in: &context, rect: rect, base: palette.key)
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(Circle())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Deep gloss-beveled satin-black physical key matching Cassette 1.0.5's
    /// HoloFoil, Circuit, GreyTracks, StealthCamo, Disco & Linen hardware keys.
    private func drawBlackHardwareKey(in context: inout GraphicsContext, rect: CGRect) {
        let outer = Path(ellipseIn: rect)
        let bezel = Path(ellipseIn: rect.insetBy(dx: 1.0, dy: 1.0))
        let dish = Path(ellipseIn: rect.insetBy(dx: 4.2, dy: 4.2))

        context.fill(outer, with: .color(Color(white: 0.04)))
        context.fill(
            bezel,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(white: 0.34), location: 0.0),
                    .init(color: Color(white: 0.13), location: 0.28),
                    .init(color: Color(white: 0.05), location: 0.68),
                    .init(color: Color(white: 0.22), location: 1.0)
                ]),
                startPoint: CGPoint(x: 7, y: 2),
                endPoint: CGPoint(x: 50, y: 56)
            )
        )
        // Subtle concave satin dish catching directional top-left studio bounce.
        context.fill(
            dish,
            with: .radialGradient(
                Gradient(colors: [
                    Color(white: 0.20),
                    Color(white: 0.125),
                    Color(white: 0.085)
                ]),
                center: CGPoint(x: 21, y: 15),
                startRadius: 2,
                endRadius: 44
            )
        )
        context.stroke(
            dish,
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.28), .clear, .black.opacity(0.45)]),
                startPoint: CGPoint(x: 8, y: 6),
                endPoint: CGPoint(x: 50, y: 52)
            ),
            lineWidth: 0.85
        )
        drawSpecularArcs(in: &context, topAlpha: 0.56, bottomAlpha: 0.18, width: 1.1)
    }

    /// Satin machined gunmetal-titanium key matching Cassette 1.0.5 `BodyGraphite`.
    private func drawGraphiteHardwareKey(in context: inout GraphicsContext, rect: CGRect) {
        let outer = Path(ellipseIn: rect)
        let rim = Path(ellipseIn: rect.insetBy(dx: 0.8, dy: 0.8))
        let cap = Path(ellipseIn: rect.insetBy(dx: 4.0, dy: 4.0))

        context.fill(outer, with: .color(Color(white: 0.09)))
        context.fill(
            rim,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.66, green: 0.68, blue: 0.69), location: 0.0),
                    .init(color: Color(red: 0.24, green: 0.25, blue: 0.26), location: 0.36),
                    .init(color: Color(red: 0.14, green: 0.15, blue: 0.16), location: 0.72),
                    .init(color: Color(red: 0.50, green: 0.52, blue: 0.53), location: 1.0)
                ]),
                startPoint: CGPoint(x: 6, y: 2),
                endPoint: CGPoint(x: 51, y: 56)
            )
        )
        context.fill(
            cap,
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.28, green: 0.29, blue: 0.30),
                    Color(red: 0.20, green: 0.21, blue: 0.22),
                    Color(red: 0.14, green: 0.15, blue: 0.16)
                ]),
                center: CGPoint(x: 20, y: 14),
                startRadius: 2,
                endRadius: 46
            )
        )
        // Subtle horizontal CNC micro-brushing inside the gunmetal cap.
        var clipped = context
        clipped.clip(to: cap)
        for index in 0..<48 {
            let y = 4.0 + CGFloat(index) * 1.05
            var line = Path()
            line.move(to: CGPoint(x: 4, y: y))
            line.addLine(to: CGPoint(x: 54, y: y))
            clipped.stroke(
                line,
                with: .color((index % 2 == 0 ? Color.white : .black).opacity(0.032)),
                lineWidth: 0.3
            )
        }
        context.stroke(
            cap,
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.45), .clear, .black.opacity(0.36)]),
                startPoint: CGPoint(x: 8, y: 6),
                endPoint: CGPoint(x: 50, y: 52)
            ),
            lineWidth: 0.85
        )
        drawSpecularArcs(in: &context, topAlpha: 0.62, bottomAlpha: 0.24, width: 1.0)
    }

    private func drawMachinedPlateKey(
        in context: inout GraphicsContext,
        rect: CGRect,
        base: OneTapeTransportMaterial.RGB
    ) {
        let rim = Path(ellipseIn: rect.insetBy(dx: 0.8, dy: 0.8))
        let cap = Path(ellipseIn: rect.insetBy(dx: 3.8, dy: 3.8))
        context.fill(
            rim,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: base.mixed(with: .init(1, 1, 1), fraction: 0.38).materialColor, location: 0),
                    .init(color: base.mixed(with: .init(0, 0, 0), fraction: 0.42).materialColor, location: 0.45),
                    .init(color: base.mixed(with: .init(1, 1, 1), fraction: 0.24).materialColor, location: 1)
                ]),
                startPoint: CGPoint(x: 6, y: 2),
                endPoint: CGPoint(x: 50, y: 56)
            )
        )
        context.fill(
            cap,
            with: .radialGradient(
                Gradient(colors: [
                    base.mixed(with: .init(1, 1, 1), fraction: 0.10).materialColor,
                    base.materialColor,
                    base.mixed(with: .init(0, 0, 0), fraction: 0.14).materialColor
                ]),
                center: CGPoint(x: 20, y: 14),
                startRadius: 2,
                endRadius: 46
            )
        )
        drawSpecularArcs(in: &context, topAlpha: 0.40, bottomAlpha: 0.16, width: 0.85)
    }

    private func drawSmokedMechanicalKey(in context: inout GraphicsContext, rect: CGRect) {
        let outer = Path(ellipseIn: rect)
        let bezel = Path(ellipseIn: rect.insetBy(dx: 0.9, dy: 0.9))
        let lens = Path(ellipseIn: rect.insetBy(dx: 3.8, dy: 3.8))

        // Translucent frosted-acrylic rim ring around the dark keycap cavity.
        context.fill(outer, with: .color(Color(white: 0.05)))
        context.fill(
            bezel,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.66, green: 0.70, blue: 0.74), location: 0.0),
                    .init(color: Color(white: 0.22), location: 0.30),
                    .init(color: Color(white: 0.08), location: 0.72),
                    .init(color: Color(red: 0.44, green: 0.48, blue: 0.52), location: 1.0)
                ]),
                startPoint: CGPoint(x: 6, y: 2),
                endPoint: CGPoint(x: 52, y: 56)
            )
        )

        // Semi-translucent smoked charcoal cavity letting internal switch hardware show through.
        context.fill(
            lens,
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.22, green: 0.24, blue: 0.26),
                    Color(red: 0.13, green: 0.145, blue: 0.16),
                    Color(red: 0.075, green: 0.085, blue: 0.095)
                ]),
                center: CGPoint(x: 24, y: 20),
                startRadius: 2,
                endRadius: 34
            )
        )

        // Internal brushed metallic spring collar visible beneath the smoked polycarbonate cap.
        let springRing = Path(ellipseIn: rect.insetBy(dx: 10.2, dy: 10.2))
        context.stroke(springRing, with: .color(Color(white: 0.78).opacity(0.22)),
                       style: StrokeStyle(lineWidth: 2.0, dash: [3.2, 2.2]))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 8.2, dy: 8.2)),
                       with: .color(.white.opacity(0.14)), lineWidth: 0.8)

        // Twin tiny warm-brass tactile leaf contacts peeking inside left/right of the stem.
        let leftTab = Path(roundedRect: CGRect(x: 11.5, y: 26.8, width: 6.0, height: 4.4), cornerRadius: 1.2)
        let rightTab = Path(roundedRect: CGRect(x: 40.5, y: 26.8, width: 6.0, height: 4.4), cornerRadius: 1.2)
        context.fill(leftTab, with: .color(Color(red: 0.82, green: 0.66, blue: 0.32).opacity(0.32)))
        context.fill(rightTab, with: .color(Color(red: 0.82, green: 0.66, blue: 0.32).opacity(0.32)))

        // Subtle milky-silver central switch plunger cross visible behind the smoked dome.
        let stemV = Path(roundedRect: CGRect(x: 26.5, y: 15.5, width: 5.0, height: 27.0), cornerRadius: 1.5)
        let stemH = Path(roundedRect: CGRect(x: 15.5, y: 26.5, width: 27.0, height: 5.0), cornerRadius: 1.5)
        context.fill(stemV, with: .color(.white.opacity(0.085)))
        context.fill(stemH, with: .color(.white.opacity(0.085)))

        // Glossy curved polycarbonate dome reflection on top.
        context.stroke(
            lens,
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.54), .clear, .black.opacity(0.42)]),
                startPoint: CGPoint(x: 8, y: 5),
                endPoint: CGPoint(x: 50, y: 53)
            ),
            lineWidth: 1.0
        )
        drawSpecularArcs(in: &context, topAlpha: 0.76, bottomAlpha: 0.30, width: 1.25)
    }

    private func drawSpecularArcs(
        in context: inout GraphicsContext,
        topAlpha: Double,
        bottomAlpha: Double,
        width: CGFloat
    ) {
        var glare = Path()
        glare.addArc(center: CGPoint(x: 29, y: 29), radius: 26.2,
                     startAngle: .degrees(194), endAngle: .degrees(274), clockwise: false)
        context.stroke(glare, with: .color(.white.opacity(topAlpha)),
                       style: StrokeStyle(lineWidth: width, lineCap: .round))

        var returnLight = Path()
        returnLight.addArc(center: CGPoint(x: 29, y: 29), radius: 25.8,
                           startAngle: .degrees(10), endAngle: .degrees(70), clockwise: false)
        context.stroke(returnLight, with: .color(.white.opacity(bottomAlpha)),
                       style: StrokeStyle(lineWidth: 0.75, lineCap: .round))
    }
}
