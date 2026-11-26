import SwiftUI

/// Minimalist studio-lit cassette shells sharing exact physical drive axles,
/// tape-head bays and shell registration:
/// - `.armature` (烟灰): matte anodized charcoal-smoke with wide recessed glass window
/// - `.fieldNotes` (纸纹): warm ivory micro-ribbed paper shell with soft waisted aperture
/// - `.silverOval` (原铝): finely brushed raw anodized aluminum with capsule oval window
/// - `.twinArc` (雾蓝): muted architectural slate-blue matte shell with figure-8 dual arc window
struct OneTapeBespokeCassette: View {
    let style: OneTapeAppearance.TapeStyle
    var supplyAngle: Angle = .zero
    var takeupAngle: Angle = .zero
    var tapeProgress: Double = 0
    var reelExposureDegrees: Double = 0
    var reelColor: OneTapeAppearance.ReelColor? = nil

    var body: some View {
        let radii = OneTapeTapeGeometry.radii(progress: tapeProgress)
        ZStack(alignment: .topLeading) {
            interiorBay
                .drawingGroup()
            tapePacks(radii: radii)
            rotatingWheels
            ZStack(alignment: .topLeading) {
                maskedShellPlate
                windowBezelAndHardware
                lowerHeadCutoutAndHardware
            }
            .drawingGroup()
        }
        .frame(width: OneTapeBespokeGeometry.canvasSize.width,
               height: OneTapeBespokeGeometry.canvasSize.height)
        .scaleEffect(x: OneTapeBespokeGeometry.drawingScale.width,
                     y: OneTapeBespokeGeometry.drawingScale.height)
        .rotationEffect(.degrees(90))
        .position(OneTapeBespokeGeometry.canvasCenter)
        .frame(width: 376.33, height: 576)
        .mask {
            OneTapeBespokeGeometry.shell
                .applying(OneTapeBespokeGeometry.portraitTransform)
                .fill(.white)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var interiorBay: some View {
        Canvas { context, _ in
            let cavityColor: Color = switch style {
            case .fieldNotes: Color(red: 0.16, green: 0.145, blue: 0.13)
            case .silverOval: Color(red: 0.12, green: 0.125, blue: 0.135)
            default: Color(red: 0.085, green: 0.09, blue: 0.10)
            }
            context.fill(OneTapeBespokeGeometry.shell, with: .color(cavityColor))
            var tape = Path()
            tape.move(to: CGPoint(x: 34, y: 120))
            tape.addLine(to: CGPoint(x: 68, y: 138))
            tape.addLine(to: CGPoint(x: 220, y: 138))
            tape.addLine(to: CGPoint(x: 254, y: 120))
            context.stroke(tape, with: .color(Color(red: 0.25, green: 0.18, blue: 0.14).opacity(0.85)), lineWidth: 4.5)
        }
    }

    private func tapePacks(radii: (supply: Double, takeup: Double)) -> some View {
        ZStack(alignment: .topLeading) {
            OneTapeBespokeTapePack(radius: CGFloat(radii.supply) / OneTapeBespokeGeometry.scale)
                .position(OneTapeBespokeGeometry.supply)
            OneTapeBespokeTapePack(radius: CGFloat(radii.takeup) / OneTapeBespokeGeometry.scale)
                .position(OneTapeBespokeGeometry.takeup)
        }
        .frame(width: OneTapeBespokeGeometry.canvasSize.width,
               height: OneTapeBespokeGeometry.canvasSize.height)
        .mask { OneTapeBespokeGeometry.landscapeWindow(for: style).fill(.white) }
    }

    @ViewBuilder
    private var rotatingWheels: some View {
        let showsLegacy = reelColor == nil
        switch style {
        case .armature:
            wheelPair(
                diameter: 22.8,
                outerFraction: 0.82,
                supply: OneTapeArmatureSupplyWheel(showsLegacyCollar: showsLegacy),
                takeup: OneTapeArmatureTakeupWheel(showsLegacyCollar: showsLegacy)
            )
        case .fieldNotes:
            wheelPair(
                diameter: 22.6,
                outerFraction: 0.82,
                supply: OneTapeFieldNotesHubWheel(showsLegacyCollar: showsLegacy),
                takeup: OneTapeFieldNotesHubWheel(showsLegacyCollar: showsLegacy)
            )
        case .silverOval:
            wheelPair(
                diameter: 22.4,
                outerFraction: 0.82,
                supply: OneTapeSilverStudioWheel(tabAngle: 180, showsLegacyCollar: showsLegacy),
                takeup: OneTapeSilverStudioWheel(tabAngle: 0, showsLegacyCollar: showsLegacy)
            )
        case .twinArc:
            wheelPair(
                diameter: 24.4,
                outerFraction: 0.82,
                supply: OneTapeTwinArcDialWheel(showsLegacyCollar: showsLegacy),
                takeup: OneTapeTwinArcDialWheel(showsLegacyCollar: showsLegacy)
            )
        default:
            EmptyView()
        }
    }

    private func wheelPair<Supply: View, Takeup: View>(
        diameter: CGFloat,
        outerFraction: CGFloat,
        supply supplyWheel: Supply,
        takeup takeupWheel: Takeup
    ) -> some View {
        ZStack(alignment: .topLeading) {
            mountedWheel(supplyWheel, at: OneTapeBespokeGeometry.supply, angle: supplyAngle,
                         gearDiameter: diameter, outerFraction: outerFraction)
            mountedWheel(takeupWheel, at: OneTapeBespokeGeometry.takeup, angle: takeupAngle,
                         gearDiameter: diameter, outerFraction: outerFraction)
        }
        .frame(width: OneTapeBespokeGeometry.canvasSize.width,
               height: OneTapeBespokeGeometry.canvasSize.height)
    }

    @ViewBuilder
    private func mountedWheel<Wheel: View>(
        _ wheel: Wheel,
        at center: CGPoint,
        angle: Angle,
        gearDiameter: CGFloat,
        outerFraction: CGFloat
    ) -> some View {
        wheel
            .modifier(OneTapeReelExposure(angle: angle, spread: reelExposureDegrees))
            .position(center)
        if let reelColor {
            OneTapeReelGearView(
                color: reelColor,
                diameter: gearDiameter,
                angle: angle,
                reelExposureDegrees: reelExposureDegrees,
                showsOuterBezel: true,
                showsAxlePin: true,
                gearOuterRadiusFraction: outerFraction
            )
            .position(center)
        }
    }

    private var maskedShellPlate: some View {
        shellMaterialCanvas
            .compositingGroup()
            .mask {
                OneTapeBespokeGeometry.shell
                    .subtracting(OneTapeBespokeGeometry.landscapeWindow(for: style), eoFill: false)
                    .fill(.white)
            }
    }

    private var shellMaterialCanvas: some View {
        Canvas { context, _ in
            let shell = OneTapeBespokeGeometry.shell
            let frame = OneTapeBespokeGeometry.shellFrame
            let colors: [Color] = switch style {
            case .armature:
                // Warm matte anodized smoke-charcoal
                [Color(red: 0.255, green: 0.258, blue: 0.264),
                 Color(red: 0.205, green: 0.208, blue: 0.214),
                 Color(red: 0.228, green: 0.232, blue: 0.238)]
            case .fieldNotes:
                // Quiet architectural oatmeal/ivory paper stock
                [Color(red: 0.935, green: 0.916, blue: 0.872),
                 Color(red: 0.892, green: 0.870, blue: 0.822),
                 Color(red: 0.914, green: 0.894, blue: 0.848)]
            case .silverOval:
                // Finely brushed raw anodized aluminum
                [Color(red: 0.885, green: 0.892, blue: 0.898),
                 Color(red: 0.785, green: 0.796, blue: 0.806),
                 Color(red: 0.855, green: 0.864, blue: 0.872)]
            case .twinArc:
                // Muted Nordic slate-mist blue matte finish
                [Color(red: 0.235, green: 0.285, blue: 0.340),
                 Color(red: 0.192, green: 0.238, blue: 0.290),
                 Color(red: 0.215, green: 0.262, blue: 0.315)]
            default:
                [Color(white: 0.20), Color(white: 0.16)]
            }

            context.fill(shell, with: .linearGradient(
                Gradient(colors: colors),
                startPoint: CGPoint(x: frame.minX, y: frame.minY),
                endPoint: CGPoint(x: frame.maxX, y: frame.maxY)))

            // Surface-specific micro-craft texture, restrained for studio realism.
            var clipped = context
            clipped.clip(to: shell)
            switch style {
            case .silverOval:
                for row in 0..<260 {
                    let y = frame.minY + CGFloat(row) * (frame.height / 260)
                    var line = Path()
                    line.move(to: CGPoint(x: frame.minX, y: y))
                    line.addLine(to: CGPoint(x: frame.maxX, y: y))
                    let shade: Color = row.isMultiple(of: 3) ? .white : .black
                    clipped.stroke(line, with: .color(shade.opacity(0.028)), lineWidth: 0.22)
                }
            case .fieldNotes:
                // Subtle vertical pressed paper ribs (inspired by Paper Ribbed)
                for x in stride(from: frame.minX + 4, to: frame.maxX - 2, by: 3.6) {
                    var rib = Path()
                    rib.move(to: CGPoint(x: x, y: frame.minY))
                    rib.addLine(to: CGPoint(x: x, y: frame.maxY))
                    clipped.stroke(rib, with: .color(Color(red: 0.45, green: 0.39, blue: 0.30).opacity(0.065)), lineWidth: 0.55)
                    clipped.stroke(rib.offsetBy(dx: 0.7, dy: 0), with: .color(.white.opacity(0.16)), lineWidth: 0.45)
                }
            case .armature, .twinArc:
                // Soft top-left studio lighting falloff for velvety matte polymer feel
                clipped.fill(shell, with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.08), .clear, .black.opacity(0.14)]),
                    center: CGPoint(x: frame.minX + 60, y: frame.minY + 35),
                    startRadius: 10, endRadius: 260))
            default:
                break
            }

