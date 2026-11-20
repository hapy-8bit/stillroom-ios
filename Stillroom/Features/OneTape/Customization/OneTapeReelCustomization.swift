import SwiftUI

/// Reel customization tab letting the user dye the rotating internal gear collar of both tape hubs.
struct OneTapeReelCustomization: View {
    @Binding var appearance: OneTapeAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("齿轮")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.60))

            HStack(spacing: 18) {
                ForEach(OneTapeAppearance.ReelColor.allCases) { color in
                    swatchButton(for: color)
                }
            }
            .padding(.leading, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }

    private func swatchButton(for option: OneTapeAppearance.ReelColor) -> some View {
        let isSelected = appearance.reelColor == option
        return Button {
            appearance.reelColor = option
        } label: {
            ZStack {
                Circle()
                    .fill(option.swatchColor)
                    .frame(width: 34, height: 34)
                    .overlay {
                        if option == .black {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        }
                    }

                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 1.8)
                        .frame(width: 42, height: 42)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.accessibilityName)
        .accessibilityValue(isSelected ? "已选择" : "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("customization.reelColor.\(option.rawValue)")
    }
}

extension OneTapeAppearance.ReelColor {
    var swatchColor: Color {
        switch self {
        case .white: Color(red: 0.922, green: 0.922, blue: 0.922)
        case .black: Color(red: 0.135, green: 0.140, blue: 0.155)
        case .orange: Color(red: 0.980, green: 0.431, blue: 0.118)
        case .crimson: Color(red: 0.820, green: 0.098, blue: 0.278)
        case .blue: Color(red: 0.200, green: 0.424, blue: 0.933)
        }
    }

    var highlightColor: Color {
        switch self {
        case .white: Color(red: 0.985, green: 0.985, blue: 0.985)
        case .black: Color(red: 0.235, green: 0.242, blue: 0.265)
        case .orange: Color(red: 1.000, green: 0.560, blue: 0.240)
        case .crimson: Color(red: 0.930, green: 0.180, blue: 0.370)
        case .blue: Color(red: 0.310, green: 0.550, blue: 0.990)
        }
    }

    var shadowColor: Color {
        switch self {
        case .white: Color(red: 0.680, green: 0.685, blue: 0.695)
        case .black: Color(red: 0.075, green: 0.078, blue: 0.088)
        case .orange: Color(red: 0.720, green: 0.255, blue: 0.045)
        case .crimson: Color(red: 0.555, green: 0.045, blue: 0.165)
        case .blue: Color(red: 0.105, green: 0.245, blue: 0.660)
        }
    }

    var accessibilityName: String {
        switch self {
        case .white: "白色齿轮"
        case .black: "黑色齿轮"
        case .orange: "橙色齿轮"
        case .crimson: "绯红齿轮"
        case .blue: "蓝色齿轮"
        }
    }
}
