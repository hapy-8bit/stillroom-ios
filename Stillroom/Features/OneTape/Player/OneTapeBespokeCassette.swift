import SwiftUI

/// Architectural CAD reconstruction of the four bespoke cassette designs
/// sharing exact physical drive axles, tape-head bays and shell registration.
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
            context.fill(OneTapeBespokeGeometry.shell, with: .color(Color(red: 0.08, green: 0.075, blue: 0.07)))
            // Stretched oxide magnetic ribbon running behind lower window guide pins
            var tape = Path()
            tape.move(to: CGPoint(x: 34, y: 120))
            tape.addLine(to: CGPoint(x: 68, y: 138))
            tape.addLine(to: CGPoint(x: 220, y: 138))
            tape.addLine(to: CGPoint(x: 254, y: 120))
            context.stroke(tape, with: .color(Color(red: 0.24, green: 0.16, blue: 0.12)), lineWidth: 5.5)
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
                diameter: 26.6,
                outerFraction: 0.80,
                supply: OneTapeArmatureSupplyWheel(showsLegacyCollar: showsLegacy),
                takeup: OneTapeArmatureTakeupWheel(showsLegacyCollar: showsLegacy)
            )
        case .fieldNotes:
            wheelPair(
                diameter: 23.0,
                outerFraction: 0.82,
                supply: OneTapeFieldNotesHubWheel(showsLegacyCollar: showsLegacy),
                takeup: OneTapeFieldNotesHubWheel(showsLegacyCollar: showsLegacy)
            )
        case .silverOval:
            wheelPair(
                diameter: 25.0,
                outerFraction: 0.82,
                supply: OneTapeSilverStudioWheel(tabAngle: 180, showsLegacyCollar: showsLegacy),
                takeup: OneTapeSilverStudioWheel(tabAngle: 0, showsLegacyCollar: showsLegacy)
            )
        case .twinArc:
            wheelPair(
                diameter: 26.0,
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
        ZStack(alignment: .topLeading) {
            shellMaterialCanvas
            if style == .fieldNotes {
                fieldNotesPaperOverlay
            }
        }
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
                [Color(white: 0.25), Color(white: 0.19), Color(white: 0.22)]
            case .fieldNotes:
                [Color(red: 0.26, green: 0.18, blue: 0.13),
                 Color(red: 0.17, green: 0.12, blue: 0.09),
                 Color(red: 0.22, green: 0.15, blue: 0.11)]
            case .silverOval:
                [Color(red: 0.91, green: 0.92, blue: 0.92),
                 Color(red: 0.78, green: 0.80, blue: 0.81),
                 Color(red: 0.87, green: 0.88, blue: 0.89)]
            case .twinArc:
                [Color(red: 0.21, green: 0.27, blue: 0.34),
                 Color(red: 0.16, green: 0.21, blue: 0.27),
                 Color(red: 0.19, green: 0.25, blue: 0.31)]
            default:
                [Color(white: 0.20), Color(white: 0.16)]
            }
            context.fill(shell, with: .linearGradient(
                Gradient(colors: colors),
                startPoint: CGPoint(x: frame.minX, y: frame.minY),
                endPoint: CGPoint(x: frame.maxX, y: frame.maxY)))

            if style == .silverOval {
                var brushed = context
                brushed.clip(to: shell)
                for row in 0..<240 {
                    let y = frame.minY + CGFloat(row) * 0.7
                    var line = Path()
                    line.move(to: CGPoint(x: frame.minX, y: y))
                    line.addLine(to: CGPoint(x: frame.maxX, y: y))
                    brushed.stroke(line, with: .color((row.isMultiple(of: 3) ? Color.white : .black)
                        .opacity(0.036)), lineWidth: 0.28)
                }
                // Matte black knurled tactile side grip bumpers + milled aluminum groove
                for bx in [frame.minX + 1.5, frame.maxX - 9.5] {
                    let bar = Path(roundedRect: CGRect(x: bx, y: 40, width: 8, height: 96), cornerRadius: 2)
                    brushed.fill(bar, with: .color(Color(white: 0.14)))
                    for ribY in stride(from: 44.0, to: 132.0, by: 4.5) {
                        var rib = Path()
                        rib.move(to: CGPoint(x: bx + 1.5, y: ribY))
                        rib.addLine(to: CGPoint(x: bx + 6.5, y: ribY))
                        brushed.stroke(rib, with: .color(.white.opacity(0.24)), lineWidth: 0.8)
                    }
                }
                let orangeTab = Path(roundedRect: CGRect(x: 224, y: 21, width: 28, height: 4.2), cornerRadius: 1.5)
                brushed.fill(orangeTab, with: .color(Color(red: 0.94, green: 0.36, blue: 0.10)))
                let groove = Path(roundedRect: frame.insetBy(dx: 12, dy: 8), cornerRadius: 6)
                context.stroke(groove, with: .color(.black.opacity(0.26)), lineWidth: 0.9)
                context.stroke(groove.offsetBy(dx: 0, dy: 0.7), with: .color(.white.opacity(0.62)), lineWidth: 0.5)
            }

            // Outer chamfer highlight
            let bevel = Path(roundedRect: frame.insetBy(dx: 1.0, dy: 1.0), cornerRadius: 10)
            context.stroke(bevel, with: .linearGradient(
                Gradient(colors: [.white.opacity(style == .silverOval ? 0.78 : 0.28),
                                  .black.opacity(0.45)]),
                startPoint: CGPoint(x: frame.minX, y: frame.minY),
                endPoint: CGPoint(x: frame.maxX, y: frame.maxY)), lineWidth: 0.9)

            // Raised lower trapezoid bridge skirt
            let lower = OneTapeBespokeGeometry.lowerHeadDeck
            context.fill(lower, with: .linearGradient(
                Gradient(colors: colors.map { $0.opacity(0.95) }),
                startPoint: CGPoint(x: 144, y: 140), endPoint: CGPoint(x: 144, y: 181)))
            context.stroke(lower, with: .color(.white.opacity(style == .silverOval ? 0.65 : 0.16)), lineWidth: 0.7)
            context.stroke(lower, with: .color(.black.opacity(0.45)), lineWidth: 1.1)
        }
    }

    private var fieldNotesPaperOverlay: some View {
        let cardRect = CGRect(x: 24, y: 25, width: 240, height: 112)
        return ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                let card = Path(roundedRect: cardRect, cornerRadius: 4)
                context.fill(card, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.96, green: 0.92, blue: 0.81),
                        Color(red: 0.89, green: 0.83, blue: 0.70)
                    ]),
                    startPoint: CGPoint(x: cardRect.minX, y: cardRect.minY),
                    endPoint: CGPoint(x: cardRect.maxX, y: cardRect.maxY)))
                var clipped = context
                clipped.clip(to: card)
                // Signature vintage vermilion-terracotta archive top band & ledger rulings
                clipped.fill(Path(CGRect(x: cardRect.minX, y: cardRect.minY, width: cardRect.width, height: 7.5)),
                             with: .color(Color(red: 0.78, green: 0.30, blue: 0.14)))
                clipped.stroke(card, with: .color(Color(red: 0.48, green: 0.34, blue: 0.20).opacity(0.32)), lineWidth: 5.5)
                for x in stride(from: cardRect.minX + 3, to: cardRect.maxX, by: 3.4) {
                    var rib = Path()
                    rib.move(to: CGPoint(x: x, y: cardRect.minY))
                    rib.addLine(to: CGPoint(x: x, y: cardRect.maxY))
                    clipped.stroke(rib, with: .color(Color(red: 0.52, green: 0.40, blue: 0.26).opacity(0.11)), lineWidth: 0.45)
                }
                for ruleY in [cardRect.minY + 34, cardRect.maxY - 24] {
                    var rule = Path()
                    rule.move(to: CGPoint(x: cardRect.minX + 8, y: ruleY))
                    rule.addLine(to: CGPoint(x: cardRect.maxX - 8, y: ruleY))
                    clipped.stroke(rule, with: .color(Color(red: 0.74, green: 0.25, blue: 0.16).opacity(0.45)), lineWidth: 0.7)
                }
                for ruleX in [cardRect.minX + 34, cardRect.maxX - 34] {
                    var rule = Path()
                    rule.move(to: CGPoint(x: ruleX, y: cardRect.minY + 10))
                    rule.addLine(to: CGPoint(x: ruleX, y: cardRect.maxY - 8))
                    clipped.stroke(rule, with: .color(Color(red: 0.25, green: 0.38, blue: 0.52).opacity(0.36)), lineWidth: 0.55)
                }
                // Warm translucent washi masking-tape strips holding top corners
                for (pt, angle) in [(CGPoint(x: 27, y: 27), -0.7), (CGPoint(x: 261, y: 27), 0.7)] {
                    var tapeCtx = context
                    tapeCtx.translateBy(x: pt.x, y: pt.y)
                    tapeCtx.rotate(by: .radians(angle))
                    tapeCtx.fill(Path(CGRect(x: -11, y: -3.5, width: 22, height: 7)),
                                 with: .color(Color(red: 0.90, green: 0.80, blue: 0.62).opacity(0.82)))
                }
                context.stroke(card, with: .color(.black.opacity(0.6)), lineWidth: 0.7)
            }
            Text("NO. 04 • ARCHIVE")
                .font(.custom("GeistMono-Regular", fixedSize: 5.0))
                .tracking(0.3)
                .foregroundStyle(Color(red: 0.22, green: 0.16, blue: 0.12))
                .position(x: 56, y: 38)
            Text("ANALOGUE")
                .font(.custom("GeistMono-Regular", fixedSize: 5.0))
                .tracking(0.4)
                .foregroundStyle(Color(red: 0.22, green: 0.16, blue: 0.12))
                .position(x: 42, y: 124)
            Text("OCT 1973")
                .font(.custom("GeistMono-Regular", fixedSize: 5.0))
                .tracking(0.4)
                .foregroundStyle(Color(red: 0.22, green: 0.16, blue: 0.12))
                .position(x: 246, y: 124)
        }
    }

    @ViewBuilder
    private var windowBezelAndHardware: some View {
        switch style {
        case .armature: armatureWindowDetails
        case .fieldNotes: fieldNotesWindowDetails
        case .silverOval: silverOvalWindowDetails
        case .twinArc: twinArcWindowDetails
        default: EmptyView()
        }
    }

    private var armatureWindowDetails: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                let win = Path(roundedRect: OneTapeBespokeGeometry.armatureWindow, cornerRadius: 5)
                context.fill(win, with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.11), .clear, .black.opacity(0.18)]),
                    startPoint: CGPoint(x: 26, y: 46), endPoint: CGPoint(x: 262, y: 130)))
                context.stroke(win, with: .color(.white.opacity(0.28)), lineWidth: 1.0)
                context.stroke(Path(roundedRect: OneTapeBespokeGeometry.armatureWindow.insetBy(dx: 1.2, dy: 1.2), cornerRadius: 4),
                               with: .color(.black.opacity(0.65)), lineWidth: 1.2)

                // Diagonal perforated aerospace truss strut across the window
                var strut = strutPolygon()
                for t in stride(from: 0.14, through: 0.86, by: 0.115) {
                    let hx = 74 + (196 - 74) * t
                    let hy = 31 + (135 - 31) * t
                    strut.addPath(OneTapeBespokeGeometry.circle(center: CGPoint(x: hx, y: hy), radius: 2.3))
                }
                context.fill(strut, with: .linearGradient(
                    Gradient(colors: [Color(white: 0.36), Color(white: 0.18), Color(white: 0.28)]),
                    startPoint: CGPoint(x: 70, y: 28), endPoint: CGPoint(x: 200, y: 138)),
                             style: FillStyle(eoFill: true))
                context.stroke(strutPolygon(), with: .color(.white.opacity(0.38)), lineWidth: 0.7)
                for anchor in [CGPoint(x: 77, y: 34), CGPoint(x: 193, y: 132)] {
                    context.fill(OneTapeBespokeGeometry.circle(center: anchor, radius: 2.8),
                                 with: .color(Color(white: 0.74)))
                }
            }
            Text("TYPE IV METAL")
                .font(.custom("GeistMono-Regular", fixedSize: 6.2))
                .tracking(0.6)
                .foregroundStyle(Color(white: 0.72))
                .position(x: 54, y: 137)
        }
    }

    private func strutPolygon() -> Path {
        let p0 = CGPoint(x: 74, y: 31)
        let p1 = CGPoint(x: 196, y: 135)
        let angle = atan2(p1.y - p0.y, p1.x - p0.x) + .pi / 2
        let w: CGFloat = 5.4
        let dx = cos(angle) * w
        let dy = sin(angle) * w
        return OneTapeBespokeGeometry.polygon([
            CGPoint(x: p0.x - dx, y: p0.y - dy),
            CGPoint(x: p1.x - dx, y: p1.y - dy),
            CGPoint(x: p1.x + dx, y: p1.y + dy),
            CGPoint(x: p0.x + dx, y: p0.y + dy)
        ])
    }

    private var fieldNotesWindowDetails: some View {
        Canvas { context, _ in
            let aperture = OneTapeBespokeGeometry.landscapeWindow(for: .fieldNotes)
            context.fill(aperture, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.65, green: 0.36, blue: 0.14).opacity(0.24),
                    Color.black.opacity(0.18)
                ]),
                startPoint: CGPoint(x: 60, y: 60),
                endPoint: CGPoint(x: 228, y: 120)))

            // Timing graduations along center bridge
            for step in 0..<7 {
                let x = 118 + CGFloat(step) * 8.5
                var mark = Path()
                mark.move(to: CGPoint(x: x, y: 88))
                mark.addLine(to: CGPoint(x: x, y: step.isMultiple(of: 2) ? 94 : 92))
                context.stroke(mark, with: .color(.white.opacity(0.45)), lineWidth: 0.65)
            }
            var leader = Path()
            leader.move(to: CGPoint(x: 112, y: 76))
            leader.addLine(to: CGPoint(x: 112, y: 104))
            context.stroke(leader, with: .color(Color(red: 0.85, green: 0.32, blue: 0.28).opacity(0.70)), lineWidth: 1.2)

            context.stroke(aperture, with: .color(Color(red: 0.14, green: 0.09, blue: 0.06)), lineWidth: 2.2)
            for c in [OneTapeBespokeGeometry.supply, OneTapeBespokeGeometry.takeup] {
                context.stroke(OneTapeBespokeGeometry.circle(center: c, radius: 30.8),
                               with: .color(Color(red: 0.72, green: 0.45, blue: 0.22).opacity(0.45)), lineWidth: 0.75)
            }
        }
    }

    private var silverOvalWindowDetails: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                let rect = OneTapeBespokeGeometry.silverOvalWindow
                let oval = Path(roundedRect: rect, cornerRadius: rect.height / 2)
                context.fill(oval, with: .linearGradient(
                    Gradient(colors: [.black.opacity(0.30), .white.opacity(0.10), .black.opacity(0.32)]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                let prism = Path(roundedRect: CGRect(x: 123, y: 73, width: 42, height: 34), cornerRadius: 5)
                context.fill(prism, with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(0.62), Color.white.opacity(0.38)]),
                    startPoint: CGPoint(x: 123, y: 73), endPoint: CGPoint(x: 165, y: 107)))
                context.stroke(prism, with: .color(.white.opacity(0.55)), lineWidth: 0.6)
                context.stroke(oval, with: .color(.white.opacity(0.85)), lineWidth: 2.2)
                context.stroke(Path(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: rect.height / 2 - 1.5),
                               with: .color(.black.opacity(0.65)), lineWidth: 1.0)

                // Precision millimeter vernier caliper rule etched below oval
                for step in 0...16 {
                    let tx = 86 + CGFloat(step) * 7.25
                    let tall = step.isMultiple(of: 4)
                    var tick = Path()
                    tick.move(to: CGPoint(x: tx, y: 134.5))
                    tick.addLine(to: CGPoint(x: tx, y: tall ? 138.0 : 136.5))
                    context.stroke(tick, with: .color(.black.opacity(tall ? 0.55 : 0.28)),
                                   lineWidth: tall ? 0.75 : 0.45)
                }
            }
            Text("TYPE I • NORMAL")
                .font(.custom("GeistMono-Regular", fixedSize: 5.0))
                .tracking(0.4)
                .foregroundStyle(Color(white: 0.24))
                .position(x: 52, y: 137)
            Text("CNC BILLET")
                .font(.custom("GeistMono-Regular", fixedSize: 5.0))
                .tracking(0.4)
                .foregroundStyle(Color(white: 0.24))
                .position(x: 236, y: 137)
        }
    }

    private var twinArcWindowDetails: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                let path = OneTapeBespokeGeometry.twinArcFigure8
                context.stroke(path, with: .linearGradient(
                    Gradient(colors: [Color(white: 0.92), Color(white: 0.56), Color(white: 0.84)]),
                    startPoint: CGPoint(x: 42, y: 42), endPoint: CGPoint(x: 246, y: 136)), lineWidth: 3.8)
                context.stroke(path, with: .color(.black.opacity(0.55)), lineWidth: 0.8)

                // Dense radial chronograph graduations along both outer arcs
                for center in [OneTapeBespokeGeometry.supply, OneTapeBespokeGeometry.takeup] {
                    for step in 0..<36 {
                        let a = Double(step) * .pi / 18
                        let pt = OneTapeBespokeGeometry.point(center: center, radius: 46, angle: a)
                        if (center == OneTapeBespokeGeometry.supply && pt.x <= OneTapeBespokeGeometry.supply.x + 12) ||
                           (center == OneTapeBespokeGeometry.takeup && pt.x >= OneTapeBespokeGeometry.takeup.x - 12) {
                            var tick = Path()
                            tick.move(to: OneTapeBespokeGeometry.point(center: center, radius: 44.3, angle: a))
                            tick.addLine(to: OneTapeBespokeGeometry.point(center: center, radius: 47.4, angle: a))
                            context.stroke(tick, with: .color(.black.opacity(step.isMultiple(of: 3) ? 0.65 : 0.30)),
                                           lineWidth: step.isMultiple(of: 3) ? 0.65 : 0.35)
                        }
                    }
                }
                // Dark anodized side spec plate on right flank
                let badge = Path(roundedRect: CGRect(x: 244, y: 60, width: 22, height: 62), cornerRadius: 3)
                context.fill(badge, with: .color(Color(white: 0.08).opacity(0.75)))
                context.stroke(badge, with: .color(.white.opacity(0.18)), lineWidth: 0.6)
            }
            VStack(spacing: 2) {
                Text("A/B").font(.system(size: 7.5, weight: .bold))
                Text("SIDE").font(.custom("GeistMono-Regular", fixedSize: 5.0)).tracking(0.7)
            }
            .foregroundStyle(Color(white: 0.85))
            .position(x: 255, y: 91)
        }
    }

    private var lowerHeadCutoutAndHardware: some View {
        Canvas { context, _ in
            // Center magnetic head shield + bronze/felt pressure pad + guide openings
            let centerPad = Path(roundedRect: CGRect(x: 132, y: 162, width: 24, height: 15), cornerRadius: 2)
            context.fill(centerPad, with: .color(Color(white: 0.05)))
            context.fill(Path(CGRect(x: 135, y: 165, width: 18, height: 6)),
                         with: .color(Color(red: 0.56, green: 0.45, blue: 0.32)))

            for pt in OneTapeBespokeGeometry.bottomCapstans {
                context.fill(OneTapeBespokeGeometry.circle(center: pt, radius: 4.4), with: .color(Color(white: 0.03)))
                context.stroke(OneTapeBespokeGeometry.circle(center: pt, radius: 4.4),
                               with: .color(.white.opacity(style == .silverOval ? 0.5 : 0.16)), lineWidth: 0.5)
            }
            for pt in OneTapeBespokeGeometry.bottomGuides {
                let slot = Path(roundedRect: CGRect(x: pt.x - 4.5, y: pt.y - 3.6, width: 9, height: 7.2), cornerRadius: 1.5)
                context.fill(slot, with: .color(Color(white: 0.04)))
                context.stroke(slot, with: .color(.white.opacity(style == .silverOval ? 0.45 : 0.15)), lineWidth: 0.5)
            }
            for pt in OneTapeBespokeGeometry.screws {
                drawScrew(in: &context, center: pt)
            }
        }
    }

    private func drawScrew(in context: inout GraphicsContext, center: CGPoint) {
        let screwColor: Color = switch style {
        case .twinArc: Color(red: 0.78, green: 0.62, blue: 0.28)
        case .silverOval, .fieldNotes: Color(white: 0.76)
        default: Color(white: 0.28)
        }
        let body = OneTapeBespokeGeometry.circle(center: center, radius: 4.2)
        context.fill(body, with: .radialGradient(
            Gradient(colors: [screwColor.opacity(0.95), Color(white: 0.10)]),
            center: center, startRadius: 0.4, endRadius: 4.2))
        context.stroke(body, with: .color(.white.opacity(0.28)), lineWidth: 0.5)
        var slot = Path()
        slot.move(to: CGPoint(x: center.x - 2.1, y: center.y - 1.2))
        slot.addLine(to: CGPoint(x: center.x + 2.1, y: center.y + 1.2))
        context.stroke(slot, with: .color(.black.opacity(0.75)), lineWidth: 0.9)
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