            // Quiet perimeter chamfer & hairline bevel
            let isLight = style == .silverOval || style == .fieldNotes
            let bevel = Path(roundedRect: frame.insetBy(dx: 0.9, dy: 0.9), cornerRadius: 10.1)
            context.stroke(bevel, with: .linearGradient(
                Gradient(colors: [
                    .white.opacity(isLight ? 0.68 : 0.24),
                    .clear,
                    .black.opacity(isLight ? 0.16 : 0.36)
                ]),
                startPoint: CGPoint(x: frame.minX, y: frame.minY),
                endPoint: CGPoint(x: frame.maxX, y: frame.maxY)), lineWidth: 0.85)
            context.stroke(shell, with: .color(.black.opacity(isLight ? 0.18 : 0.42)), lineWidth: 0.9)

            // Recessed subtle label-plane step with authentic top-corner chamfers
            // clearing the upper screws cleanly while framing the printable area.
            var labelInset = Path()
            labelInset.move(to: CGPoint(x: 37, y: 22))
            labelInset.addLine(to: CGPoint(x: 250, y: 22))
            labelInset.addLine(to: CGPoint(x: 264, y: 36))
            labelInset.addLine(to: CGPoint(x: 264, y: 132))
            labelInset.addQuadCurve(to: CGPoint(x: 260, y: 136), control: CGPoint(x: 264, y: 136))
            labelInset.addLine(to: CGPoint(x: 27, y: 136))
            labelInset.addQuadCurve(to: CGPoint(x: 23, y: 132), control: CGPoint(x: 23, y: 136))
            labelInset.addLine(to: CGPoint(x: 23, y: 36))
            labelInset.closeSubpath()
            context.stroke(labelInset, with: .color(.black.opacity(isLight ? 0.055 : 0.16)), lineWidth: 0.6)
            context.stroke(labelInset.offsetBy(dx: 0, dy: 0.5),
                           with: .color(.white.opacity(isLight ? 0.24 : 0.06)), lineWidth: 0.45)

