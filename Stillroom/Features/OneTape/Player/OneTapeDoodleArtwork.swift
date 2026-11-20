import SwiftUI

/// Reference-inspired high-resolution artwork, individually redrawn from the
/// thumbnail styles with added detail. These are not recovered original prints.
struct OneTapeDoodleArtwork: View {
    let appearance: OneTapeAppearance

    private var descriptor: (name: String, isPortraitTemplate: Bool)? {
        OneTapeDoodleCatalog.inkAsset(for: appearance.doodleStyle)
    }

    private var ink: Color {
        // Recovered from Cassette DoodleLayer (0x1001e3bdc):
        // dark shells use warm cream (0.93, 0.91, 0.87), light shells use near-black (0.10, 0.10, 0.11).
        appearance.tapeStyle.usesLightInk
            ? Color(red: 0.93, green: 0.91, blue: 0.87)
            : Color(red: 0.10, green: 0.10, blue: 0.11)
    }

    private var stencilSize: CGSize {
        // The botanical redraw fills its source canvas, unlike the thumbnail's
        // template margins. Inset its logical print area to keep both birds' heads
        // inside the physical mask; this is artwork geometry, not screen pixels.
        appearance.doodleStyle == .wild
            ? CGSize(width: 528, height: 352)
            : CGSize(width: 622.973682, height: 415.315788)
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
        ZStack(alignment: .topLeading) {
            ink
                .frame(width: 376.33, height: 576)
                .mask { stencil(descriptor).foregroundStyle(.white) }
            if !appearance.tapeStyle.isSculpted {
                Image("OneTapeDoodleClassicLight")
                    .renderingMode(.original)
                    .resizable()
                    .frame(width: 376.33, height: 576)
                    // Tint source RGB before compositing. A blend filter
                    // across SwiftUI's mask/group boundary can expose the
                    // white lighting layer as luminous paint on iOS.
                    .colorMultiply(ink)
                    .opacity(0.35)
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

