import SwiftUI

/// Surface-effects rows at the bottom of the Print tab, aligned with Cassette 1.0.5:
/// Glass (已关闭 / 已打开), Brand print (关 / 开), Foil (关 / Holo), and Track list (关 / 开).
struct OneTapeSurfaceEffectsSection: View {
    @Binding var appearance: OneTapeAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("表面效果")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.60))
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 12) {
                effectRow(title: "玻璃", identifier: "customization.glass") {
                    pillToggle(
                        leftTitle: "已关闭",
                        rightTitle: "已打开",
                        isRightSelected: appearance.glassOpen,
                        rightStudioDot: false
                    ) { open in
                        appearance.glassOpen = open
                    }
                }

                effectRow(title: "品牌印字", identifier: "customization.brandPrint") {
                    pillToggle(
                        leftTitle: "关",
                        rightTitle: "开",
                        isRightSelected: appearance.isBrandPrintVisible,
                        rightStudioDot: false
                    ) { visible in
                        var next = appearance
                        next.setBrandPrintVisible(visible)
                        appearance = next
                    }
                }

                effectRow(title: "Foil", identifier: "customization.foil") {
                    pillToggle(
                        leftTitle: "关",
                        rightTitle: "Holo",
                        isRightSelected: appearance.tapeFoilStyle == .holo,
                        rightStudioDot: true
                    ) { enabled in
                        var next = appearance
                        next.tapeFoilStyle = enabled ? .holo : nil
                        appearance = next
                    }
                }

                effectRow(title: "Track list", identifier: "customization.trackList") {
                    pillToggle(
                        leftTitle: "关",
                        rightTitle: "开",
                        isRightSelected: appearance.trackListEnabled,
                        rightStudioDot: true
                    ) { enabled in
                        var next = appearance
                        next.setTrackListEnabled(enabled)
                        appearance = next
                    }
                }
            }

            if appearance.trackListEnabled {
                Text("曲目表会直接印在磁带正面并高亮当前播放歌曲；开启品牌印字或选择印花会替换曲目表。")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            } else if appearance.doodleStyle != .none
                || appearance.customDrawingID != nil
                || appearance.customArtworkID != nil {
                Text("开启品牌印字或 Track list 会替换当前插画；Foil 镭射箔可与任意印花叠加。")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func effectRow<Control: View>(
        title: String,
        identifier: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
            Spacer(minLength: 8)
            control()
                .accessibilityIdentifier(identifier)
        }
        .frame(minHeight: 40)
    }

    private func pillToggle(
        leftTitle: String,
        rightTitle: String,
        isRightSelected: Bool,
        rightStudioDot: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 2) {
            pillButton(title: leftTitle, selected: !isRightSelected, studioDot: false) {
                if isRightSelected { onChange(false) }
            }
            pillButton(title: rightTitle, selected: isRightSelected, studioDot: rightStudioDot) {
                if !isRightSelected { onChange(true) }
            }
        }
        .padding(3)
        .background(.white.opacity(0.08), in: Capsule())
    }

    private func pillButton(
        title: String,
        selected: Bool,
        studioDot: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                    .foregroundStyle(.white.opacity(selected ? 0.96 : 0.62))
                if studioDot {
                    Circle()
                        .fill(Color(red: 0.92, green: 0.56, blue: 0.25))
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .background {
                if selected {
                    Capsule().fill(.white.opacity(0.18))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