            // Raised lower trapezoid magnetic-head bridge
            let lower = OneTapeBespokeGeometry.lowerHeadDeck
            context.fill(lower, with: .linearGradient(
                Gradient(colors: [
                    colors[0].opacity(0.96),
                    colors[1].opacity(0.98)
                ]),
                startPoint: CGPoint(x: 144, y: 140), endPoint: CGPoint(x: 144, y: 181)))
            context.stroke(lower, with: .color(.white.opacity(isLight ? 0.50 : 0.14)), lineWidth: 0.65)
            context.stroke(lower, with: .color(.black.opacity(isLight ? 0.18 : 0.40)), lineWidth: 0.9)
        }
    }

    private var windowBezelAndHardware: some View {
        Canvas { context, _ in
            let aperture = OneTapeBespokeGeometry.landscapeWindow(for: style)
            let isLight = style == .silverOval || style == .fieldNotes

            // Subtle optical glazing reflection across the recessed aperture.
            context.fill(aperture, with: .linearGradient(
                Gradient(colors: [
                    .white.opacity(isLight ? 0.12 : 0.08),
                    .clear,
                    .black.opacity(isLight ? 0.10 : 0.18)
                ]),
                startPoint: CGPoint(x: 40, y: 50),
                endPoint: CGPoint(x: 248, y: 132)))

            // Minimalist center tape-sightline hair marks (quiet, functional detail).
            if style == .armature || style == .silverOval {
                for step in 0..<5 {
                    let tx = 128 + CGFloat(step) * 8.0
                    let tall = step == 2
                    var tick = Path()
                    tick.move(to: CGPoint(x: tx, y: tall ? 85.5 : 87.5))
                    tick.addLine(to: CGPoint(x: tx, y: tall ? 93.5 : 91.5))
                    context.stroke(tick, with: .color(.white.opacity(tall ? 0.34 : 0.18)), lineWidth: 0.55)
                }
            }

            // Crisp recessed inner wall shadow + fine outer rim catchlight.
            var innerClip = context
            innerClip.clip(to: aperture)
            innerClip.stroke(aperture, with: .color(.black.opacity(isLight ? 0.24 : 0.52)), lineWidth: 3.0)

            context.stroke(aperture, with: .linearGradient(
                Gradient(colors: [
                    .black.opacity(isLight ? 0.30 : 0.58),
                    .white.opacity(isLight ? 0.68 : 0.24)
                ]),
                startPoint: CGPoint(x: 42, y: 50),
                endPoint: CGPoint(x: 246, y: 130)), lineWidth: 1.0)
        }
    }

    private var lowerHeadCutoutAndHardware: some View {
        Canvas { context, _ in
            let isLight = style == .silverOval || style == .fieldNotes
            let centerPad = Path(roundedRect: CGRect(x: 134, y: 164, width: 20, height: 12), cornerRadius: 1.8)
            context.fill(centerPad, with: .color(Color(white: 0.06)))
            context.fill(Path(CGRect(x: 137, y: 167, width: 14, height: 4.5)),
                         with: .color(Color(red: 0.52, green: 0.43, blue: 0.32)))

            for pt in OneTapeBespokeGeometry.bottomCapstans {
                let hole = OneTapeBespokeGeometry.circle(center: pt, radius: 4.1)
                context.fill(hole, with: .color(Color(white: 0.04)))
                context.stroke(hole, with: .color(isLight ? .black.opacity(0.24) : .white.opacity(0.14)), lineWidth: 0.55)
            }
            for pt in OneTapeBespokeGeometry.bottomGuides {
                let slot = Path(roundedRect: CGRect(x: pt.x - 4.2, y: pt.y - 3.3, width: 8.4, height: 6.6), cornerRadius: 1.4)
                context.fill(slot, with: .color(Color(white: 0.04)))
                context.stroke(slot, with: .color(isLight ? .black.opacity(0.22) : .white.opacity(0.12)), lineWidth: 0.5)
            }
            for pt in OneTapeBespokeGeometry.screws {
                drawScrew(in: &context, center: pt, isLight: isLight)
            }
        }
    }

    private func drawScrew(in context: inout GraphicsContext, center: CGPoint, isLight: Bool) {
        let well = OneTapeBespokeGeometry.circle(center: center, radius: 4.4)
        context.fill(well, with: .color(.black.opacity(isLight ? 0.14 : 0.38)))

        let head = OneTapeBespokeGeometry.circle(center: center, radius: 3.6)
        let topTone: Color = isLight ? Color(white: 0.72) : Color(white: 0.28)
        let bottomTone: Color = isLight ? Color(white: 0.42) : Color(white: 0.10)
        context.fill(head, with: .linearGradient(
            Gradient(colors: [topTone, bottomTone]),
            startPoint: CGPoint(x: center.x - 3, y: center.y - 3),
            endPoint: CGPoint(x: center.x + 3, y: center.y + 3)))
        context.stroke(head, with: .color(.white.opacity(isLight ? 0.45 : 0.16)), lineWidth: 0.4)

        var cross = Path()
        cross.move(to: CGPoint(x: center.x - 1.7, y: center.y))
        cross.addLine(to: CGPoint(x: center.x + 1.7, y: center.y))
        cross.move(to: CGPoint(x: center.x, y: center.y - 1.7))
        cross.addLine(to: CGPoint(x: center.x, y: center.y + 1.7))
        context.stroke(cross, with: .color(.black.opacity(0.55)), lineWidth: 0.75)
    }
}

/// Exact portrait window exclusion matching `OneTapeBespokeGeometry` so overlay lettering
/// and doodles never render inside transparent tape cavities.
struct OneTapeBespokeWindowMask: Shape {
    let style: OneTapeAppearance.TapeStyle

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        let cutout = OneTapeBespokeGeometry.landscapeWindow(for: style)
            .applying(OneTapeBespokeGeometry.portraitTransform)
        path.addPath(cutout)
        return path
    }
}
