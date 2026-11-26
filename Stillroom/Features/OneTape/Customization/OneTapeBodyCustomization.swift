import SwiftUI

/// Unified 5-category body customization structure aligned with Cassette 1.0.5's
/// complete body catalog (4 classic styles + 8 paint coats + 11 GPU signature finishes).
struct OneTapeBodyCustomization: View {
    @Binding var appearance: OneTapeAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            classicSection
            ForEach(OneTapeBodyCategory.materialCategories) { category in
                materialCategorySection(category)
            }
        }
        .contentShape(Rectangle())
    }

    private var classicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(OneTapeBodyCategory.classic.title,
                          subtitle: OneTapeBodyCategory.classic.subtitle)
            LazyVGrid(columns: twoColumns, spacing: 12) {
                OneTapeCustomizationTile(
                    title: "经典黑",
                    selected: isClassicSelected(.black),
                    studioMarker: false,
                    identifier: "customization.body.black"
                ) {
                    appearance.selectBodyStyle(.black)
                } thumbnail: {
                    Image(OneTapeAppearance.BodyStyle.black.customizationThumbnailAsset)
                        .resizable()
                        .scaledToFill()
                }

                OneTapeCustomizationTile(
                    title: "石墨钛灰",
                    selected: isClassicSelected(.graphite),
                    studioMarker: true,
                    identifier: "customization.body.graphite"
                ) {
                    appearance.selectBodyStyle(.graphite)
                } thumbnail: {
                    OneTapeMaterialPreview(bodyStyle: .graphite)
                }

                OneTapeCustomizationTile(
                    title: "随曲配色",
                    selected: isClassicSelected(.adaptive),
                    studioMarker: true,
                    identifier: "customization.body.adaptive"
                ) {
                    appearance.selectBodyStyle(.adaptive)
                } thumbnail: {
                    Image(OneTapeAppearance.BodyStyle.adaptive.customizationThumbnailAsset)
                        .resizable()
                        .scaledToFill()
                }

                OneTapeCustomizationTile(
                    title: "专辑封面",
                    selected: isClassicSelected(.cover),
                    studioMarker: true,
                    identifier: "customization.body.cover"
                ) {
                    appearance.selectBodyStyle(.cover)
                } thumbnail: {
                    Image(OneTapeAppearance.BodyStyle.cover.customizationThumbnailAsset)
                        .resizable()
                        .scaledToFill()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("机身喷漆")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
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
            .padding(.top, 2)
        }
    }

    private func isClassicSelected(_ style: OneTapeAppearance.BodyStyle) -> Bool {
        appearance.bodyMaterial == nil
            && appearance.bodyStyle == style
            && appearance.bodyColor == .black
    }

    private func materialCategorySection(_ category: OneTapeBodyCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(category.title, subtitle: category.subtitle)
            LazyVGrid(columns: twoColumns, spacing: 12) {
                ForEach(category.materials) { material in
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
    }

    private var twoColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.76))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.40))
                .lineLimit(1)
        }
    }

    private func colorButton(_ color: OneTapeAppearance.BodyColor) -> some View {
        let isSelected = appearance.bodyMaterial == nil
            && appearance.bodyStyle == .black
            && appearance.bodyColor == color
        return Button { appearance.selectBodyColor(color) } label: {
            Circle()
                .fill(color.swiftUIColor)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(isSelected ? .white : .clear, lineWidth: 1.8)
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
        .accessibilityValue(isSelected ? "已选择" : "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("customization.bodyColor.\(color.rawValue)")
    }
}
