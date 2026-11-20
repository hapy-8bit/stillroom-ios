import SwiftUI

/// Renders the customizable 6-tooth rotating internal gear collar, 3-lug inner drum,
/// dark recessed well, and optional outer bezel & stationary brushed-steel axle pin.
struct OneTapeReelGearView: View {
    let color: OneTapeAppearance.ReelColor
    let diameter: CGFloat
    var angle: Angle = .zero
    var reelExposureDegrees: Double = 0
    var showsOuterBezel: Bool = true
    var showsAxlePin: Bool = true
    /// Relative radius of the colored gear collar's outer edge inside `diameter * 0.5`.
    var gearOuterRadiusFraction: CGFloat = 0.785

    var body: some View {
        let radius = diameter * 0.5
        ZStack {
            if showsOuterBezel {
                outerBezel(radius: radius)
                    .drawingGroup()
            }

            rotatingWheel(radius: radius)
                .drawingGroup()
                .modifier(OneTapeReelExposure(angle: angle, spread: reelExposureDegrees))

            if showsAxlePin {
                axlePin(radius: radius)
                    .drawingGroup()
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }

    private func outerBezel(radius: CGFloat) -> some View {
        let outerSize = radius * 2
        let innerRadius = radius * gearOuterRadiusFraction
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.225, green: 0.238, blue: 0.295),
                            Color(red: 0.165, green: 0.174, blue: 0.222),
                            Color(red: 0.128, green: 0.135, blue: 0.178)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: outerSize, height: outerSize)

            // Crisp chamfered inner lip framing the rotating colored gear collar.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.34, green: 0.36, blue: 0.43),
                            Color(red: 0.20, green: 0.21, blue: 0.27)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    lineWidth: max(1.0, radius * 0.045)
                )
                .frame(width: innerRadius * 2 + radius * 0.05, height: innerRadius * 2 + radius * 0.05)

