import SwiftUI

/// CNC lathe-brushed anodized aluminum reel flange for exposed transparent shells.
/// Keeps the conical anisotropic brushed-metal sheen stationary under studio lighting
/// while the cutout mask, milled window bevels, and 3 domed spoke rivets rotate smoothly
/// with `OneTapeReelExposure` — matching Cassette 1.0.5's `FlangeView` optical model.
struct OneTapeMetalReelView: View {
    let diameter: CGFloat
    var style: OneTapeAppearance.ReelStyle = .classic
    var finish: OneTapeAppearance.ReelFinish = .silver
    var angle: Angle = .zero
    var reelExposureDegrees: Double = 0

    var body: some View {
        ZStack {
            stationaryBrushedDisc
                .mask {
                    OneTapeReelFlangeSilhouette(style: style)
                        .fill(.white, style: FillStyle(eoFill: true))
                        .frame(width: diameter, height: diameter)
                        .drawingGroup()
                        .modifier(OneTapeReelExposure(angle: angle, spread: reelExposureDegrees))
                }

            rotatingHardwareDetails
                .drawingGroup()
                .modifier(OneTapeReelExposure(angle: angle, spread: reelExposureDegrees))
        }
        .frame(width: diameter, height: diameter)
    }

    /// Stationary lathe-brushed anodized disc whose anisotropic butterfly highlight
    /// stays anchored to the fixed studio light while cutouts sweep underneath it.
    private var stationaryBrushedDisc: some View {
        let collarOuter = diameter * 0.452
        let collarInner = diameter * 0.362

        return ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(stops: finish.anisotropicGradientStops),
                        center: .center,
                        angle: .degrees(-36)
                    )
                )
                .frame(width: diameter - 1.4, height: diameter - 1.4)

            // Directional studio key-light gradient grounding the aluminum inside the shell.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(finish == .graphite ? 0.14 : 0.20),
                            .clear,
                            .black.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: diameter - 1.4, height: diameter - 1.4)

            // Subtle radial sheen falloff toward the machined edge.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.08),
                            .clear,
                            .black.opacity(0.14)
                        ],
                        center: .center,
                        startRadius: diameter * 0.18,
                        endRadius: diameter * 0.50
                    )
                )
                .frame(width: diameter - 1.4, height: diameter - 1.4)

            // Concentric CNC lathe micro-grooves (suppressed at tiny icon scales to avoid moire).
            if diameter >= 72 {
                latheMicroGrooves
            }

            // Recessed machined anodized collar hugging the 80.67pt center hub.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            finish.deepColor.opacity(0.86),
                            finish.valleyColor.opacity(0.72),
                            finish.deepColor.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1.2, (collarOuter - collarInner) * 0.50)
                )
                .frame(width: collarOuter, height: collarOuter)

            // Outer & inner machined chamfer rings framing the recessed collar step.
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.black.opacity(0.38), finish.rimLight.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.7, diameter * 0.0065)
                )
                .frame(width: collarOuter, height: collarOuter)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [finish.rimLight.opacity(0.85), .black.opacity(0.32)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.65, diameter * 0.0055)
                )
                .frame(width: collarInner + max(1.0, diameter * 0.008), height: collarInner + max(1.0, diameter * 0.008))

            // Outer flange edge bevel.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [finish.rimLight.opacity(0.82), .black.opacity(0.36)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.75, diameter * 0.0055)
                )
                .frame(width: diameter - 1.4, height: diameter - 1.4)
        }
        .frame(width: diameter, height: diameter)
        .drawingGroup()
    }

    private var latheMicroGrooves: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            let startR = diameter * 0.232
            let endR = diameter * 0.490
            let ringCount = 34
            let step = (endR - startR) / CGFloat(ringCount)
            for index in 0..<ringCount {
                let r = startR + CGFloat(index) * step
                let mixed = UInt64(index) &* 2654435761
                let isLight = ((mixed >> 17) & 1) == 0
                let weight = CGFloat((mixed >> 9) & 0xFF) / 255.0
                let alpha = (isLight ? 0.055 : 0.048) * (0.45 + 0.55 * weight)
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(isLight ? .white.opacity(alpha) : .black.opacity(alpha)),
                    lineWidth: 0.45
                )
            }
        }
        .frame(width: diameter, height: diameter)
    }

    /// Physical details fixed to the metal plate itself (cutout chamfers, 3 domed spoke
    /// rivets, and collar key ticks) that spin cleanly with the reel axle.
    private var rotatingHardwareDetails: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

            // Cutout milled edge shadows and specular chamfers for classic & rounded styles.
            let cutouts = OneTapeReelFlangeGeometry.cutoutPaths(style: style, in: rect)
            if !cutouts.isEmpty {
                let bevelWidth = max(0.75, diameter * 0.0075)
                let shadowWidth = max(1.1, diameter * 0.0115)
                for cutout in cutouts {
                    context.stroke(
                        cutout,
                        with: .color(.black.opacity(0.42)),
                        style: StrokeStyle(lineWidth: shadowWidth, lineCap: .round, lineJoin: .round)
                    )
                    context.stroke(
                        cutout,
                        with: .color(finish.rimLight.opacity(0.55)),
                        style: StrokeStyle(lineWidth: bevelWidth, lineCap: .round, lineJoin: .round)
                    )
                }
            }

            // 3 raised machined domed rivets centered on the solid spokes (angles: -30, 90, 210 deg)
            // matching Cassette 1.0.5's FlangeTurn rivets across classic, rounded, and solid.
            let rivetOrbit = diameter * 0.278
            let rivetRadius = max(1.5, diameter * 0.0185)
            for index in 0..<3 {
                let rad = (Double(index) * 120.0 - 30.0) * .pi / 180.0
                let pos = CGPoint(
                    x: center.x + cos(rad) * rivetOrbit,
                    y: center.y + sin(rad) * rivetOrbit
                )

                // Soft machined seating ring & contact shadow.
                let shadowRect = CGRect(
                    x: pos.x - rivetRadius * 1.24,
                    y: pos.y - rivetRadius * 1.10,
                    width: rivetRadius * 2.48,
                    height: rivetRadius * 2.48
                )
                context.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.36)))

                // Domed brushed-steel rivet cap.
                let domeRect = CGRect(
                    x: pos.x - rivetRadius,
                    y: pos.y - rivetRadius,
                    width: rivetRadius * 2,
                    height: rivetRadius * 2
                )
                let highlightCenter = CGPoint(
                    x: pos.x - rivetRadius * 0.28,
                    y: pos.y - rivetRadius * 0.28
                )
                context.fill(
                    Path(ellipseIn: domeRect),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: .white.opacity(0.95), location: 0.0),
                            .init(color: Color(white: 0.78), location: 0.42),
                            .init(color: Color(white: 0.44), location: 0.82),
                            .init(color: Color(white: 0.26), location: 1.0)
                        ]),
                        center: highlightCenter,
                        startRadius: 0,
                        endRadius: rivetRadius * 1.45
                    )
                )
                context.stroke(
                    Path(ellipseIn: domeRect),
                    with: .color(.black.opacity(0.32)),
                    lineWidth: max(0.35, diameter * 0.0024)
                )

                // Subtle radial indexing lock notch on the inner collar aligned with each spoke.
                let tickStart = diameter * 0.188
                let tickEnd = diameter * 0.214
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + cos(rad) * tickStart, y: center.y + sin(rad) * tickStart))
                tick.addLine(to: CGPoint(x: center.x + cos(rad) * tickEnd, y: center.y + sin(rad) * tickEnd))
                context.stroke(
                    tick,
                    with: .color(finish.rimLight.opacity(0.45)),
                    style: StrokeStyle(lineWidth: max(0.8, diameter * 0.0075), lineCap: .round)
                )
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

