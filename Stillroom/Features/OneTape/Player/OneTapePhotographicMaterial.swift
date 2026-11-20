import SwiftUI

/// Native photographic study. The root owns visual seconds and play/lifecycle
/// policy. This view introduces no clock, PCM subscription or persistent state.
struct OneTapePhotographicMaterial: View {
    let style: OneTapeAppearance.ScreenStyle
    let phase: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        // Read before the delayed Canvas closure so phase and Reduce Motion
        // register as body dependencies even when no audio publisher is active.
        let seconds = reduceMotion || !phase.isFinite ? 0 : max(0, phase)
        let selectedStyle = style
        let scale = displayScale
        Group {
            if style == .fluid {
                approvedFluid(seconds: seconds, displayScale: scale)
            } else {
                GeometryReader { geometry in
                    if let asset {
                        ZStack {
                            Image(asset)
                                .renderingMode(.original)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                            if seconds > 0 {
                                Canvas(rendersAsynchronously: true) { context, size in
                                    guard let frame = OneTapeMaterialRasterizer.render(
                                        style: selectedStyle, phase: seconds, size: size, displayScale: scale
                                    ) else { return }
                                    context.draw(Image(decorative: frame, scale: 1, orientation: .up)
                                        .interpolation(.high), in: CGRect(origin: .zero, size: size))
                                }
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Portrait fluid has its own composition, rather than stretching the wide
    /// photograph over the text. The material still receives the parent's phase.
    private func approvedFluid(seconds: Double, displayScale: CGFloat) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let layout = OneTapeScreenLayoutGeometry(size: size)
            let artHeight = size.height * layout.mix(1, 0.82)
            let coverScale = max(size.width / 1200, artHeight / 750) * 1.015
            let photoSize = CGSize(width: 1200 * coverScale, height: 750 * coverScale)
            let focus = layout.mix(0.50, 0.60) + sin(seconds / 5) * 0.004
            let photoRect = CGRect(x: (size.width - photoSize.width) * focus,
                                   y: (artHeight - photoSize.height) / 2,
                                   width: photoSize.width, height: photoSize.height)
            let dark = Color(red: 5 / 255.0, green: 7 / 255.0, blue: 7 / 255.0)
            ZStack(alignment: .topLeading) {
                dark
                ZStack(alignment: .topLeading) {
                    Image("OneTapeScreenFluidPhoto")
                        .resizable().interpolation(.high)
                        .frame(width: photoSize.width, height: photoSize.height)
                        .offset(x: photoRect.minX, y: photoRect.minY)
                    if seconds > 0 {
                        Canvas(rendersAsynchronously: true) { context, _ in
                            if let frame = OneTapeMaterialRasterizer.render(style: .fluid, phase: seconds,
                                size: photoSize, displayScale: displayScale) {
                                context.draw(Image(decorative: frame, scale: 1), in: photoRect)
                            }
                        }
                        .frame(width: size.width, height: artHeight)
                    }
                }
                .frame(width: size.width, height: artHeight, alignment: .topLeading)
                .clipped()
                LinearGradient(stops: [.init(color: dark.opacity(0), location: 0.40),
                    .init(color: dark.opacity(220 / 255.0), location: 0.7168),
                    .init(color: dark, location: 0.88)], startPoint: .top, endPoint: .bottom)
                    .opacity(Double(layout.tallFraction))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    private var asset: String? {
        switch style {
        case .dunes: "OneTapeScreenDunesPhoto"
        case .iron: "OneTapeScreenIronPhoto"
        case .fluid: "OneTapeScreenFluidPhoto"
        default: nil
        }
    }
}
