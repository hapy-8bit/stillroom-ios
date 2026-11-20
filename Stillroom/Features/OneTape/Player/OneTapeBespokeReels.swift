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
                    Color(red: 0.16, green: 0.11, blue: 0.08),
                    Color(red: 0.27, green: 0.18, blue: 0.13),
                    Color(red: 0.22, green: 0.15, blue: 0.10),
                    Color(red: 0.12, green: 0.08, blue: 0.06)
                ]), center: center, startRadius: 12, endRadius: clamped))

            // Stationary specular flare on oxide tape surface + concentric winding grooves
            context.fill(outer, with: .conicGradient(
                Gradient(colors: [
                    .white.opacity(0.08), .clear, .black.opacity(0.22),
                    .white.opacity(0.07), .clear, .black.opacity(0.18), .white.opacity(0.08)
                ]), center: center, angle: .degrees(32)))

            for index in 1..<24 {
                let r = 14 + max(0, clamped - 14) * CGFloat(index) / 24
                let ring = OneTapeBespokeGeometry.circle(center: center, radius: r)
                context.stroke(ring, with: .color(.black.opacity(index.isMultiple(of: 3) ? 0.22 : 0.07)),
                               lineWidth: 0.35)
            }
            context.stroke(outer, with: .color(.black.opacity(0.45)), lineWidth: 0.6)
        }
        .frame(width: clamped * 2, height: clamped * 2)
    }
}

/// Ivory-white 34-tooth mechanical flywheel with bright crimson phase indicator quadrant.
struct OneTapeArmatureSupplyWheel: View {
    var showsLegacyCollar = true

    var body: some View {
        Canvas { context, _ in
            let c = CGPoint(x: 34, y: 34)
            let outer = OneTapeBespokeGeometry.gear(center: c, outer: 30.8, root: 27.6, teeth: 34)
            context.fill(outer, with: .linearGradient(
                Gradient(colors: [Color(white: 0.96), Color(white: 0.85), Color(white: 0.92)]),
                startPoint: .zero, endPoint: CGPoint(x: 68, y: 68)))
            context.stroke(outer, with: .color(.black.opacity(0.45)), lineWidth: 0.45)

            // Recessed spokes + hub cutout
            let innerRim = OneTapeBespokeGeometry.circle(center: c, radius: 22.8)
            context.stroke(innerRim, with: .color(.black.opacity(0.24)), lineWidth: 0.7)

            // Bold red mechanical phase arc block
            let indicator = OneTapeBespokeGeometry.annularSector(center: c, inner: 17.5, outer: 23.2,
                                                                startDegrees: -52, endDegrees: 22)
            context.fill(indicator, with: .color(Color(red: 0.88, green: 0.16, blue: 0.13)))

            var holes = Path()
            holes.addPath(OneTapeBespokeGeometry.circle(center: c, radius: showsLegacyCollar ? 13.5 : 12.8))
            for i in 0..<8 {
                let pt = OneTapeBespokeGeometry.point(center: c, radius: 18.8, angle: Double(i) * .pi / 4)
                holes.addPath(OneTapeBespokeGeometry.circle(center: pt, radius: 1.9))
            }
            context.blendMode = .destinationOut
            context.fill(holes, with: .color(.white))
            context.blendMode = .normal

            if showsLegacyCollar {
                drawCenterCollar(in: &context, center: c, radius: 13.8,
                                 toothColor: Color(white: 0.90),
                                 isCustomTinted: false)
            }
        }
        .frame(width: 68, height: 68)
        .shadow(color: .black.opacity(0.42), radius: 1.8, y: 1.2)
        .drawingGroup()
    }
}

/// Compact dark anodized 10-hole perforated rotor for Armature right spool.
struct OneTapeArmatureTakeupWheel: View {
    var showsLegacyCollar = true