/// Even-odd filled flange mask silhouette for the 3 Cassette 1.0.5 reel styles.
struct OneTapeReelFlangeSilhouette: Shape {
    let style: OneTapeAppearance.ReelStyle

    func path(in rect: CGRect) -> Path {
        let diameter = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path(ellipseIn: CGRect(
            x: center.x - diameter * 0.5 + 0.7,
            y: center.y - diameter * 0.5 + 0.7,
            width: diameter - 1.4,
            height: diameter - 1.4
        ))

        let hubHole = diameter * 0.362
        path.addEllipse(in: CGRect(
            x: center.x - hubHole * 0.5,
            y: center.y - hubHole * 0.5,
            width: hubHole,
            height: hubHole
        ))

        for cutout in OneTapeReelFlangeGeometry.cutoutPaths(style: style, in: rect) {
            path.addPath(cutout)
        }
        return path
    }
}

/// Shared pure-geometry builder for cutout paths so mask and chamfer stroke stay pixel-locked.
enum OneTapeReelFlangeGeometry {
    static func cutoutPaths(style: OneTapeAppearance.ReelStyle, in rect: CGRect) -> [Path] {
        let diameter = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)

        switch style {
        case .classic:
            // 3 slim curved crescent arc slots matching Cassette 1.0.5 `FlangeTurnSupply` (classic).
            let rIn = diameter * 0.326
            let rOut = diameter * 0.440
            let cornerR = (rOut - rIn) * 0.47
            return (0..<3).map { index in
                let midAngle = Double(index) * 120.0 - 90.0
                return roundedAnnularSector(
                    center: center,
                    innerRadius: rIn,
                    outerRadius: rOut,
                    startDegrees: midAngle - 43.0,
                    endDegrees: midAngle + 43.0,
                    cornerRadius: cornerR
                )
            }

        case .rounded:
            // 3 wide rounded-trapezoid fan windows matching Cassette 1.0.5 `FlangeTurnSupplyRounded`.
            let rIn = diameter * 0.246
            let rOut = diameter * 0.446
            let cornerR = diameter * 0.046
            return (0..<3).map { index in
                let midAngle = Double(index) * 120.0 - 90.0
                return roundedAnnularSector(
                    center: center,
                    innerRadius: rIn,
                    outerRadius: rOut,
                    startDegrees: midAngle - 35.5,
                    endDegrees: midAngle + 35.5,
                    cornerRadius: cornerR
                )
            }

        case .solid:
            // Full uninterrupted solid CNC aluminum platter matching `FlangeTurnSupplySolid`.
            return []
        }
    }

    private static func roundedAnnularSector(
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        startDegrees: Double,
        endDegrees: Double,
        cornerRadius: CGFloat
    ) -> Path {
        let rC = min(cornerRadius, (outerRadius - innerRadius) * 0.48)
        let outerInsetDeg = Double(rC / outerRadius) * 180.0 / .pi
        let innerInsetDeg = Double(rC / innerRadius) * 180.0 / .pi

        func pt(_ r: CGFloat, _ deg: Double) -> CGPoint {
            let a = deg * .pi / 180.0
            return CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
        }

        var p = Path()
        p.move(to: pt(outerRadius - rC, startDegrees))
        p.addQuadCurve(
            to: pt(outerRadius, startDegrees + outerInsetDeg),
            control: pt(outerRadius, startDegrees)
        )
        p.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .degrees(startDegrees + outerInsetDeg),
            endAngle: .degrees(endDegrees - outerInsetDeg),
            clockwise: false
        )
        p.addQuadCurve(
            to: pt(outerRadius - rC, endDegrees),
            control: pt(outerRadius, endDegrees)
        )
        p.addLine(to: pt(innerRadius + rC, endDegrees))
        p.addQuadCurve(
            to: pt(innerRadius, endDegrees - innerInsetDeg),
            control: pt(innerRadius, endDegrees)
        )
        p.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .degrees(endDegrees - innerInsetDeg),
            endAngle: .degrees(startDegrees + innerInsetDeg),
            clockwise: true
        )
        p.addQuadCurve(
            to: pt(innerRadius + rC, startDegrees),
            control: pt(innerRadius, startDegrees)
        )
        p.closeSubpath()
        return p
    }
}