            Circle()
                .fill(Color(red: 0.025, green: 0.027, blue: 0.032))
                .frame(width: innerRadius * 2, height: innerRadius * 2)
        }
    }

    private func rotatingWheel(radius: CGFloat) -> some View {
        let outerR = radius * gearOuterRadiusFraction
        let ringInnerR = outerR * 0.815
        let toothTipR = outerR * 0.675
        let hubRadius = outerR * 0.630
        let lugOuterR = outerR * 0.805

        return Canvas { context, size in
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

            // Deep black trough beneath the rotating collar & teeth.
            let troughRect = CGRect(
                x: center.x - outerR,
                y: center.y - outerR,
                width: outerR * 2,
                height: outerR * 2
            )
            context.fill(Path(ellipseIn: troughRect), with: .color(Color(red: 0.022, green: 0.024, blue: 0.028)))

            // Colored outer gear ring + 6 inward trapezoidal teeth.
            let gearPath = internalGearPath(
                center: center,
                outerRadius: outerR,
                ringInnerRadius: ringInnerR,
                toothTipRadius: toothTipR,
                toothCount: 6,
                startAngleDegrees: 30
            )
            context.fill(
                gearPath,
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: color.swatchColor, location: 0.66),
                        .init(color: color.highlightColor, location: 0.82),
                        .init(color: color.swatchColor, location: 0.90),
                        .init(color: color.shadowColor, location: 1.0)
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: outerR
                ),
                style: FillStyle(eoFill: true)
            )

            // Inner matte charcoal drum + 3 alternating drive lugs aligned between pairs of teeth.
            let innerHubPath = driveDrumPath(
                center: center,
                coreRadius: hubRadius,
                lugOuterRadius: lugOuterR,
                lugCount: 3,
                startAngleDegrees: 60
            )
            context.fill(
                innerHubPath,
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(white: 0.165), location: 0.0),
                        .init(color: Color(white: 0.155), location: 0.62),
                        .init(color: Color(white: 0.110), location: 1.0)
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: lugOuterR
                )
            )
        }
        .frame(width: radius * 2, height: radius * 2)
    }

    private func axlePin(radius: CGFloat) -> some View {
        let pinDiameter = radius * 0.285
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.66),
                            Color(white: 0.56)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: pinDiameter, height: pinDiameter)
                .shadow(color: .black.opacity(0.70), radius: max(1.0, radius * 0.045), x: 0, y: max(0.6, radius * 0.025))

            Circle()
                .strokeBorder(.white.opacity(0.10), lineWidth: max(0.35, radius * 0.010))
                .frame(width: pinDiameter, height: pinDiameter)
        }
    }

    private func internalGearPath(
        center: CGPoint,
        outerRadius: CGFloat,
        ringInnerRadius: CGFloat,
        toothTipRadius: CGFloat,
        toothCount: Int,
        startAngleDegrees: Double
    ) -> Path {
        var path = Path()
        // Outer boundary (clockwise).
        path.addEllipse(in: CGRect(
            x: center.x - outerRadius,
            y: center.y - outerRadius,
            width: outerRadius * 2,
            height: outerRadius * 2
        ))

        // Inner boundary with 6 inward teeth (cut out via eoFill).
        var hole = Path()
        let step = 360.0 / Double(toothCount)
        let halfToothTipDeg = 12.5
        let halfToothRootDeg = 15.5

        for index in (0..<toothCount).reversed() {
            let baseDeg = startAngleDegrees + Double(index) * step
            let rootEnd = Angle.degrees(baseDeg + halfToothRootDeg - 90)
            let tipEnd = Angle.degrees(baseDeg + halfToothTipDeg - 90)
            let tipStart = Angle.degrees(baseDeg - halfToothTipDeg - 90)
            let rootStart = Angle.degrees(baseDeg - halfToothRootDeg - 90)
            let nextRootEnd = Angle.degrees(baseDeg - step + halfToothRootDeg - 90)

            let startPoint = point(center: center, radius: ringInnerRadius, angle: rootEnd)
            if index == toothCount - 1 {
                hole.move(to: startPoint)
            } else {
                hole.addLine(to: startPoint)
            }
            hole.addLine(to: point(center: center, radius: toothTipRadius, angle: tipEnd))
            hole.addArc(
                center: center,
                radius: toothTipRadius,
                startAngle: tipEnd,
                endAngle: tipStart,
                clockwise: true
            )
            hole.addLine(to: point(center: center, radius: ringInnerRadius, angle: rootStart))
            hole.addArc(
                center: center,
                radius: ringInnerRadius,
                startAngle: rootStart,
                endAngle: nextRootEnd,
                clockwise: true
            )
        }
        hole.closeSubpath()

        path.addPath(hole)
        return path
    }

    private func driveDrumPath(
        center: CGPoint,
        coreRadius: CGFloat,
        lugOuterRadius: CGFloat,
        lugCount: Int,
        startAngleDegrees: Double
    ) -> Path {
        var path = Path()
        let step = 360.0 / Double(lugCount)
        let halfLugBaseDeg = 10.5
        let halfLugTipDeg = 8.5

        for index in 0..<lugCount {
            let baseDeg = startAngleDegrees + Double(index) * step
            let baseStart = Angle.degrees(baseDeg - halfLugBaseDeg - 90)
            let tipStart = Angle.degrees(baseDeg - halfLugTipDeg - 90)
            let tipEnd = Angle.degrees(baseDeg + halfLugTipDeg - 90)
            let baseEnd = Angle.degrees(baseDeg + halfLugBaseDeg - 90)
            let nextBaseStart = Angle.degrees(baseDeg + step - halfLugBaseDeg - 90)

            if index == 0 {
                path.move(to: point(center: center, radius: coreRadius, angle: baseStart))
            }
            path.addLine(to: point(center: center, radius: lugOuterRadius, angle: tipStart))
            path.addArc(
                center: center,
                radius: lugOuterRadius,
                startAngle: tipStart,
                endAngle: tipEnd,
                clockwise: false
            )
            path.addLine(to: point(center: center, radius: coreRadius, angle: baseEnd))
            path.addArc(
                center: center,
                radius: coreRadius,
                startAngle: baseEnd,
                endAngle: nextBaseStart,
                clockwise: false
            )
        }
        path.closeSubpath()
        return path
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        let radians = angle.radians
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }
}
