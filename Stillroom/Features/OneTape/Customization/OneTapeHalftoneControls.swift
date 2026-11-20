import SwiftUI

struct OneTapeHalftoneControlsPanel: View {
    @Binding var recipe: OneTapeArtworkRecipe
    let tapeStyle: OneTapeAppearance.TapeStyle
    let isIsolatingSubject: Bool
    let onToggleSubjectOnly: (Bool) -> Void
    let onParameterChanged: (_ immediate: Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("印花")

                Picker("印花模式", selection: Binding(
                    get: { recipe.mode },
                    set: { next in
                        recipe.mode = next
                        onParameterChanged(true)
                    }
                )) {
                    ForEach(OneTapeArtworkMode.allCases, id: \.rawValue) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if recipe.mode == .halftone {
                    Picker("网点风格", selection: Binding(
                        get: { recipe.halftoneStyle },
                        set: { next in
                            recipe.halftoneStyle = next
                            onParameterChanged(true)
                        }
                    )) {
                        ForEach(OneTapeHalftoneStyle.allCases, id: \.rawValue) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                subjectToggleRow

                if recipe.mode == .halftone {
                    OneTapeHalftoneCapsuleSlider(title: "网点大小", value: $recipe.dotSize) { editing in
                        onParameterChanged(!editing)
                    }
                    OneTapeHalftoneCapsuleSlider(title: "印迹磨损", value: $recipe.inkWear) { editing in
                        onParameterChanged(!editing)
                    }
                } else {
                    OneTapeHalftoneCapsuleSlider(title: "去杂", value: $recipe.cleanup) { editing in
                        onParameterChanged(!editing)
                    }
                    OneTapeHalftoneCapsuleSlider(title: "浓度", value: $recipe.strength) { editing in
                        onParameterChanged(!editing)
                    }
                }
            }

            inkSwatchSection(title: "墨水", selection: $recipe.primaryInk)

            if recipe.mode == .halftone && recipe.halftoneStyle == .overprint {
                inkSwatchSection(title: "第二种墨色", selection: $recipe.secondaryInk)
            }

            if recipe.mode == .halftone {
                OneTapeHalftoneCapsuleSlider(title: "浓度", value: $recipe.strength) { editing in
                    onParameterChanged(!editing)
                }
            } else {
                Text("保留墨迹，去除纸张。浅色素纸上的深色笔迹效果最好。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
            .accessibilityAddTraits(.isHeader)
    }

    private var subjectToggleRow: some View {
        HStack {
            Text("仅保留主体")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.92))
            Spacer()
            if isIsolatingSubject {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 8)
            }
            Toggle("", isOn: Binding(
                get: { recipe.subjectOnly },
                set: onToggleSubjectOnly
            ))
            .labelsHidden()
            .tint(.orange)
        }
        .padding(.vertical, 2)
    }

    private func inkSwatchSection(title: String, selection: Binding<OneTapeArtworkInk>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(title)
                Spacer()
                Text(selection.wrappedValue.title)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(spacing: 12) {
                ForEach(OneTapeArtworkInk.allCases) { ink in
                    let isSelected = selection.wrappedValue == ink
                    Button {
                        selection.wrappedValue = ink
                        onParameterChanged(true)
                    } label: {
                        Circle()
                            .fill(ink.swatchColor(for: tapeStyle))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Circle().strokeBorder(.white.opacity(0.24), lineWidth: 1)
                            }
                            .overlay {
                                if isSelected {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2)
                                        .padding(-4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ink.title)
                }
            }

            if selection.wrappedValue == .tapeInk && recipe.mode == .halftone && title == "墨水" {
                Text(tapeStyle.usesLightInk ? "这张照片用奶油色印制，适合深色磁带。" : "这张照片用深色墨水印制，适合浅色磁带。")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }
}

struct OneTapeHalftoneCapsuleSlider: View {
    let title: String
    @Binding var value: Double
    let onEditingChanged: (Bool) -> Void

    private let activeFill = Color(red: 239.0 / 255.0, green: 232.0 / 255.0, blue: 215.0 / 255.0)
    private let trackFill = Color(red: 42.0 / 255.0, green: 42.0 / 255.0, blue: 42.0 / 255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text("\(Int(round(value * 100)))%")
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }

            GeometryReader { proxy in
                let width = max(1, proxy.size.width)
                let thumbW: CGFloat = 30
                let thumbH: CGFloat = 18
                let usable = max(1, width - thumbW)
                let clamped = min(1.0, max(0.0, value))
                let fillWidth = thumbW * 0.5 + usable * CGFloat(clamped)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(trackFill)
                        .frame(height: 6)
                    Capsule()
                        .fill(activeFill)
                        .frame(width: fillWidth, height: 6)
                    Capsule()
                        .fill(.white)
                        .frame(width: thumbW, height: thumbH)
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .offset(x: usable * CGFloat(clamped))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let ratio = min(1.0, max(0.0, Double((drag.location.x - thumbW * 0.5) / usable)))
                            value = ratio
                            onEditingChanged(true)
                        }
                        .onEnded { drag in
                            let ratio = min(1.0, max(0.0, Double((drag.location.x - thumbW * 0.5) / usable)))
                            value = ratio
                            onEditingChanged(false)
                        }
                )
            }
            .frame(height: 26)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue("\(Int(round(value * 100)))%")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    value = min(1.0, value + 0.05)
                    onEditingChanged(false)
                case .decrement:
                    value = max(0.0, value - 0.05)
                    onEditingChanged(false)
                @unknown default:
                    break
                }
            }
        }
    }
}
