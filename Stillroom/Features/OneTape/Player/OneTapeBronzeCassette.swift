import SwiftUI

/// A native reconstruction of the small grey-bronze wedge-window thumbnail.
/// Its full-size material and original motion have not been visually accepted.
/// Angles and queue progress come from the player's existing authoritative state.
struct OneTapeBronzeCassette: View {
    var supplyAngle: Angle = .zero
    var takeupAngle: Angle = .zero
    var tapeProgress: Double = 0
    var reelExposureDegrees: Double = 0
    var reelColor: OneTapeAppearance.ReelColor? = nil

    var body: some View {
        let radii = OneTapeTapeGeometry.radii(progress: tapeProgress)
        ZStack(alignment: .topLeading) {
            shell
            pressedPanel
            lowerEmbossing
            windowWell
            ZStack(alignment: .topLeading) {
                OneTapeBronzeTapePack(radius: CGFloat(radii.supply) / BronzeGeometry.scale)
                    .modifier(OneTapeReelExposure(angle: supplyAngle, spread: reelExposureDegrees))
                    .position(BronzeGeometry.supply)
                OneTapeBronzeTapePack(radius: CGFloat(radii.takeup) / BronzeGeometry.scale)
                    .modifier(OneTapeReelExposure(angle: takeupAngle, spread: reelExposureDegrees))
                    .position(BronzeGeometry.takeup)
            }
            .frame(width: 288, height: 195)
            .mask { BronzeGeometry.wedge.fill(.white) }
            windowLip
            OneTapeBronzeDial(showsLegacyHub: reelColor == nil)
                .modifier(OneTapeReelExposure(angle: supplyAngle, spread: reelExposureDegrees))
                .position(BronzeGeometry.supply)
            mountedGear(at: BronzeGeometry.supply, angle: supplyAngle)
            rightSocket
            OneTapeBronzeSmallGear(showsLegacyHub: reelColor == nil)
                .modifier(OneTapeReelExposure(angle: takeupAngle, spread: reelExposureDegrees))
                .position(BronzeGeometry.takeup)
            mountedGear(at: BronzeGeometry.takeup, angle: takeupAngle)
            fasteners
        }
        .frame(width: 288, height: 195)
        // Source coordinates are logical design units, not asset pixels. One
        // transform is shared with the print mask so holes cannot drift apart.
        .scaleEffect(x: BronzeGeometry.drawingScale.width, y: BronzeGeometry.drawingScale.height)
        .rotationEffect(.degrees(90))
        .position(BronzeGeometry.canvasCenter)
        .frame(width: 376.33, height: 576)
        .mask { BronzeGeometry.shell.applying(BronzeGeometry.portraitTransform).fill(.white) }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func mountedGear(at center: CGPoint, angle: Angle) -> some View {
        if let reelColor {
            OneTapeReelGearView(
                color: reelColor,
                diameter: BronzeGeometry.gearDiameter,
                angle: angle,
                reelExposureDegrees: reelExposureDegrees,
                showsOuterBezel: true,
                showsAxlePin: true,
                gearOuterRadiusFraction: 0.84
            )
            .position(center)
        }
    }

    private var shell: some View {
        Canvas { context, _ in
            context.fill(BronzeGeometry.shell, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.73, green: 0.71, blue: 0.65), location: 0),
                    .init(color: Color(red: 0.65, green: 0.63, blue: 0.57), location: 0.42),
                    .init(color: Color(red: 0.71, green: 0.70, blue: 0.64), location: 1)
                ]), startPoint: CGPoint(x: 23, y: 20), endPoint: CGPoint(x: 256, y: 180)))
            context.stroke(BronzeGeometry.shell, with: .color(Color(white: 0.075)), lineWidth: 1.3)
            let bevel = Path(roundedRect: BronzeGeometry.shellFrame.insetBy(dx: 1.2, dy: 1.2),
                             cornerRadius: 9.8)
            context.stroke(bevel, with: .linearGradient(
                Gradient(colors: [Color(white: 0.90), Color(white: 0.25), Color(white: 0.72)]),
                startPoint: CGPoint(x: 15, y: 17), endPoint: CGPoint(x: 275, y: 182)), lineWidth: 0.7)
            var brushed = context
            brushed.clip(to: bevel)
            // Fixed low-contrast hairlines describe machining, without adding
            // noise that changes between frames or a second animation clock.
            for row in 0..<275 {
                let y = 17.5 + CGFloat(row) * 0.59
                let opacity = 0.015 + (sin(Double(row) * 1.73) + 1) * 0.006
                var hairline = Path()
                hairline.move(to: CGPoint(x: 14, y: y))
                hairline.addLine(to: CGPoint(x: 274, y: y + 0.12))
                brushed.stroke(hairline,
                    with: .color(row.isMultiple(of: 3) ? .black.opacity(opacity) : .white.opacity(opacity)),
                    lineWidth: 0.18)
            }
        }
        .frame(width: 288, height: 195)
        .shadow(color: .black.opacity(0.50), radius: 1, y: 0.8)
    }

    private var pressedPanel: some View {
        RoundedRectangle(cornerRadius: 2.7)
            .fill(LinearGradient(colors: [.white.opacity(0.018), .black.opacity(0.018)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                RoundedRectangle(cornerRadius: 2.7)
                    .stroke(.black.opacity(0.095), lineWidth: 0.55)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(.white.opacity(0.07)).frame(height: 0.4).padding(.horizontal, 3)
            }
            .frame(width: 83, height: 96)
            .position(x: 222.5, y: 89)
    }

    private var lowerEmbossing: some View {
        Canvas { context, _ in
            context.fill(BronzeGeometry.lowerPlate, with: .linearGradient(
                Gradient(colors: [.black.opacity(0.12), .white.opacity(0.025), .black.opacity(0.04)]),
                startPoint: CGPoint(x: 144, y: 139), endPoint: CGPoint(x: 144, y: 181)))
            context.stroke(BronzeGeometry.lowerPlate, with: .color(.black.opacity(0.14)), lineWidth: 0.8)
            let inner = BronzeGeometry.polygon([
                CGPoint(x: 70.5, y: 143), CGPoint(x: 216.7, y: 143),
                CGPoint(x: 225.7, y: 177), CGPoint(x: 61.6, y: 177)
            ])
            context.stroke(inner, with: .color(.white.opacity(0.16)), lineWidth: 0.85)
            var lip = Path()
            lip.move(to: CGPoint(x: 58, y: 179))
            lip.addLine(to: CGPoint(x: 69, y: 140))
            lip.addLine(to: CGPoint(x: 218, y: 140))
            context.stroke(lip, with: .color(.white.opacity(0.16)), lineWidth: 1.1)
        }
        .frame(width: 288, height: 195)
    }

    private var windowWell: some View {
        Canvas { context, _ in
            context.fill(BronzeGeometry.wedge, with: .linearGradient(
                Gradient(colors: [Color(red: 0.28, green: 0.27, blue: 0.23),
                                  Color(red: 0.40, green: 0.39, blue: 0.34),
                                  Color(red: 0.30, green: 0.29, blue: 0.25)]),
                startPoint: CGPoint(x: 26, y: 90), endPoint: CGPoint(x: 175, y: 94)))
            var inside = context
            inside.clip(to: BronzeGeometry.wedge)
            for index in 0..<26 {
                let x = 29 + CGFloat(index) * 5.7
                var shadow = Path()
                shadow.move(to: CGPoint(x: x, y: 36))
                shadow.addLine(to: CGPoint(x: x, y: 141))
                inside.stroke(shadow, with: .color(.black.opacity(0.08)), lineWidth: 0.85)
                inside.stroke(shadow.offsetBy(dx: 0.9, dy: 0),
                              with: .color(.white.opacity(0.09)), lineWidth: 0.45)
            }
            inside.stroke(BronzeGeometry.wedge, with: .color(.black.opacity(0.32)), lineWidth: 3.6)
        }
        .frame(width: 288, height: 195)
    }

    private var windowLip: some View {
        BronzeGeometry.wedge
            .stroke(LinearGradient(colors: [.black.opacity(0.42), .white.opacity(0.28)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
            .frame(width: 288, height: 195)
    }

    private var rightSocket: some View {
        Circle()
            .fill(Color(red: 0.42, green: 0.40, blue: 0.35))
            .overlay { Circle().stroke(.white.opacity(0.32), lineWidth: 0.65) }
            .shadow(color: .black.opacity(0.24), radius: 0.7, y: 0.5)
            .frame(width: 29.5, height: 29.5)
            .position(BronzeGeometry.takeup)
    }

    private var fasteners: some View {
        ZStack(alignment: .topLeading) {
            ForEach(BronzeGeometry.screws.indices, id: \.self) { index in
                OneTapeBronzeScrew()
                    .position(BronzeGeometry.screws[index])
            }
            ForEach(BronzeGeometry.bottomHoles.indices, id: \.self) { index in
                Circle()
                    .fill(Color(white: 0.04))
                    .overlay { Circle().stroke(.white.opacity(0.24), lineWidth: 0.6) }
                    .overlay { Circle().stroke(.black.opacity(0.35), lineWidth: 0.45).padding(-0.8) }
                    .frame(width: 9.0, height: 9.0)
                    .position(BronzeGeometry.bottomHoles[index])
            }
            ForEach(BronzeGeometry.bottomSlots.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.3)
                    .fill(Color(white: 0.035))
                    .overlay {
                        RoundedRectangle(cornerRadius: 1.3)
                            .stroke(.white.opacity(0.24), lineWidth: 0.55)
                    }
                    .frame(width: 8.2, height: 6.0)
                    .position(BronzeGeometry.bottomSlots[index])
            }
        }
        .frame(width: 288, height: 195)
    }
}

/// The ordinary fill is already a difference shape. Callers need no even-odd
/// fill flag, and the same source-to-portrait transform is used by the material.
struct OneTapeBronzePrintMask: Shape {
    func path(in rect: CGRect) -> Path {
        var printable = BronzeGeometry.shell
            .subtracting(BronzeGeometry.wedge, eoFill: false)
            .subtracting(BronzeGeometry.circle(center: BronzeGeometry.takeup, radius: 15.6), eoFill: false)
        for center in BronzeGeometry.screws {
            printable = printable.subtracting(BronzeGeometry.circle(center: center, radius: 5.7), eoFill: false)
        }
        for center in BronzeGeometry.bottomHoles {
            printable = printable.subtracting(BronzeGeometry.circle(center: center, radius: 6), eoFill: false)
        }
        for center in BronzeGeometry.bottomSlots {
            let slot = Path(roundedRect: CGRect(x: center.x - 5.2, y: center.y - 4.2,
                                               width: 10.4, height: 8.4), cornerRadius: 1.8)
            printable = printable.subtracting(slot, eoFill: false)
        }
        let fit = CGAffineTransform(a: rect.width / 376.33, b: 0, c: 0, d: rect.height / 576,
                                    tx: rect.minX, ty: rect.minY)
        return printable.applying(BronzeGeometry.portraitTransform.concatenating(fit))
    }
}

private struct OneTapeBronzeTapePack: View {
    let radius: CGFloat

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let circle = BronzeGeometry.circle(center: center, radius: radius)
            context.fill(circle, with: .radialGradient(
                Gradient(colors: [Color(red: 0.24, green: 0.22, blue: 0.18),
                                  Color(red: 0.33, green: 0.30, blue: 0.25),
                                  Color(red: 0.23, green: 0.21, blue: 0.17)]),
                center: center, startRadius: 9, endRadius: radius))
            for index in 1..<22 {
                let ringRadius = 13 + max(0, radius - 13) * CGFloat(index) / 22
                context.stroke(BronzeGeometry.circle(center: center, radius: ringRadius),
                               with: .color(.black.opacity(index.isMultiple(of: 3) ? 0.11 : 0.045)),
                               lineWidth: 0.35)
            }
            context.stroke(circle, with: .color(.black.opacity(0.24)), lineWidth: 0.6)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

/// Restrained satin champagne-bronze machined disc replacing the old white/red dial.
private struct OneTapeBronzeDial: View {
    var showsLegacyHub = true

    var body: some View {
        Canvas { context, _ in
            let center = CGPoint(x: 29, y: 29)
            let face = BronzeGeometry.circle(center: center, radius: 28.0)
            context.fill(face, with: .conicGradient(
                Gradient(colors: [
                    Color(red: 0.80, green: 0.78, blue: 0.72),
                    Color(red: 0.64, green: 0.62, blue: 0.56),
                    Color(red: 0.82, green: 0.80, blue: 0.74),
                    Color(red: 0.62, green: 0.60, blue: 0.54),
                    Color(red: 0.80, green: 0.78, blue: 0.72)
                ]), center: center, angle: .degrees(24)))
            context.stroke(face, with: .color(.black.opacity(0.26)), lineWidth: 0.65)
            context.stroke(BronzeGeometry.circle(center: center, radius: 19.8),
                           with: .color(.black.opacity(0.14)), lineWidth: 0.5)
            for index in 0..<6 {
                let angle = Double(index) * .pi / 3
                var tick = Path()
                tick.move(to: BronzeGeometry.point(center: center, radius: 22.0, angle: angle))
                tick.addLine(to: BronzeGeometry.point(center: center, radius: 26.0, angle: angle))
                context.stroke(tick, with: .color(Color(white: 0.24).opacity(0.55)), lineWidth: 0.85)
            }
            if showsLegacyHub {
                let hub = BronzeGeometry.gear(center: center, outer: 11.2, root: 9.4, teeth: 12)
                context.fill(hub, with: .color(Color(white: 0.10)))
                context.stroke(hub, with: .color(.white.opacity(0.32)), lineWidth: 0.45)
                context.fill(BronzeGeometry.circle(center: center, radius: 6.8),
                             with: .color(Color(white: 0.05)))
                context.stroke(BronzeGeometry.circle(center: center, radius: 7.7),
                               with: .color(.white.opacity(0.14)), lineWidth: 0.55)
            }
        }
        .frame(width: 58, height: 58)
        .shadow(color: .black.opacity(0.30), radius: 1.4, x: -0.4, y: 0.9)
        .drawingGroup()
    }
}

private struct OneTapeBronzeSmallGear: View {
    var showsLegacyHub = true

    var body: some View {
        Canvas { context, _ in
            let center = CGPoint(x: 15, y: 15)
            let outerRadius: CGFloat = showsLegacyHub ? 13.2 : 14.4
            context.fill(BronzeGeometry.circle(center: center, radius: outerRadius),
                         with: .color(Color(red: 0.77, green: 0.75, blue: 0.69)))
            context.stroke(BronzeGeometry.circle(center: center, radius: outerRadius - 0.5),
                           with: .color(.black.opacity(0.24)), lineWidth: 0.5)
            if showsLegacyHub {
                let teeth = BronzeGeometry.gear(center: center, outer: 10.8, root: 8.7, teeth: 12)
                context.fill(teeth, with: .color(Color(white: 0.08)))
                context.stroke(teeth, with: .color(.white.opacity(0.22)), lineWidth: 0.35)
                context.stroke(BronzeGeometry.circle(center: center, radius: 6.4),
                               with: .color(.white.opacity(0.14)), lineWidth: 0.6)
            }
        }
        .frame(width: 30, height: 30)
        .drawingGroup()
    }
}

private struct OneTapeBronzeScrew: View {
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(white: 0.10), Color(white: 0.025), Color(white: 0.25)],
                                 center: .center, startRadius: 0.5, endRadius: 4.6))
            .overlay { Circle().stroke(.white.opacity(0.36), lineWidth: 0.6) }
            .overlay {
                Rectangle().fill(.white.opacity(0.16)).frame(width: 4.6, height: 0.6)
                    .rotationEffect(.degrees(-28))
            }
            .frame(width: 8.8, height: 8.8)
            .shadow(color: .black.opacity(0.20), radius: 0.4, y: 0.4)
    }
}

