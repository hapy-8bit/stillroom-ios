import SwiftUI

/// Approved sculptural shell, hidden tape and collars are fixed. Only drive cores
/// receive the player's existing phase; no media time is inferred from artwork.
struct OneTapeMouldedCassette: View {
    let style: OneTapeAppearance.TapeStyle
    var supplyAngle: Angle = .zero
    var takeupAngle: Angle = .zero
    var tapeProgress: Double = 0
    var reelExposureDegrees: Double = 0
    var showsFineTexture = true
    var reelColor: OneTapeAppearance.ReelColor? = nil

    private var geometry: OneTapeMouldGeometry { OneTapeMouldGeometry(style: style) }

    var body: some View {
        let radii = OneTapeTapeGeometry.radii(progress: tapeProgress)
        OneTapeMouldPortrait {
            ZStack(alignment: .topLeading) {
                Color(red: 0.12, green: 0.11, blue: 0.09)
                    .frame(width: OneTapeMouldGeometry.size.width, height: OneTapeMouldGeometry.size.height)

                tapePacks(radii: radii)

                shellSurface

                if geometry.hasTapeWindow {
                    geometry.slotsPath
                        .stroke(LinearGradient(colors: [
                            Color.black.opacity(0.55),
                            Color.white.opacity(0.25)
                        ], startPoint: .top, endPoint: .bottom), lineWidth: 1.0)
                }

                drive(index: 0, angle: supplyAngle)
                drive(index: 1, angle: takeupAngle)
            }
            .frame(width: OneTapeMouldGeometry.size.width, height: OneTapeMouldGeometry.size.height)
            .mask { geometry.outline.fill(.white) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func tapePacks(radii: (supply: Double, takeup: Double)) -> some View {
        ZStack(alignment: .topLeading) {
            if geometry.axles.count >= 2 {
                let packScale = geometry.packScale
                let supplyRadius = CGFloat(radii.supply) * packScale
                let takeupRadius = CGFloat(radii.takeup) * packScale

                tapeRibbon(supplyRadius: supplyRadius, takeupRadius: takeupRadius)

                OneTapeMouldTapePack(radius: supplyRadius)
                    .position(geometry.axles[0])

                OneTapeMouldTapePack(radius: takeupRadius)
                    .position(geometry.axles[1])
            }
        }
    }

    private func tapeRibbon(supplyRadius: CGFloat, takeupRadius: CGFloat) -> some View {
        Canvas { context, _ in
            guard geometry.axles.count >= 2 else { return }
            let p0 = geometry.axles[0]
            let p1 = geometry.axles[1]
            let ribbonHeight: CGFloat = 16
            let yMid = (p0.y + p1.y) / 2
            let xStart = p0.x
            let xEnd = p1.x
            let rect = CGRect(x: xStart, y: yMid - ribbonHeight / 2,
                              width: xEnd - xStart, height: ribbonHeight)
            context.fill(Path(rect), with: .color(Color(red: 0.18, green: 0.16, blue: 0.14)))
            context.stroke(Path(rect), with: .color(Color.black.opacity(0.3)), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var shellSurface: some View {
        if geometry.hasTapeWindow {
            OneTapeMouldedSurface(style: style, showsFineTexture: showsFineTexture).equatable()
                .mask {
                    geometry.outline
                        .subtracting(geometry.slotsPath, eoFill: false)
                        .fill(.white)
                }
        } else {
            OneTapeMouldedSurface(style: style, showsFineTexture: showsFineTexture).equatable()
        }
    }

    private func drive(index: Int, angle: Angle) -> some View {
        let diameter = geometry.hubRadii[index] * 2
        let shaftDiameter = geometry.shaftRadii[index] * 2
        return ZStack {
            // A complete opaque circular sample covers the baked pose at every
            // angle; the collar and the now-covered tape remain in the shell.
            Image(geometry.asset + "Drive" + String(index))
                .resizable()
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .modifier(OneTapeReelExposure(angle: angle, spread: reelExposureDegrees))
                .clipShape(Circle())

            if let reelColor {
                OneTapeReelGearView(
                    color: reelColor,
                    diameter: diameter,
                    angle: angle,
                    reelExposureDegrees: reelExposureDegrees,
                    showsOuterBezel: false,
                    showsAxlePin: false,
                    gearOuterRadiusFraction: 1.0
                )
            }

            // Keep the shaft's directional metal highlight stationary instead
            // of baking its reflection into the rotating tooth texture.
            Image(geometry.asset + "Shaft" + String(index))
                .resizable()
                .frame(width: shaftDiameter, height: shaftDiameter)
                .clipShape(Circle())
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(x: geometry.driveStretch.width, y: geometry.driveStretch.height)
        .position(geometry.axles[index])
    }

}

/// The picker uses the same fixed mechanism and molding as the player.
struct OneTapeMouldedThumbnail: View {
    let style: OneTapeAppearance.TapeStyle

    var body: some View {
        GeometryReader { proxy in
            OneTapeMouldedCassette(style: style, showsFineTexture: false)
                .rotationEffect(.degrees(-90))
                .frame(width: OneTapeMouldGeometry.size.width, height: OneTapeMouldGeometry.size.height)
                .scaleEffect(proxy.size.width / OneTapeMouldGeometry.size.width)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(OneTapeMouldGeometry.size, contentMode: .fit)
    }
}

struct OneTapeMouldedPrint: View {
    let appearance: OneTapeAppearance
    var readout: OneTapeCassetteReadout = .empty
    var customPrint: OneTapeResolvedPrint? = nil

    private var geometry: OneTapeMouldGeometry { OneTapeMouldGeometry(style: appearance.tapeStyle) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let customPrint {
                OneTapeCustomPrintLayer(resolvedPrint: customPrint, tapeStyle: appearance.tapeStyle)
            } else if appearance.doodleStyle != .none {
                OneTapeDoodleArtwork(appearance: appearance)
            }
            OneTapeMouldPortrait {
                ZStack(alignment: .topLeading) {
                    if appearance.isBrandPrintVisible {
                        Text("One Cassette")
                            .font(.custom("InstrumentSerif-Italic", fixedSize: geometry.wordRect.height * 1.15))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(width: geometry.wordRect.width, height: geometry.wordRect.height)
                            .position(x: geometry.wordRect.midX, y: geometry.wordRect.midY)
                    }
                    // Move text out of the shared illustration canvas rather
                    // than cutting a different caption-shaped hole in its ink.
                    metadata(readout.durationLabel,
                        caption: readout.trackCount == 0 ? "EMPTY" : readout.durationSeconds == nil ? "UNKNOWN" : "TOTAL",
                        rect: appearance.isBrandPrintVisible ? geometry.durationRect
                            : OneTapeMouldGeometry.illustrationDurationRect)
                    metadata(String(readout.trackCount), caption: "TRACKS",
                        rect: appearance.isBrandPrintVisible ? geometry.countRect
                            : OneTapeMouldGeometry.illustrationCountRect)
                }
                .foregroundStyle(geometry.ink)
                .frame(width: OneTapeMouldGeometry.size.width, height: OneTapeMouldGeometry.size.height)
            }
        }
        .frame(width: 376.33, height: 576)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func metadata(_ value: String, caption: String, rect: CGRect) -> some View {
        Group {
            if rect.height < 27 {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    number(value, size: min(20, rect.height * 0.86))
                    Text(caption).font(.custom("GeistMono-Regular", fixedSize: 7)).tracking(0.6)
                }
            } else {
                VStack(spacing: 2) {
                    number(value, size: min(22, rect.height * 0.58))
                    Text(caption).font(.custom("GeistMono-Regular", fixedSize: 7.5)).tracking(1.2)
                }
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    private func number(_ value: String, size: CGFloat) -> some View {
        Text(value)
            .font(.custom("DMMono-Regular", fixedSize: size))
            .lineLimit(1)
            .minimumScaleFactor(0.42)
    }
}

struct OneTapeMouldPrintMask: View {
    private static let clips: [(outline: Path, exclusions: [Path])] =
        OneTapeAppearance.TapeStyle.sculpted.map { style in
            let geometry = OneTapeMouldGeometry(style: style)
            return (geometry.outline, [geometry.windows, geometry.guidePorts, geometry.headRail])
        }

    var body: some View {
        OneTapeMouldPortrait {
            Canvas { context, size in
                context.clip(to: Path(roundedRect: OneTapeMouldGeometry.frameRect
                    .insetBy(dx: 10, dy: 10), cornerRadius: 14))
                // All styles use exactly these same cached clips. Keep each
                // exclusion separate: boolean operations on coincident shell
                // contours can reopen overlapping holes on iOS.
                for clip in Self.clips {
                    context.clip(to: clip.outline)
                    for exclusion in clip.exclusions {
                        context.clip(to: exclusion, options: .inverse)
                    }
                }
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            }
        }
    }
}

private struct OneTapeMouldTapePack: View {
    let radius: CGFloat

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                               width: radius * 2, height: radius * 2))
            context.fill(circle, with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.22, green: 0.19, blue: 0.16),
                    Color(red: 0.29, green: 0.25, blue: 0.21),
                    Color(red: 0.18, green: 0.16, blue: 0.14)
                ]),
                center: center, startRadius: 10, endRadius: max(12, radius)))
            for index in 1..<24 {
                let ringRadius = 12 + max(0, radius - 12) * CGFloat(index) / 24
                let ring = Path(ellipseIn: CGRect(x: center.x - ringRadius, y: center.y - ringRadius,
                                                  width: ringRadius * 2, height: ringRadius * 2))
                context.stroke(ring,
                               with: .color(.black.opacity(index.isMultiple(of: 3) ? 0.12 : 0.045)),
                               lineWidth: 0.35)
            }
            context.stroke(circle, with: .color(.black.opacity(0.30)), lineWidth: 0.6)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

