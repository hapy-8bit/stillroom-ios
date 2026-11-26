import SwiftUI

/// Lettering is live vector text on the cassette's logical artwork canvas.
/// It replaces the reference wordmark without repainting the plastic texture.
struct OneTapeBrandPrint: View {
    let appearance: OneTapeAppearance
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var customPrint: OneTapeResolvedPrint? = nil
    var tilt: CGSize = OneTapeTiltMonitor.restingTilt

    @ViewBuilder var body: some View {
        legacyBody
    }

    private var ink: Color {
        appearance.tapeStyle.usesLightInk ? Color(white: 0.90) : Color(white: 0.20)
    }

    private var legacyBody: some View {
        ZStack(alignment: .topLeading) {
            if appearance.tapeFoilStyle != nil {
                OneTapeHoloFoilOverlay(appearance: appearance, tilt: tilt)
            }
            if appearance.trackListEnabled {
                OneTapeTrackListPrint(appearance: appearance, readout: cassetteReadout)
            } else if appearance.isBrandPrintVisible {
                Text("A")
                    .font(.system(size: 21, weight: .light, design: .serif))
                    .rotationEffect(.degrees(90))
                    .position(x: 329, y: 62)
                // Printed artwork keeps logical-point typography independent
                // from Dynamic Type; the separate player controls stay accessible.
                Text("One Cassette")
                    .font(.custom("RacingSansOne-Regular", fixedSize: 46))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 360, height: 62)
                    .rotationEffect(.degrees(90))
                    .position(x: 307, y: 292)
                lettering("YOUR MUSIC, ONE CASSETTE", size: 7.5, tracking: 1.1, x: 270, y: 292)
                lettering("C60", size: 14, tracking: 0.7,
                    x: appearance.tapeStyle == .bronze ? 251 : 227, y: 292)
                if appearance.tapeStyle == .bronze {
                    // The wedge occupies the old center label lane. Put the
                    // small imprint on the closed right panel instead of glass.
                    lettering("ONE CASSETTE", size: 8.5, tracking: 1.5, x: 204, y: 486)
                } else {
                    Text("ONE CASSETTE")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .tracking(3.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 280, height: 24)
                        .rotationEffect(.degrees(90))
                        .position(x: 164, y: 292)
                }
                lettering("A SIDE FOR EVERY DAY", size: 7.5, tracking: 0.9, x: 131, y: 292)
                lettering("PRESS PLAY · STAY A WHILE", size: 7.5, tracking: 0.6, x: 121, y: 292)
            }
            if let customPrint {
                OneTapeCustomPrintLayer(resolvedPrint: customPrint, tapeStyle: appearance.tapeStyle)
            } else if appearance.doodleStyle != .none {
                OneTapeDoodleArtwork(appearance: appearance)
            }
        }
        .foregroundStyle(ink)
        .frame(width: 376.33, height: 576)
        .mask {
            if appearance.tapeStyle == .bronze {
                OneTapeBronzePrintMask().fill(.white)
            } else {
                Color.white
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func lettering(_ text: String, size: CGFloat, tracking: CGFloat,
                           x: CGFloat, y: CGFloat) -> some View {
        Text(text).font(.custom("GeistMono-Regular", size: size)).tracking(tracking)
            .frame(width: 280, height: 16)
            .rotationEffect(.degrees(90))
            .position(x: x, y: y)
    }
}

/// Leaf observer so 30Hz tilt updates only re-render the foil/print layer.
struct OneTapeLiveBrandPrint: View {
    let appearance: OneTapeAppearance
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var customPrint: OneTapeResolvedPrint? = nil
    @ObservedObject var tiltMonitor: OneTapeTiltMonitor

    var body: some View {
        OneTapeBrandPrint(
            appearance: appearance,
            cassetteReadout: cassetteReadout,
            customPrint: customPrint,
            tilt: tiltMonitor.tilt
        )
    }
}
