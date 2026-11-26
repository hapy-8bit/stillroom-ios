import SwiftUI

/// Reference-inspired high-resolution artwork, individually redrawn from the
/// thumbnail styles with added detail. These are not recovered original prints.
struct OneTapeDoodleArtwork: View {
    let appearance: OneTapeAppearance

    private var descriptor: (name: String, isPortraitTemplate: Bool)? {
        guard OneTapeDoodleCatalog.supports(appearance.doodleStyle, on: appearance.tapeStyle) else {
            return nil
        }
        return OneTapeDoodleCatalog.inkAsset(for: appearance.doodleStyle)
    }

    private var ink: Color {
        // Material-calibrated pad-print pigment tones so line art integrates
        // physically into each shell surface rather than floating flat on top.
        switch appearance.tapeStyle {
        case .classic:
            return Color(red: 0.11, green: 0.11, blue: 0.125)
        case .graphite:
            return Color(red: 0.93, green: 0.91, blue: 0.86)
        case .armature:
            return Color(red: 0.90, green: 0.91, blue: 0.93)
        case .fieldNotes:
            // Warm archival espresso ink on pressed oatmeal paper
            return Color(red: 0.19, green: 0.155, blue: 0.125)
        case .silverOval:
            // Laser-etched cool graphite on raw brushed aluminum
            return Color(red: 0.145, green: 0.165, blue: 0.195)
        case .twinArc:
            // Soft pearl-mist ivory harmonizing with muted Nordic slate-blue
            return Color(red: 0.91, green: 0.94, blue: 0.97)
        case .memphis:
            // Warm charcoal textile ink integrated into woven linen
            return Color(red: 0.17, green: 0.155, blue: 0.14)
        case .bronze:
            // Deep oxidized umber-bronze etched ink on satin champagne bronze
            return Color(red: 0.16, green: 0.13, blue: 0.095)
        case .window:
            return Color(red: 0.13, green: 0.13, blue: 0.145)
        case .clear:
            return Color(red: 0.94, green: 0.94, blue: 0.93)
        default:
            return appearance.tapeStyle.usesLightInk
                ? Color(red: 0.93, green: 0.91, blue: 0.87)
                : Color(red: 0.10, green: 0.10, blue: 0.11)
        }
    }

    private var inkOpacity: Double {
        switch appearance.tapeStyle {
        case .clear: 0.92
        case .classic, .graphite, .twinArc: 0.90
        case .fieldNotes, .bronze, .armature, .window: 0.88
        case .silverOval, .memphis: 0.86
        default: 0.90
        }
    }

    private var usesClassicShellLighting: Bool {
        appearance.tapeStyle == .classic || appearance.tapeStyle == .graphite || appearance.tapeStyle == .memphis
    }

    private var stencilSize: CGSize {
        // Logical print area matching the 1536×1024 landscape template alignment
        // with `OneTapeDoodleClassicMask` (artwork geometry, not screen pixels).
        CGSize(width: 622.973682, height: 415.315788)
    }

    var body: some View {
        Group {
            if let descriptor {
                printLayer(descriptor)
            }
        }
        .frame(width: 376.33, height: 576)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func printLayer(_ descriptor: (name: String, isPortraitTemplate: Bool)) -> some View {
        let isLight = appearance.tapeStyle.usesLightInk
        return ZStack(alignment: .topLeading) {
            // Subtle physical pad-print micro-relief catchlight beneath the pigment.
            (isLight ? Color.black.opacity(0.24) : Color.white.opacity(0.26))
                .frame(width: 376.33, height: 576)
                .mask { stencil(descriptor).foregroundStyle(.white) }
                .offset(x: isLight ? 0.35 : 0.3, y: isLight ? 0.45 : 0.4)
            ink
                .opacity(inkOpacity)
                .frame(width: 376.33, height: 576)
                .mask { stencil(descriptor).foregroundStyle(.white) }
            if usesClassicShellLighting {
                Image("OneTapeDoodleClassicLight")
                    .renderingMode(.original)
                    .resizable()
                    .frame(width: 376.33, height: 576)
                    // Tint source RGB before compositing. A blend filter
                    // across SwiftUI's mask/group boundary can expose the
                    // white lighting layer as luminous paint on iOS.
                    .colorMultiply(ink)
                    .opacity(0.32)
                    .mask { stencil(descriptor).foregroundStyle(.white) }
            } else {
                // Soft directional studio light falloff tailored to non-classic shells.
                LinearGradient(
                    colors: [
                        Color.white.opacity(isLight ? 0.10 : 0.08),
                        .clear,
                        Color.black.opacity(isLight ? 0.14 : 0.09)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 376.33, height: 576)
                .mask { stencil(descriptor).foregroundStyle(.white) }
            }
        }
        .compositingGroup()
        .mask {
            OneTapeShellPrintMask(tapeStyle: appearance.tapeStyle)
        }
    }

    @ViewBuilder
    private func stencil(_ descriptor: (name: String, isPortraitTemplate: Bool)) -> some View {
        // Logical points from the recovered 1.1036 × width, 1.5 aspect and
        // (-.0537 × width, -.0406 × height) source artwork transform.
        if descriptor.isPortraitTemplate {
            Image(descriptor.name)
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .frame(width: 415.315788, height: 622.973682)
                .position(x: 187.448973, y: 288.101241)
                .frame(width: 376.33, height: 576)
        } else {
            // The landscape recreation needs +90° inside the portrait tape.
            inkMask(descriptor.name)
                .frame(width: stencilSize.width, height: stencilSize.height)
                .rotationEffect(.degrees(90))
                .position(x: 187.448973, y: 288.101241)
                .frame(width: 376.33, height: 576)
        }
    }

    private func inkMask(_ asset: String) -> some View {
        Image(asset)
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            // Ink coverage is darkness × source alpha. Generated light fills
            // stay clear instead of turning into solid ink under a template tint.
            .colorInvert()
            .luminanceToAlpha()
            // Luminance-to-alpha replaces alpha on iOS. Restore source coverage
            // explicitly so the inverted transparent background cannot print.
            .mask {
                Image(asset)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
            }
    }
}

struct OneTapeShellPrintMask: View {
    let tapeStyle: OneTapeAppearance.TapeStyle

    var body: some View {
        if tapeStyle.isSculpted {
            OneTapeMouldPrintMask()
        } else if tapeStyle == .bronze {
            OneTapeBronzePrintMask().fill(.white)
        } else if tapeStyle.isBespoke {
            OneTapeBespokeWindowMask(style: tapeStyle)
                .fill(.white, style: FillStyle(eoFill: true))
        } else {
            // This reference mask is black/white and opaque; alpha
            // alone would incorrectly print over the spindle holes.
            Image("OneTapeDoodleClassicMask")
                .resizable()
                .frame(width: 376.33, height: 576)
                .luminanceToAlpha()
        }
    }
}

struct OneTapeCustomPrintLayer: View {
    let resolvedPrint: OneTapeResolvedPrint
    let tapeStyle: OneTapeAppearance.TapeStyle

    private var inkColor: Color {
        tapeStyle.usesLightInk ? Color(white: 0.90) : Color(white: 0.20)
    }

    var body: some View {
        Group {
            switch resolvedPrint.inkMode {
            case .tapeInk:
                Image(uiImage: resolvedPrint.image)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .foregroundStyle(inkColor)
            case .originalColors:
                Image(uiImage: resolvedPrint.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .frame(width: 376.33, height: 576)
        .clipped()
        .compositingGroup()
        .mask {
            OneTapeShellPrintMask(tapeStyle: tapeStyle)
        }
    }
}