private enum BronzeGeometry {
    static let scale: CGFloat = 2.128
    static let gearDiameter: CGFloat = 25.8
    static let shellFrame = CGRect(x: 13, y: 15, width: 261, height: 166)
    static let supply = OneTapeCassetteStandard.landscape288Point(
        fromPortrait: OneTapeCassetteStandard.portraitSupplyCenter, via: portraitTransform)
    static let takeup = OneTapeCassetteStandard.landscape288Point(
        fromPortrait: OneTapeCassetteStandard.portraitTakeupCenter, via: portraitTransform)
    static let screws = [CGPoint(x: 29, y: 30), CGPoint(x: 259, y: 30),
                         CGPoint(x: 25, y: 170), CGPoint(x: 263, y: 170), CGPoint(x: 144, y: 149)]
    static let bottomHoles = [CGPoint(x: 82, y: 166), CGPoint(x: 206, y: 166)]
    static let bottomSlots = [CGPoint(x: 108, y: 162), CGPoint(x: 180, y: 162)]

    static var drawingScale: CGSize {
        let target = OneTapeCassettePocketMask.shellFrame
        return CGSize(width: target.height / shellFrame.width,
                      height: target.width / shellFrame.height)
    }

    // The visible shell, not the full source canvas, shares the classic bounds.
    // Reuse this registration for print exclusions so the wedge stays clear.
    static var portraitTransform: CGAffineTransform {
        let target = OneTapeCassettePocketMask.shellFrame
        return CGAffineTransform(a: 0, b: drawingScale.width, c: -drawingScale.height, d: 0,
            tx: target.maxX + shellFrame.minY * drawingScale.height,
            ty: target.minY - shellFrame.minX * drawingScale.width)
    }

