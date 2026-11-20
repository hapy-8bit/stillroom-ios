import SwiftUI

struct OneTapeScreenCustomization: View {
    @Binding var appearance: OneTapeAppearance
    var readout: OneTapePlaybackReadout = .empty
    var visualization: AudioVisualizationSignal? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            livePreview
            Text("选择屏幕的材质与动效")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .center)
            sectionTitle("屏幕")
            OneTapeChipFlow(spacing: 8) {
                ForEach(OneTapeScreenAvailability.selectableStyles.filter {
                    $0 != .fox && !extensions.contains($0)
                }) { style in
                    screenChip(style)
                }
            }
            Text(appearance.screenStyle.resolvedStyle.customizationDescription)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)
            sectionTitle("扩展")
            OneTapeChipFlow(spacing: 8) {
                ForEach(extensions) { style in screenChip(style) }
            }
            sectionTitle("角色")
            OneTapeChipFlow(spacing: 8) {
                screenChip(.fox)
            }
        }
    }

    private var extensions: [OneTapeAppearance.ScreenStyle] { [.rain, .trails] }

    private var livePreview: some View {
        OneTapeDisplay(style: appearance.screenStyle, readout: readout,
                       visualization: visualization)
            .scaleEffect(0.65)
            .frame(width: 171.85, height: 107.66)
            .padding(8)
            .background(Color(white: 0.035), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(.white.opacity(0.13), lineWidth: 0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))
            .accessibilityAddTraits(.isHeader)
    }
}
