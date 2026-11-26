import SwiftUI
import UIKit

/// Renders a live, device-accurate Home Screen widget preview card inside
/// Settings using the exact same view hierarchy as the WidgetKit extension.
struct OneTapeWidgetPreview: View {
    typealias Size = OneTapeWidgetSize

    let size: OneTapeWidgetSize
    var snapshot: OneTapeWidgetSnapshot = .empty
    var artwork: UIImage? = nil
    var metrics: OneTapeWidgetMetrics = OneTapeWidgetMetrics.forScreen(width: 393, height: 852)
    var maxAvailableWidth: CGFloat? = nil
    var onTogglePlayback: () -> Void = {}
    var onNextTrack: () -> Void = {}

    var body: some View {
        let natural = metrics.size(for: size)
        let fitScale: CGFloat = {
            guard let maxAvailableWidth, maxAvailableWidth > 0, natural.width > maxAvailableWidth else {
                return 1
            }
            return maxAvailableWidth / natural.width
        }()
        let displaySize = CGSize(
            width: natural.width * fitScale,
            height: natural.height * fitScale
        )
        let cornerRadius = metrics.cornerRadius * fitScale

        ZStack {
            OneTapeWidgetBackground(snapshot: snapshot)
            OneTapeWidgetCardView(
                snapshot: snapshot,
                size: size,
                artwork: artwork,
                controlsMode: .callbacks(
                    onTogglePlayback: onTogglePlayback,
                    onNextTrack: onNextTrack
                )
            )
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.42), radius: 14, y: 8)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.09), lineWidth: 0.5)
        }
    }
}

/// Interactive hardware-catalog style showcase for Settings: replaces the old
/// mismatched-height horizontal scroll strip with a clean segmented switcher
/// (`小 | 中 | 大`), dark/light desktop preview toggle, and centered stage mat.
struct OneTapeWidgetSettingsShowcase: View {
    let snapshot: OneTapeWidgetSnapshot
    let artwork: UIImage?
    let screenSize: CGSize
    let onTogglePlayback: () -> Void
    let onNextTrack: () -> Void

    @State private var selectedSize: OneTapeWidgetSize = .medium
    @State private var previewDark = true
    @Namespace private var tabNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var metrics: OneTapeWidgetMetrics {
        OneTapeWidgetMetrics.forScreen(width: screenSize.width, height: screenSize.height)
    }

    private var sizeSpecText: String {
        switch selectedSize {
        case .small: "小 · 2×2"
        case .medium: "中 · 4×2"
        case .large: "大 · 4×4"
        }
    }

    private var interactiveHintText: String {
        switch selectedSize {
        case .small: "实时磁带计数"
        case .medium, .large: "可试按播控键"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerBar
            showcaseStage
            Text("在主屏幕上长按，然后轻点“编辑”>“添加小组件”。")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.34))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("小组件")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.42))
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            sizePicker

            Button {
                let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.22)
                withAnimation(animation) { previewDark.toggle() }
            } label: {
                Image(systemName: previewDark ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(previewDark ? .white.opacity(0.72) : Color(red: 0.94, green: 0.72, blue: 0.36))
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.06), in: Circle())
                    .overlay { Circle().strokeBorder(.white.opacity(0.08), lineWidth: 0.5) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(previewDark ? "当前深色小组件预览，轻点切换浅色" : "当前浅色小组件预览，轻点切换深色")
            .accessibilityIdentifier("settings.widget.themeToggle")
        }
    }

    private var sizePicker: some View {
        HStack(spacing: 2) {
            ForEach(OneTapeWidgetSize.allCases, id: \.rawValue) { size in
                let active = selectedSize == size
                Button {
                    guard selectedSize != size else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.55)
                    let animation: Animation? = reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.84)
                    withAnimation(animation) { selectedSize = size }
                } label: {
                    Text(size.title)
                        .font(.system(size: 12, weight: active ? .semibold : .medium))
                        .foregroundStyle(.white.opacity(active ? 0.94 : 0.48))
                        .frame(width: 34, height: 26)
                        .background {
                            if active {
                                Capsule()
                                    .fill(.white.opacity(0.14))
                                    .matchedGeometryEffect(id: "widgetSizePill", in: tabNamespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.widget.tab.\(size.rawValue)")
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(2)
        .background(.white.opacity(0.045), in: Capsule())
        .overlay { Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5) }
    }

    private var showcaseStage: some View {
        let availableWidth = max(240, screenSize.width - 40 - 28)
        let cardHeight: CGFloat = {
            let natural = metrics.size(for: selectedSize)
            let scale = natural.width > availableWidth ? availableWidth / natural.width : 1
            return natural.height * scale
        }()

        return VStack(spacing: 14) {
            ZStack {
                RadialGradient(
                    colors: [
                        (previewDark ? Color.white : Color(red: 0.95, green: 0.86, blue: 0.72))
                            .opacity(previewDark ? 0.055 : 0.09),
                        .clear
                    ],
                    center: .center,
                    startRadius: 12,
                    endRadius: 170
                )

                OneTapeWidgetPreview(
                    size: selectedSize,
                    snapshot: snapshot,
                    artwork: artwork,
                    metrics: metrics,
                    maxAvailableWidth: availableWidth,
                    onTogglePlayback: onTogglePlayback,
                    onNextTrack: onNextTrack
                )
                .environment(\.colorScheme, previewDark ? .dark : .light)
                .id(selectedSize)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                .accessibilityIdentifier("settings.widget.\(selectedSize.rawValue)")
                .accessibilityElement(children: selectedSize == .small ? .combine : .contain)
                .accessibilityLabel(snapshot.previewAccessibilityLabel(size: selectedSize))
            }
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight + 12)

            HStack {
                Text(sizeSpecText)
                    .font(.custom("GeistMono-Regular", fixedSize: 10))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.46))
                Spacer()
                Text(interactiveHintText)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.36))
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity)
        .background(
            Color.white.opacity(0.032),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.075), lineWidth: 0.5)
        }
    }
}

struct OneTapeTapeThumbnail: View {
    var tilt: Double = 0
    var appearance = OneTapeAppearance()
    var showsPrint = true
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var customPrint: OneTapeResolvedPrint? = nil

    var body: some View {
        GeometryReader { geometry in
            // The reference-preview layers share a portrait canvas. The
            // thumbnail intentionally turns that canvas onto its long edge.
            let portraitWidth = min(geometry.size.height, geometry.size.width / (1728.0 / 1129.0))
            OneTapeCassetteArtwork(appearance: appearance, showsPrint: showsPrint, showsFineTexture: false,
                cassetteReadout: cassetteReadout, customPrint: customPrint)
            .frame(width: 376.33, height: 576)
            .scaleEffect(portraitWidth / 376.33)
            .rotationEffect(.degrees(-90 + tilt))
            .shadow(color: .black.opacity(0.4), radius: 10, y: 8)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