    static var canvasCenter: CGPoint {
        CGPoint(x: 144, y: 97.5).applying(portraitTransform)
    }

    static var shell: Path { Path(roundedRect: shellFrame, cornerRadius: 11) }

    static var wedge: Path {
        var path = Path()
        path.move(to: CGPoint(x: 27, y: 40.5))
        path.addQuadCurve(to: CGPoint(x: 29.2, y: 39.7), control: CGPoint(x: 27, y: 38.8))
        path.addLine(to: CGPoint(x: 173.2, y: 89.7))
        path.addQuadCurve(to: CGPoint(x: 173.2, y: 92.3), control: CGPoint(x: 177, y: 91))
        path.addLine(to: CGPoint(x: 29.2, y: 139.0))
        path.addQuadCurve(to: CGPoint(x: 27, y: 137.5), control: CGPoint(x: 27, y: 140))
        path.closeSubpath()
        return path
    }

    static var lowerPlate: Path {
        polygon([CGPoint(x: 69, y: 140), CGPoint(x: 218, y: 140),
                 CGPoint(x: 230, y: 179), CGPoint(x: 58, y: 179)])
    }

    static func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    static func circle(center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                              width: radius * 2, height: radius * 2))
    }

    static func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    static func gear(center: CGPoint, outer: CGFloat, root: CGFloat, teeth: Int) -> Path {
        polygon((0..<(teeth * 4)).map { index in
            let toothEdge = index % 4
            let radius = toothEdge == 1 || toothEdge == 2 ? outer : root
            return point(center: center, radius: radius, angle: Double(index) * 2 * .pi / Double(teeth * 4))
        })
    }

    static func annularSector(center: CGPoint, inner: CGFloat, outer: CGFloat,
                              start: Double, end: Double) -> Path {
        let outside = (0...20).map { index in
            point(center: center, radius: outer, angle: (start + (end - start) * Double(index) / 20) * .pi / 180)
        }
        let inside = (0...20).reversed().map { index in
            point(center: center, radius: inner, angle: (start + (end - start) * Double(index) / 20) * .pi / 180)
        }
        return polygon(outside + inside)
    }
}