    var body: some View {
        Canvas { context, _ in
            let c = CGPoint(x: 27, y: 27)
            var disc = OneTapeBespokeGeometry.circle(center: c, radius: 24.5)
            disc.addPath(OneTapeBespokeGeometry.circle(center: c, radius: showsLegacyCollar ? 12.2 : 12.8))
            for i in 0..<10 {
                let pt = OneTapeBespokeGeometry.point(center: c, radius: 18.4, angle: Double(i) * .pi / 5)
                disc.addPath(OneTapeBespokeGeometry.circle(center: pt, radius: 2.3))
            }
            context.fill(disc, with: .linearGradient(
                Gradient(colors: [Color(white: 0.25), Color(white: 0.12), Color(white: 0.20)]),
                startPoint: .zero, endPoint: CGPoint(x: 54, y: 54)), style: FillStyle(eoFill: true))
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 24.3),
                           with: .color(.white.opacity(0.22)), lineWidth: 0.6)
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: showsLegacyCollar ? 13.6 : 14.1),
                           with: .color(.white.opacity(0.16)), lineWidth: 0.6)
            if showsLegacyCollar {
                drawCenterCollar(in: &context, center: c, radius: 12.2,
                                 toothColor: Color(white: 0.30),
                                 isCustomTinted: false)
            }
        }
        .frame(width: 54, height: 54)
        .shadow(color: .black.opacity(0.45), radius: 1.6, y: 1.1)
        .drawingGroup()
    }
}

/// Vintage 3-spoke cream-bakelite open-reel flange revealing dynamic tape coils behind spokes.
struct OneTapeFieldNotesHubWheel: View {
    var showsLegacyCollar = true

    var body: some View {
        Canvas { context, _ in
            let c = CGPoint(x: 30, y: 30)
            var flange = OneTapeBespokeGeometry.circle(center: c, radius: 28.2)
            flange.addPath(OneTapeBespokeGeometry.circle(center: c, radius: 10.6))
            for sector in 0..<3 {
                let start = Double(sector) * 120 - 38
                flange.addPath(OneTapeBespokeGeometry.annularSector(center: c, inner: 14.5, outer: 24.8,
                                                                   startDegrees: start, endDegrees: start + 76))
            }
            context.fill(flange, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.96, green: 0.92, blue: 0.81),
                    Color(red: 0.85, green: 0.79, blue: 0.68),
                    Color(red: 0.92, green: 0.87, blue: 0.76)
                ]), startPoint: .zero, endPoint: CGPoint(x: 60, y: 60)), style: FillStyle(eoFill: true))
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 28.0),
                           with: .color(.black.opacity(0.42)), lineWidth: 0.65)
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 13.0),
                           with: .color(Color(red: 0.62, green: 0.34, blue: 0.18).opacity(0.75)), lineWidth: 1.0)
            let pip = OneTapeBespokeGeometry.point(center: c, radius: 26.2, angle: -Double.pi / 2)
            context.fill(OneTapeBespokeGeometry.circle(center: pip, radius: 1.6),
                         with: .color(Color(red: 0.85, green: 0.28, blue: 0.14)))
            if showsLegacyCollar {
                drawCenterCollar(in: &context, center: c, radius: 10.6,
                                 toothColor: Color(red: 0.91, green: 0.86, blue: 0.74),
                                 isCustomTinted: false)
            }
        }
        .frame(width: 60, height: 60)
        .shadow(color: .black.opacity(0.38), radius: 1.4, y: 1.0)
        .drawingGroup()
    }
}

/// CNC-machined 6-vane anodized aluminum turbine wheel with center lock nut.
struct OneTapeSilverStudioWheel: View {
    let tabAngle: Double
    var showsLegacyCollar = true

    var body: some View {
        Canvas { context, _ in
            let c = CGPoint(x: 34, y: 34)
            var wheel = OneTapeBespokeGeometry.circle(center: c, radius: 30.8)
            wheel.addPath(OneTapeBespokeGeometry.circle(center: c, radius: 11.8))
            for i in 0..<6 {
                let start = Double(i) * 60 + 11
                wheel.addPath(OneTapeBespokeGeometry.annularSector(center: c, inner: 16.5, outer: 27.2,
                                                                  startDegrees: start, endDegrees: start + 38))
            }
            context.fill(wheel, with: .conicGradient(
                Gradient(colors: [
                    Color(white: 0.94), Color(white: 0.70), Color(white: 0.90),
                    Color(white: 0.68), Color(white: 0.92), Color(white: 0.72), Color(white: 0.94)
                ]), center: c, angle: .degrees(24)), style: FillStyle(eoFill: true))
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 30.5),
                           with: .color(.white.opacity(0.72)), lineWidth: 0.8)
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 28.4),
                           with: .color(.black.opacity(0.28)), lineWidth: 0.6)

            // Keep signature signal-orange accent for the default hardware look, and
            // shift to neutral anodized titanium when a custom reel gear color is chosen.
            let lockColor = showsLegacyCollar
                ? Color(red: 0.94, green: 0.36, blue: 0.10)
                : Color(white: 0.26)
            let pinColor = showsLegacyCollar
                ? Color(red: 0.94, green: 0.36, blue: 0.10)
                : Color(white: 0.36)
            let lockNut = OneTapeBespokeGeometry.annularSector(center: c, inner: 12.6, outer: 15.6,
                                                              startDegrees: 0, endDegrees: 360)
            context.fill(lockNut, with: .color(lockColor))
            for idx in 0..<3 {
                let angle = (tabAngle + Double(idx) * 120) * .pi / 180
                let pin = OneTapeBespokeGeometry.point(center: c, radius: 28.8, angle: angle)
                context.fill(OneTapeBespokeGeometry.circle(center: pin, radius: 1.5),
                             with: .color(pinColor))
            }
            if showsLegacyCollar {
                drawCenterCollar(in: &context, center: c, radius: 11.8,
                                 toothColor: Color(white: 0.84),
                                 isCustomTinted: false)
            }
        }
        .frame(width: 68, height: 68)
        .shadow(color: .black.opacity(0.45), radius: 2, y: 1.5)
        .drawingGroup()
    }
}

