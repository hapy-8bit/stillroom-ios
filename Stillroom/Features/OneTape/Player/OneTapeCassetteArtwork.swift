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

/// Restrained architectural woven-linen shell (亚麻) composited under
/// neutralized `OneTapeClassicShell` lighting so the warm oatmeal flax weave,
/// quiet sand head-bridge, real screws and 77pt hub collars keep authentic 3D depth.
private struct OneTapeMemphisShell: View {
    let size: CGSize

    // Pre-compensated bright warm linen tones so multiplying `OneTapeClassicShell`
    // (~0.84 midtone) yields a calm natural oatmeal fabric finish.
    private let linenBase = Color(red: 0.99, green: 0.96, blue: 0.90)
    private let bridgeSand = Color(red: 0.95, green: 0.92, blue: 0.85)

    var body: some View {
        ZStack(alignment: .topLeading) {
            linenArtwork
                .mask {
                    OneTapeLinenCutoutShape(
                        bounds: CGRect(x: 14, y: 13.7, width: 348, height: 548),
                        cornerRadius: 15.5
                    )
                    .fill(.white, style: FillStyle(eoFill: true))
                }
                .mask {
                    Image("OneTapeClassicShell")
                        .resizable()
                        .frame(width: size.width, height: size.height)
                }
            Image("OneTapeClassicShell")
                .resizable()
                .frame(width: size.width, height: size.height)
                .saturation(0.16)
                .blendMode(.multiply)
        }
        .frame(width: size.width, height: size.height)
        .drawingGroup()
    }

    private var linenArtwork: some View {
        ZStack(alignment: .topLeading) {
            linenBase
            Canvas { context, _ in
                // Fine tactile warp and weft linen threads with soft organic slub variation.
                for col in 0..<150 {
                    let x = 14 + CGFloat(col) * (348.0 / 150.0)
                    let n = hashUnit(UInt64(col * 37 + 11))
                    var warp = Path()
                    warp.move(to: CGPoint(x: x, y: 14))
                    warp.addLine(to: CGPoint(x: x, y: 562))
                    let tint: Color = n > 0.52
                        ? .white.opacity(0.14 * n)
                        : Color(red: 0.48, green: 0.41, blue: 0.31).opacity(0.055 + 0.05 * n)
                    context.stroke(warp, with: .color(tint), lineWidth: n > 0.86 ? 1.0 : 0.55)
                }
                for row in 0..<240 {
                    let y = 14 + CGFloat(row) * (548.0 / 240.0)
                    let n = hashUnit(UInt64(row * 53 + 29))
                    var weft = Path()
                    weft.move(to: CGPoint(x: 14, y: y))
                    weft.addLine(to: CGPoint(x: 362, y: y))
                    let tint: Color = n > 0.48
                        ? Color(red: 1.0, green: 0.99, blue: 0.95).opacity(0.14 * n)
                        : Color(red: 0.44, green: 0.37, blue: 0.27).opacity(0.05 + 0.05 * n)
                    context.stroke(weft, with: .color(tint), lineWidth: n > 0.88 ? 1.05 : 0.55)
                }
                // Subtle warm woven border accent around the main label plane.
                let labelBorder = Path(roundedRect: CGRect(x: 112, y: 42, width: 224, height: 492), cornerRadius: 5)
                context.stroke(labelBorder,
                               with: .color(Color(red: 0.50, green: 0.43, blue: 0.34).opacity(0.16)),
                               lineWidth: 0.9)
            }
            OneTapeLinenTrapezoid(inset: 0)
                .fill(bridgeSand.opacity(0.75))
            OneTapeLinenTrapezoid(inset: 0.5)
                .stroke(Color(red: 0.46, green: 0.40, blue: 0.32).opacity(0.18), lineWidth: 0.8)
        }
        .frame(width: size.width, height: size.height)
    }

    private func hashUnit(_ value: UInt64) -> CGFloat {
        let mixed = (value ^ (value >> 13)) &* 1274126177
        return CGFloat((mixed ^ (mixed >> 16)) & 0xFFFF) / 65535.0
    }
}

private struct OneTapeLinenCutoutShape: Shape {
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

private struct OneTapeLinenTrapezoid: Shape {
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
