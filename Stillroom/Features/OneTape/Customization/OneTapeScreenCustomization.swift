import SwiftUI

/// Pinned live reflective LCD preview header displayed above the scrollable
/// screen-category picker so every tap updates visibly right above the chips.
struct OneTapeScreenPreviewHeader: View {
    let appearance: OneTapeAppearance
    var readout: OneTapePlaybackReadout = .empty
    var visualization: AudioVisualizationSignal? = nil

    private var lcdMaterial: OneTapeLCDMaterial {
        OneTapeLCDMaterial(appearance: appearance)
    }

    var body: some View {
        VStack(spacing: 8) {
            OneTapeDisplay(
                style: appearance.screenStyle,
                readout: readout,
                visualization: visualization,
                lcdMaterial: lcdMaterial,
                isPreview: true
            )
            .scaleEffect(0.68)
            .frame(width: 264.39 * 0.68, height: 165.63 * 0.68)
            .padding(6)
            .background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 0.8)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            Text(appearance.screenStyle.resolvedStyle.customizationDescription)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Unified 5-category screen customization picker aligned with Cassette 1.0.5's
/// reflective monochrome LCD screen taxonomy.
struct OneTapeScreenCustomization: View {
    @Binding var appearance: OneTapeAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(OneTapeScreenCategory.allCases) { category in
                VStack(alignment: .leading, spacing: 9) {
                    sectionHeader(category.title, subtitle: category.subtitle)
                    OneTapeChipFlow(spacing: 8) {
                        ForEach(category.activeStyles) { style in
                            screenChip(style)
                        }
                    }
                }
            }
        }
    }

    private func screenChip(_ style: OneTapeAppearance.ScreenStyle) -> some View {
        OneTapeCustomizationChip(
            title: style.customizationTitle,
            selected: appearance.screenStyle.resolvedStyle == style,
            studioMarker: style != .lcd
        ) {
            appearance.screenStyle = style
        }
        .accessibilityIdentifier("customization.screen.\(style.rawValue)")
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.76))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
        }
    }
}
