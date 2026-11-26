import SwiftUI

/// Magnetic oxide tape pack calibrated inside `OneTapeBespokeGeometry` (288×195 landscape).
struct OneTapeBespokeTapePack: View {
    let radius: CGFloat

    var body: some View {
        let clamped = max(16, radius)
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = Path(ellipseIn: CGRect(x: center.x - clamped, y: center.y - clamped,
                                              width: clamped * 2, height: clamped * 2))
            context.fill(outer, with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.14, green: 0.10, blue: 0.08),
                    Color(red: 0.23, green: 0.16, blue: 0.12),
                    Color(red: 0.19, green: 0.13, blue: 0.10),
                    Color(red: 0.11, green: 0.08, blue: 0.06)
                ]), center: center, startRadius: 12, endRadius: clamped))

            context.fill(outer, with: .conicGradient(
                Gradient(colors: [
                    .white.opacity(0.06), .clear, .black.opacity(0.18),
                    .white.opacity(0.05), .clear, .black.opacity(0.16), .white.opacity(0.06)
                ]), center: center, angle: .degrees(28)))

            for index in 1..<22 {
                let r = 14 + max(0, clamped - 14) * CGFloat(index) / 22
                let ring = OneTapeBespokeGeometry.circle(center: center, radius: r)
                context.stroke(ring, with: .color(.black.opacity(index.isMultiple(of: 3) ? 0.16 : 0.05)),
                               lineWidth: 0.32)
            }
            context.stroke(outer, with: .color(.black.opacity(0.38)), lineWidth: 0.55)
        }
        .frame(width: clamped * 2, height: clamped * 2)
    }
}

/// Restrained dark-titanium 3-slot precision reel for 烟灰 (`.armature`).
struct OneTapeArmatureSupplyWheel: View {
    var showsLegacyCollar = true

    var body: some View {
        minimalistDarkRotor(showsLegacyCollar: showsLegacyCollar)
    }
}

/// Matching symmetric dark-titanium precision reel for 烟灰 (`.armature`) take-up axle.
struct OneTapeArmatureTakeupWheel: View {
    var showsLegacyCollar = true

    var body: some View {
        minimalistDarkRotor(showsLegacyCollar: showsLegacyCollar)
    }
}

private func minimalistDarkRotor(showsLegacyCollar: Bool) -> some View {
    Canvas { context, _ in
        let c = CGPoint(x: 27, y: 27)
        var disc = OneTapeBespokeGeometry.circle(center: c, radius: 24.4)
        disc.addPath(OneTapeBespokeGeometry.circle(center: c, radius: 11.4))
        for i in 0..<3 {
            let start = Double(i) * 120 - 30
            disc.addPath(OneTapeBespokeGeometry.annularSector(
                center: c, inner: 14.6, outer: 21.2, startDegrees: start, endDegrees: start + 60
            ))
        }
        context.fill(
            disc,
            with: .conicGradient(
                Gradient(colors: [
                    Color(white: 0.34), Color(white: 0.22), Color(white: 0.32),
                    Color(white: 0.20), Color(white: 0.34)
                ]), center: c, angle: .degrees(20)),
            style: FillStyle(eoFill: true)
        )
        context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 24.2),
                       with: .color(.white.opacity(0.20)), lineWidth: 0.6)
        context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 13.2),
                       with: .color(.white.opacity(0.14)), lineWidth: 0.55)
        // Single subtle matte alignment notch to make rotation effortlessly readable.
        let dot = OneTapeBespokeGeometry.point(center: c, radius: 22.4, angle: -Double.pi / 2)
        context.fill(OneTapeBespokeGeometry.circle(center: dot, radius: 1.2),
                     with: .color(.white.opacity(0.45)))
        if showsLegacyCollar {
            drawCenterCollar(in: &context, center: c, radius: 11.4,
                             toothColor: Color(white: 0.72), isCustomTinted: false)
        }
    }
    .frame(width: 54, height: 54)
    .shadow(color: .black.opacity(0.38), radius: 1.5, y: 0.9)
    .drawingGroup()
}

/// Quiet warm-ivory 3-spoke open-reel flange for 纸纹 (`.fieldNotes`).
struct OneTapeFieldNotesHubWheel: View {
    var showsLegacyCollar = true

    var body: some View {
        Canvas { context, _ in
            let c = CGPoint(x: 28, y: 28)
            var flange = OneTapeBespokeGeometry.circle(center: c, radius: 25.8)
            flange.addPath(OneTapeBespokeGeometry.circle(center: c, radius: 10.6))
            for sector in 0..<3 {
                let start = Double(sector) * 120 - 36
                flange.addPath(OneTapeBespokeGeometry.annularSector(
                    center: c, inner: 14.2, outer: 22.8, startDegrees: start, endDegrees: start + 72
                ))
            }
            context.fill(flange, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.94, green: 0.92, blue: 0.87),
                    Color(red: 0.86, green: 0.84, blue: 0.79),
                    Color(red: 0.91, green: 0.89, blue: 0.84)
                ]), startPoint: .zero, endPoint: CGPoint(x: 56, y: 56)), style: FillStyle(eoFill: true))
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 25.6),
                           with: .color(.black.opacity(0.24)), lineWidth: 0.55)
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 13.0),
                           with: .color(.black.opacity(0.16)), lineWidth: 0.6)
            if showsLegacyCollar {
                drawCenterCollar(in: &context, center: c, radius: 10.6,
                                 toothColor: Color(red: 0.88, green: 0.86, blue: 0.81),
                                 isCustomTinted: false)
            }
        }
        .frame(width: 56, height: 56)
        .shadow(color: .black.opacity(0.26), radius: 1.2, y: 0.8)
        .drawingGroup()
    }
}

