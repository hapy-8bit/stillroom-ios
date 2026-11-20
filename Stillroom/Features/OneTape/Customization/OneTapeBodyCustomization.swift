import SwiftUI

struct OneTapeBodyCustomization: View {
    @Binding var appearance: OneTapeAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("机身")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(OneTapeAppearance.BodyStyle.allCases) { style in
                    OneTapeCustomizationTile(
                        title: style.customizationTitle,
                        selected: appearance.bodyMaterial == nil && appearance.bodyStyle == style,
                        studioMarker: style != .black,
                        identifier: "customization.body.\(style.rawValue)"
                    ) {
                        appearance.selectBodyStyle(style)
                    } thumbnail: {
                        Image(style.customizationThumbnailAsset).resizable().scaledToFit()
                    }
                }
                ForEach(OneTapeBodyMaterial.allCases) { material in
                    OneTapeCustomizationTile(title: material.title,
                        selected: appearance.bodyMaterial == material, studioMarker: false,
                        identifier: "customization.material.\(material.rawValue)") {
                            appearance.selectBodyMaterial(material)
                        } thumbnail: {
                            OneTapeMaterialPreview(material: material)
                        }
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(OneTapeAppearance.BodyColor.allCases) { color in
                        colorButton(color)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("customization.bodyColors")
        }
        .contentShape(Rectangle())
    }

    private func colorButton(_ color: OneTapeAppearance.BodyColor) -> some View {
        Button { appearance.bodyColor = color } label: {
            Circle()
                .fill(color.swiftUIColor)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(appearance.bodyColor == color ? .white : .clear, lineWidth: 1.8)
                        .padding(-4)
                }
                .overlay(alignment: .topTrailing) {
                    if color != .black {
                        Circle().fill(Color(red: 0.86, green: 0.52, blue: 0.25))
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -4)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(color.customizationTitle)机身")
        .accessibilityValue(appearance.bodyColor == color ? "已选择" : "")
        .accessibilityAddTraits(appearance.bodyColor == color ? [.isSelected] : [])
        .accessibilityIdentifier("customization.bodyColor.\(color.rawValue)")
    }
}