extension OneTapeAppearance.ReelStyle {
    var customizationTitle: String {
        switch self {
        case .classic: "经典"
        case .rounded: "圆角"
        case .solid: "实心"
        }
    }

    var accessibilityName: String {
        "\(customizationTitle)金属卷盘"
    }
}

extension OneTapeAppearance.ReelFinish {
    var customizationTitle: String {
        switch self {
        case .silver: "银色"
        case .ruby: "红宝石"
        case .gold: "金色"
        case .cobalt: "钴蓝"
        case .graphite: "石墨"
        case .orange: "橙色"
        case .emerald: "祖母绿"
        }
    }

    var accessibilityName: String {
        "\(customizationTitle)卷盘"
    }

    var brightColor: Color {
        switch self {
        case .silver: Color(red: 0.975, green: 0.980, blue: 0.990)
        case .ruby: Color(red: 0.990, green: 0.480, blue: 0.555)
        case .gold: Color(red: 1.000, green: 0.930, blue: 0.720)
        case .cobalt: Color(red: 0.580, green: 0.800, blue: 1.000)
        case .graphite: Color(red: 0.630, green: 0.650, blue: 0.695)
        case .orange: Color(red: 1.000, green: 0.735, blue: 0.460)
        case .emerald: Color(red: 0.480, green: 0.905, blue: 0.680)
        }
    }