/// Pure brushed anodized aluminum 6-slot wheel for 原铝 (`.silverOval`), zero loud color accents.
struct OneTapeSilverStudioWheel: View {
    let tabAngle: Double
    var showsLegacyCollar = true

    var body: some View {
        Canvas { context, _ in
            let c = CGPoint(x: 28, y: 28)
            var wheel = OneTapeBespokeGeometry.circle(center: c, radius: 24.8)
            wheel.addPath(OneTapeBespokeGeometry.circle(center: c, radius: 11.2))
            for i in 0..<6 {
                let start = Double(i) * 60 + 13
                wheel.addPath(OneTapeBespokeGeometry.annularSector(
                    center: c, inner: 14.8, outer: 22.0, startDegrees: start, endDegrees: start + 34
                ))
            }
            context.fill(wheel, with: .conicGradient(
                Gradient(colors: [
                    Color(white: 0.94), Color(white: 0.76), Color(white: 0.90),
                    Color(white: 0.72), Color(white: 0.92), Color(white: 0.78), Color(white: 0.94)
                ]), center: c, angle: .degrees(24)), style: FillStyle(eoFill: true))
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 24.6),
                           with: .color(.white.opacity(0.75)), lineWidth: 0.6)
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 23.2),
                           with: .color(.black.opacity(0.18)), lineWidth: 0.45)

            let lockRing = OneTapeBespokeGeometry.annularSector(
                center: c, inner: 11.8, outer: 13.7, startDegrees: 0, endDegrees: 360
            )
            context.fill(lockRing, with: .color(Color(white: 0.34)))
            for idx in 0..<3 {
                let angle = (tabAngle + Double(idx) * 120) * .pi / 180
                let pin = OneTapeBespokeGeometry.point(center: c, radius: 23.3, angle: angle)
                context.fill(OneTapeBespokeGeometry.circle(center: pin, radius: 1.1),
                             with: .color(Color(white: 0.38)))
            }
            if showsLegacyCollar {
                drawCenterCollar(in: &context, center: c, radius: 11.2,
                                 toothColor: Color(white: 0.84),
                                 isCustomTinted: false)
            }
        }
        .frame(width: 56, height: 56)
        .shadow(color: .black.opacity(0.32), radius: 1.4, y: 0.9)
        .drawingGroup()
    }
}

/// Calm satin-pewter machined disc with six understated radial balance marks for 雾蓝 (`.twinArc`).
struct OneTapeTwinArcDialWheel: View {
    var showsLegacyCollar = true

    var body: some View {
        Canvas { context, _ in
            let c = CGPoint(x: 32, y: 32)
            var dial = OneTapeBespokeGeometry.circle(center: c, radius: 29.4)
            dial.addPath(OneTapeBespokeGeometry.circle(center: c, radius: 12.0))
            context.fill(dial, with: .conicGradient(
                Gradient(colors: [
                    Color(red: 0.78, green: 0.81, blue: 0.84),
                    Color(red: 0.62, green: 0.66, blue: 0.70),
                    Color(red: 0.82, green: 0.85, blue: 0.88),
                    Color(red: 0.60, green: 0.64, blue: 0.68),
                    Color(red: 0.78, green: 0.81, blue: 0.84)
                ]), center: c, angle: .degrees(18)), style: FillStyle(eoFill: true))
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 29.1),
                           with: .color(.white.opacity(0.45)), lineWidth: 0.55)
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 18.6),
                           with: .color(.black.opacity(0.16)), lineWidth: 0.5)

            for i in 0..<6 {
                let angle = Double(i) * .pi / 3
                var tick = Path()
                tick.move(to: OneTapeBespokeGeometry.point(center: c, radius: 21.0, angle: angle))
                tick.addLine(to: OneTapeBespokeGeometry.point(center: c, radius: 26.8, angle: angle))
                context.stroke(tick, with: .color(.black.opacity(0.28)), lineWidth: 0.8)
            }
            if showsLegacyCollar {
                drawCenterCollar(in: &context, center: c, radius: 12.0,
                                 toothColor: Color(red: 0.76, green: 0.79, blue: 0.82),
                                 isCustomTinted: false)
            }
        }
        .frame(width: 64, height: 64)
        .shadow(color: .black.opacity(0.32), radius: 1.4, y: 0.9)
        .drawingGroup()
    }
}

private func drawCenterCollar(in context: inout GraphicsContext, center: CGPoint,
                              radius: CGFloat, toothColor: Color, isCustomTinted: Bool) {
    let rim = OneTapeBespokeGeometry.circle(center: center, radius: radius - 0.6)
    context.stroke(rim, with: .color(isCustomTinted ? toothColor.opacity(0.92) : .black.opacity(0.55)),
                   lineWidth: isCustomTinted ? 2.1 : 1.25)
    for i in 0..<6 {
        let a = Double(i) * .pi / 3
        let perp = a + .pi / 2
        let p0 = OneTapeBespokeGeometry.point(center: center, radius: radius - 0.6, angle: a)
        let p1 = OneTapeBespokeGeometry.point(center: center, radius: radius - 3.6, angle: a)
        let dx = cos(perp) * 1.3
        let dy = sin(perp) * 1.3
        let tooth = OneTapeBespokeGeometry.polygon([
            CGPoint(x: p0.x - dx, y: p0.y - dy),
            CGPoint(x: p0.x + dx, y: p0.y + dy),
            CGPoint(x: p1.x + dx * 0.72, y: p1.y + dy * 0.72),
            CGPoint(x: p1.x - dx * 0.72, y: p1.y - dy * 0.72)
        ])
        context.fill(tooth, with: .color(toothColor))
    }
}
