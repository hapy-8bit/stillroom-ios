import SwiftUI

struct OneTapeBodyCustomization: View {
    @Binding var appearance: OneTapeAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("经典机身")
                LazyVGrid(columns: twoColumns, spacing: 12) {
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
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("特色材质")
                LazyVGrid(columns: threeColumns, spacing: 12) {
                    ForEach(OneTapeBodyMaterial.cassetteOriginals) { material in
                        OneTapeCustomizationTile(
                            title: material.title,
                            selected: appearance.bodyMaterial == material,
                            studioMarker: true,
                            identifier: "customization.material.\(material.rawValue)"
                        ) {
                            appearance.selectBodyMaterial(material)
                        } thumbnail: {
                            OneTapeMaterialPreview(material: material)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("玻璃与金属")
                LazyVGrid(columns: twoColumns, spacing: 12) {
                    ForEach(OneTapeBodyMaterial.glassAndMetal) { material in
                        OneTapeCustomizationTile(
                            title: material.title,
                            selected: appearance.bodyMaterial == material,
                            studioMarker: false,
                            identifier: "customization.material.\(material.rawValue)"
                        ) {
                            appearance.selectBodyMaterial(material)
                        } thumbnail: {
                            OneTapeMaterialPreview(material: material)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("机身色调")
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
        }
        .contentShape(Rectangle())
    }

    private var twoColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    }

    private var threeColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.65))
            .accessibilityAddTraits(.isHeader)
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