    var midColor: Color {
        switch self {
        case .silver: Color(red: 0.805, green: 0.820, blue: 0.840)
        case .ruby: Color(red: 0.790, green: 0.145, blue: 0.255)
        case .gold: Color(red: 0.845, green: 0.655, blue: 0.305)
        case .cobalt: Color(red: 0.175, green: 0.425, blue: 0.845)
        case .graphite: Color(red: 0.345, green: 0.365, blue: 0.405)
        case .orange: Color(red: 0.925, green: 0.420, blue: 0.130)
        case .emerald: Color(red: 0.105, green: 0.565, blue: 0.355)
        }
    }

    var valleyColor: Color {
        switch self {
        case .silver: Color(red: 0.490, green: 0.505, blue: 0.535)
        case .ruby: Color(red: 0.420, green: 0.055, blue: 0.125)
        case .gold: Color(red: 0.515, green: 0.370, blue: 0.135)
        case .cobalt: Color(red: 0.070, green: 0.195, blue: 0.485)
        case .graphite: Color(red: 0.165, green: 0.178, blue: 0.205)
        case .orange: Color(red: 0.565, green: 0.215, blue: 0.045)
        case .emerald: Color(red: 0.040, green: 0.285, blue: 0.175)
        }
    }

    var deepColor: Color {
        switch self {
        case .silver: Color(red: 0.360, green: 0.375, blue: 0.405)
        case .ruby: Color(red: 0.265, green: 0.032, blue: 0.080)
        case .gold: Color(red: 0.345, green: 0.240, blue: 0.082)
        case .cobalt: Color(red: 0.042, green: 0.115, blue: 0.305)
        case .graphite: Color(red: 0.105, green: 0.115, blue: 0.135)
        case .orange: Color(red: 0.365, green: 0.125, blue: 0.022)
        case .emerald: Color(red: 0.022, green: 0.175, blue: 0.105)
        }
    }

    var rimLight: Color {
        switch self {
        case .silver: Color.white
        case .ruby: Color(red: 1.00, green: 0.72, blue: 0.76)
        case .gold: Color(red: 1.00, green: 0.95, blue: 0.78)
        case .cobalt: Color(red: 0.72, green: 0.88, blue: 1.00)
        case .graphite: Color(white: 0.82)
        case .orange: Color(red: 1.00, green: 0.82, blue: 0.62)
        case .emerald: Color(red: 0.68, green: 0.96, blue: 0.82)
        }
    }

    var anisotropicGradientStops: [Gradient.Stop] {
        [
            .init(color: brightColor, location: 0.00),
            .init(color: midColor, location: 0.12),
            .init(color: valleyColor, location: 0.25),
            .init(color: midColor, location: 0.38),
            .init(color: brightColor, location: 0.50),
            .init(color: midColor, location: 0.62),
            .init(color: valleyColor, location: 0.75),
            .init(color: midColor, location: 0.88),
            .init(color: brightColor, location: 1.00)
        ]
    }
}
