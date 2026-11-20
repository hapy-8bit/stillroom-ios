import SwiftUI

/// Material coordinates use logical points within the portrait cassette canvas.
/// Classic uses verified reference layers. Approved sculpted shells use text-free
/// photographic molding and separately turning drives. Legacy colored shells
/// remain native material studies, not recovered full-size reference packs.
struct OneTapeCassetteArtwork: View {
    let appearance: OneTapeAppearance
    var showsPrint = true
    var showsFineTexture = true
    var isFrosted = false
    var supplyAngle: Angle = .zero
    var takeupAngle: Angle = .zero
    var tapeProgress: Double = 0
    var reelExposureDegrees: Double = 0
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var customPrint: OneTapeResolvedPrint? = nil

    private let size = OneTapeCassetteStandard.portraitCanvasSize
    private let supply = OneTapeCassetteStandard.portraitSupplyCenter
    private let takeup = OneTapeCassetteStandard.portraitTakeupCenter

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                if appearance.tapeStyle == .clear {
                    OneTapeClearInteriorDeck(size: size)
                } else if appearance.tapeStyle == .window {
                    OneTapeWindowInteriorDeck(size: size)
                } else if appearance.tapeStyle != .bronze && !appearance.tapeStyle.isSculpted && !appearance.tapeStyle.isBespoke {
                    plate("OneTapeClassicStill")
                }
                material
            }
            .blur(radius: isFrosted && appearance.tapeStyle != .classic ? 1.8 : 0)
            // Multiply light instead of subtracting it: an additive brightness
            // reduction clips the already-dark graphite relief to solid black.
            .colorMultiply(isFrosted && appearance.tapeStyle != .classic ? Color(white: 0.82) : .white)
            if showsPrint {
                OneTapeBrandPrint(appearance: appearance, cassetteReadout: cassetteReadout, customPrint: customPrint)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder private var material: some View {
        switch appearance.tapeStyle {
        case .classic:
            mechanisms(exposed: false)
            plate("OneTapeClassicShell")
        case .graphite:
            mechanisms(exposed: false)
            plate("OneTapeClassicShell")
                .saturation(0.15)
                .colorMultiply(Color(white: 0.19))
                .contrast(1.08)
            graphiteRelief
        case .clear:
            mechanisms(exposed: true)
            OneTapeClearShellOverlay(size: size)
        case .window:
            mechanisms(exposed: true)
            OneTapeWindowShellOverlay(size: size, shellAssetName: materialAsset("OneTapeClassicShell"))
        case .memphis:
            mechanisms(exposed: false)
            OneTapeMemphisShell(size: size)
        case .bronze:
            OneTapeBronzeCassette(supplyAngle: supplyAngle, takeupAngle: takeupAngle,
                tapeProgress: tapeProgress, reelExposureDegrees: reelExposureDegrees,
                reelColor: appearance.reelColor)
        case .armature, .fieldNotes, .silverOval, .twinArc:
            OneTapeBespokeCassette(style: appearance.tapeStyle, supplyAngle: supplyAngle,
                takeupAngle: takeupAngle, tapeProgress: tapeProgress, reelExposureDegrees: reelExposureDegrees,
                reelColor: appearance.reelColor)
        case .strata, .facet, .islands, .ribs, .stream, .eclipse:
            OneTapeMouldedCassette(style: appearance.tapeStyle, supplyAngle: supplyAngle,
                takeupAngle: takeupAngle, tapeProgress: tapeProgress, reelExposureDegrees: reelExposureDegrees,
                showsFineTexture: showsFineTexture, reelColor: appearance.reelColor)
        }
    }

    private func plate(_ name: String) -> some View {
        Image(materialAsset(name))
            .resizable()
            .frame(width: size.width, height: size.height)
    }

    private func mechanisms(exposed: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            let radii = OneTapeTapeGeometry.radii(progress: tapeProgress)
            pack("OneTapeClassicPackSupply", radius: radii.supply, center: supply)
            pack("OneTapeClassicPackTakeup", radius: radii.takeup, center: takeup)
            if exposed {
                metalReel(center: supply)
                metalReel(center: takeup)
            }
            hub("OneTapeClassicSpinSupply", center: supply)
            hub("OneTapeClassicSpinTakeup", center: takeup)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func pack(_ name: String, radius: CGFloat, center: CGPoint) -> some View {
        // Asset pixels are resolved once by the catalog. The crop radius is a
        // physical tape-pack radius in logical points, independent of UI scale.
        Image(materialAsset(name))
            .resizable()
            .frame(width: 694 / 3, height: 694 / 3)
            .opacity(appearance.tapeStyle == .window ? 0.28 : 1)
            .mask(Circle().frame(width: radius * 2, height: radius * 2))
            .drawingGroup()
            .modifier(OneTapeReelExposure(angle: center == supply ? supplyAngle : takeupAngle,
                spread: reelExposureDegrees))
            .position(center)
    }

    private func hub(_ name: String, center: CGPoint) -> some View {
        let angle = center == supply ? supplyAngle : takeupAngle
        let diameter = OneTapeCassetteStandard.classicGearFrameDiameter
        return Group {
            if let reelColor = appearance.reelColor {
                OneTapeReelGearView(
                    color: reelColor,
                    diameter: diameter,
                    angle: angle,
                    reelExposureDegrees: reelExposureDegrees
                )
            } else {
                Image(materialAsset(name))
                    .resizable()
                    .frame(width: diameter, height: diameter)
                    .modifier(OneTapeReelExposure(angle: angle, spread: reelExposureDegrees))
            }
        }
        .position(center)
    }

    private func materialAsset(_ name: String) -> String {
        guard isFrosted, appearance.tapeStyle == .classic else { return name }
        switch name {
        case "OneTapeClassicStill": return "OneTapeCoverClassicStill"
        case "OneTapeClassicShell": return "OneTapeCoverClassicShell"
        case "OneTapeClassicSpinSupply": return "OneTapeCoverClassicSpinSupply"
        case "OneTapeClassicSpinTakeup": return "OneTapeCoverClassicSpinTakeup"
        case "OneTapeClassicPackSupply": return "OneTapeCoverClassicPackSupply"
        case "OneTapeClassicPackTakeup": return "OneTapeCoverClassicPackTakeup"
        default: return name
        }
    }

    private func metalReel(center: CGPoint) -> some View {
        OneTapeMetalReelView(diameter: 224)
            .modifier(OneTapeReelExposure(angle: center == supply ? supplyAngle : takeupAngle,
                spread: reelExposureDegrees))
            .position(center)
    }

    private var graphiteRelief: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .stroke(.black.opacity(0.8), lineWidth: 1)
                .shadow(color: .white.opacity(0.14), radius: 0, y: 0.8)
                .frame(width: 258, height: 405)
                .position(x: 216, y: 288)
            RoundedRectangle(cornerRadius: 3)
                .fill(.black.opacity(0.22))
                .overlay(alignment: .leading) {
                    Rectangle().fill(.white.opacity(0.08)).frame(width: 0.6)
                }
                .frame(width: 37, height: 312)
                .position(x: 71, y: 288)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Calibrated retro Memphis finish composited under neutralized `OneTapeClassicShell`
/// lighting so pastel rose plastic, off-white trapezoid, slate-teal grid, screws,
/// guide pins, and 77pt reel collars retain physical 3D molding without garish neon clipping.
private struct OneTapeMemphisShell: View {
    let size: CGSize

    // Pre-multiply colors compensate for `OneTapeClassicShell`'s ~0.84 midtone
    // luminance when multiplied on top, yielding matte pastel target hues.
    private let pinkBase = Color(red: 1.00, green: 0.835, blue: 0.865)
    private let creamTrapezoid = Color(red: 1.00, green: 0.992, blue: 0.965)
    private let mustardYellow = Color(red: 0.95, green: 0.84, blue: 0.34)
    private let stickerTeal = Color(red: 0.41, green: 0.73, blue: 0.78)
    private let gridGreen = Color(red: 0.27, green: 0.69, blue: 0.48)
    private let confettiInk = Color(white: 0.16).opacity(0.58)

    var body: some View {
        ZStack(alignment: .topLeading) {
            colorArtwork
                .mask {
                    OneTapeMemphisCutoutShape(
                        bounds: CGRect(x: 14, y: 13.7, width: 348, height: 548),
                        cornerRadius: 15.5
                    )
                    .fill(.white, style: FillStyle(eoFill: true))
                }
                // Intersect with `OneTapeClassicShell` alpha so the four trapezoid
                // guide holes punch cleanly through to `OneTapeClassicStill` underneath.
                .mask {
                    Image("OneTapeClassicShell")
                        .resizable()
                        .frame(width: size.width, height: size.height)
                }
            Image("OneTapeClassicShell")
                .resizable()
                .frame(width: size.width, height: size.height)
                .saturation(0.18)
                .blendMode(.multiply)
        }
        .frame(width: size.width, height: size.height)
        .drawingGroup()
    }

    private var colorArtwork: some View {
        ZStack(alignment: .topLeading) {
            pinkBase
            confettiLayer
            trapezoidBridge
            stickerLayer
        }
        .frame(width: size.width, height: size.height)
    }

    private var confettiLayer: some View {
        Canvas { context, _ in
            var strokes = Path()
            let screws: [CGPoint] = [
                CGPoint(x: 34.2, y: 36.1),
                CGPoint(x: 344.6, y: 35.5),
                CGPoint(x: 33.6, y: 540.4),
                CGPoint(x: 345.2, y: 541.2)
            ]
            for row in 0..<28 {
                for column in 0..<18 {
                    let seed = UInt64(row * 31 + column * 97 + 17)
                    let jx = hashUnit(seed &* 2654435761) * 9 - 4.5
                    let jy = hashUnit(seed &* 2246822519) * 9 - 4.5
                    let x = CGFloat(column) * 20 + 18 + jx
                    let y = CGFloat(row) * 20 + 14 + jy
                    let center = CGPoint(x: x, y: y)
                    // Keep screw recesses clean; trapezoid and sticker cover the interior.
                    if screws.contains(where: { hypot($0.x - center.x, $0.y - center.y) < 13 }) {
                        continue
                    }
                    let angle = hashUnit(seed &* 3266489917) * .pi
                    let half = 2.2 + hashUnit(seed &* 668265263) * 0.85
                    let dx = cos(angle) * half
                    let dy = sin(angle) * half
                    if (row + column).isMultiple(of: 4) {
                        let perpAngle = angle + 1.25
                        strokes.move(to: CGPoint(x: x - dx * 0.85, y: y - dy * 0.85))
                        strokes.addLine(to: center)
                        strokes.addLine(to: CGPoint(x: x + cos(perpAngle) * half,
                                                    y: y + sin(perpAngle) * half))
                    } else {
                        strokes.move(to: CGPoint(x: x - dx, y: y - dy))
                        strokes.addLine(to: CGPoint(x: x + dx, y: y + dy))
                    }
                }
            }
            context.stroke(strokes, with: .color(confettiInk),
                           style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round))
        }
    }

    private var trapezoidBridge: some View {
        ZStack {
            OneTapeMemphisTrapezoid(inset: 0)
                .fill(creamTrapezoid)
            Canvas { context, _ in
                var waves = Path()
                for xBase in [34.0, 57.0, 86.0] {
                    var started = false
                    for yStep in stride(from: 124.0, through: 452.0, by: 3.0) {
                        let wave = sin((yStep - 124.0) / 24.0) * 2.8
                        let pt = CGPoint(x: xBase + wave, y: yStep)
                        if !started {
                            waves.move(to: pt)
                            started = true
                        } else {
                            waves.addLine(to: pt)
                        }
                    }
                }
                context.stroke(waves, with: .color(mustardYellow),
                               style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
            }
            .clipShape(OneTapeMemphisTrapezoid(inset: 4))
        }
    }

    private var stickerLayer: some View {
        ZStack {
            stickerTeal
            Canvas { context, _ in
                var grid = Path()
                for xLine in stride(from: 111.0, through: 338.0, by: 22.5) {
                    var started = false
                    for yStep in stride(from: 42.0, through: 536.0, by: 6.0) {
                        let wob = sin((yStep - 42.0) / 32.0 + xLine * 0.1) * 0.65
                        let pt = CGPoint(x: xLine + wob, y: yStep)
                        if !started { grid.move(to: pt); started = true } else { grid.addLine(to: pt) }
                    }
                }
                for yLine in stride(from: 42.0, through: 536.0, by: 23.0) {
                    var started = false
                    for xStep in stride(from: 111.0, through: 338.0, by: 6.0) {
                        let wob = sin((xStep - 111.0) / 32.0 + yLine * 0.1) * 0.65
                        let pt = CGPoint(x: xStep, y: yLine + wob)
                        if !started { grid.move(to: pt); started = true } else { grid.addLine(to: pt) }
                    }
                }
                context.stroke(grid, with: .color(gridGreen),
                               style: StrokeStyle(lineWidth: 1.25, lineCap: .round))
                let accents = [CGPoint(x: 274, y: 119), CGPoint(x: 275, y: 336),
                               CGPoint(x: 143, y: 218), CGPoint(x: 136, y: 429)]
                for origin in accents {
                    let rect = CGRect(x: origin.x, y: origin.y, width: 9.5, height: 9.5)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(mustardYellow))
                }
            }
        }
        .mask {
            OneTapeMemphisCutoutShape(
                bounds: CGRect(x: 111, y: 42, width: 226, height: 492),
                cornerRadius: 5
            )
            .fill(.white, style: FillStyle(eoFill: true))
        }
    }

    private func hashUnit(_ value: UInt64) -> CGFloat {
        let mixed = (value ^ (value >> 13)) &* 1274126177
        return CGFloat((mixed ^ (mixed >> 16)) & 0xFFFF) / 65535.0
    }
}

/// Clips a Memphis outer contour (`shell` or `sticker`) while punching the two
/// 74pt reel collar openings and the 22×127pt central acrylic window cleanly.
private struct OneTapeMemphisCutoutShape: Shape {
    let bounds: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: bounds, cornerRadius: cornerRadius)
        for y in [OneTapeCassetteStandard.portraitSupplyCenter.y,
                  OneTapeCassetteStandard.portraitTakeupCenter.y] {
            path.addEllipse(in: CGRect(
                x: OneTapeCassetteStandard.portraitSupplyCenter.x - 37,
                y: y - 37,
                width: 74,
                height: 74
            ))
        }
        path.addRoundedRect(in: CGRect(x: 193, y: 224, width: 22, height: 127),
                            cornerSize: CGSize(width: 11, height: 11))
        return path
    }
}

private struct OneTapeMemphisTrapezoid: Shape {
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 14 + inset, y: 102 + inset * 1.4))
        path.addLine(to: CGPoint(x: 102 - inset, y: 121 + inset * 1.2))
        path.addLine(to: CGPoint(x: 102 - inset, y: 455 - inset * 1.2))
        path.addLine(to: CGPoint(x: 14 + inset, y: 474 - inset * 1.4))
        path.closeSubpath()
        return path
    }
}