/// Lathe-turned spun-silver chronograph dial disc with red & black tachometer ticks.
struct OneTapeTwinArcDialWheel: View {
    var showsLegacyCollar = true

    var body: some View {
        Canvas { context, _ in
            let c = CGPoint(x: 34, y: 34)
            var dial = OneTapeBespokeGeometry.circle(center: c, radius: 31.2)
            dial.addPath(OneTapeBespokeGeometry.circle(center: c, radius: 12.2))
            context.fill(dial, with: .conicGradient(
                Gradient(colors: [
                    Color(white: 0.88), Color(white: 0.64), Color(white: 0.92),
                    Color(white: 0.60), Color(white: 0.86), Color(white: 0.64), Color(white: 0.88)
                ]), center: c, angle: .degrees(15)), style: FillStyle(eoFill: true))
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 30.8),
                           with: .color(.black.opacity(0.45)), lineWidth: 0.6)
            context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 20.5),
                           with: .color(.black.opacity(0.18)), lineWidth: 0.5)

            for i in 0..<24 {
                let angle = Double(i) * .pi / 12
                let isMajor = i.isMultiple(of: 2)
                var tick = Path()
                tick.move(to: OneTapeBespokeGeometry.point(center: c, radius: isMajor ? 21.8 : 25.2, angle: angle))
                tick.addLine(to: OneTapeBespokeGeometry.point(center: c, radius: 29.2, angle: angle))
                context.stroke(tick, with: .color(isMajor
                    ? Color(red: 0.78, green: 0.16, blue: 0.14)
                    : Color.black.opacity(0.35)), lineWidth: isMajor ? 1.15 : 0.6)
            }
            if showsLegacyCollar {
                drawCenterCollar(in: &context, center: c, radius: 12.2,
                                 toothColor: Color(white: 0.72),
                                 isCustomTinted: false)
            }
        }
        .frame(width: 68, height: 68)
        .shadow(color: .black.opacity(0.4), radius: 1.5, y: 1)
        .drawingGroup()
    }
}

private func drawCenterCollar(in context: inout GraphicsContext, center: CGPoint,
                              radius: CGFloat, toothColor: Color, isCustomTinted: Bool) {
    let rim = OneTapeBespokeGeometry.circle(center: center, radius: radius - 0.6)
    context.stroke(rim, with: .color(isCustomTinted ? toothColor.opacity(0.92) : .black.opacity(0.65)),
                   lineWidth: isCustomTinted ? 2.1 : 1.4)
    for i in 0..<6 {
        let a = Double(i) * .pi / 3
        let perp = a + .pi / 2
        let p0 = OneTapeBespokeGeometry.point(center: center, radius: radius - 0.6, angle: a)
        let p1 = OneTapeBespokeGeometry.point(center: center, radius: radius - 3.6, angle: a)
        let dx = cos(perp) * 1.35
        let dy = sin(perp) * 1.35
        let tooth = OneTapeBespokeGeometry.polygon([
            CGPoint(x: p0.x - dx, y: p0.y - dy),
            CGPoint(x: p0.x + dx, y: p0.y + dy),
            CGPoint(x: p1.x + dx * 0.72, y: p1.y + dy * 0.72),
            CGPoint(x: p1.x - dx * 0.72, y: p1.y - dy * 0.72)
        ])
        context.fill(tooth, with: .color(toothColor))
    }
}
