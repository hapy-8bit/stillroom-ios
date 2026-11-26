import SwiftUI

/// A floating surface: its caller controls window placement and keeps the HUD
/// above it. This view never presents a sheet or owns persistent appearance data.
struct OneTapeCustomizationView: View {
    @Binding var appearance: OneTapeAppearance
    @Binding var tab: OneTapeCustomizationTab
    var readout: OneTapePlaybackReadout = .empty
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var customPrint: OneTapeResolvedPrint? = nil
    var drawings: [OneTapeCustomDrawing] = []
    var artworks: [OneTapeCustomArtwork] = []
    var thumbnailForDrawing: (OneTapeCustomDrawing) -> UIImage? = { _ in nil }
    var titleForDrawing: (OneTapeCustomDrawing) -> String = { _ in "画作" }
    var thumbnailForArtwork: (OneTapeCustomArtwork) -> UIImage? = { _ in nil }
    var titleForArtwork: (OneTapeCustomArtwork) -> String = { _ in "照片" }
    var visualization: AudioVisualizationSignal? = nil
    let onClose: () -> Void
    let onStudio: () -> Void
    var onStartNewDrawing: () -> Void = {}
    var onStartHalftone: () -> Void = {}
    var onEditDrawing: (OneTapeCustomDrawing) -> Void = { _ in }
    var onToggleInkMode: (OneTapeCustomDrawing) -> Void = { _ in }
    var onDeleteDrawing: (OneTapeCustomDrawing) -> Void = { _ in }
    var onEditArtwork: (OneTapeCustomArtwork) -> Void = { _ in }
    var onReprintArtwork: (OneTapeCustomArtwork) -> Void = { _ in }
    var onDeleteArtwork: (OneTapeCustomArtwork) -> Void = { _ in }
    var onGetPaper: () -> Void = {}
    var onImportFromPhotos: () -> Void = {}
    var onImportFromFiles: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let panelHeight = geometry.size.height * tab.panelHeightFraction
            VStack(spacing: 0) {
                header
                    .padding(.leading, 20)
                    .padding(.trailing, 10)
                    .padding(.top, 12)
                    .padding(.bottom, 17)
                tabs
                    .padding(.leading, 20)
                    .padding(.trailing, 10)
                    .padding(.bottom, 13)
                if tab == .tape {
                    preview
                        .frame(height: min(196, max(130, geometry.size.width * 0.46)))
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        choices
                        if tab != .print && tab != .reel {
                            studioLink
                                .padding(.top, 6)
                        }
                    }
                    // The root's floating HUD overlaps the lower panel. Scroll
                    // clearance lets every last row move above that obstruction.
                    .padding(.bottom, 96)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("customization.scroll")
            }
            .frame(width: geometry.size.width, height: panelHeight)
            .background {
                if tab == .print || tab == .reel {
                    Color(white: 0.055).opacity(0.90)
                } else {
                    Color(white: 0.075).opacity(0.94)
                        .background(.ultraThinMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.035), lineWidth: 0.7)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text("自定义")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("customization.title")
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.1), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭自定义")
            .accessibilityIdentifier("customization.close")
        }
        .frame(height: 44)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(OneTapeCustomizationTab.allCases) { item in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        tab = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 14, weight: tab == item ? .semibold : .medium))
                        .foregroundStyle(.white.opacity(tab == item ? 0.95 : 0.55))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background {
                            if tab == item {
                                Capsule().fill(.white.opacity(0.19))
                            }
                        }
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("customization.tab.\(item.rawValue)")
                .accessibilityValue(tab == item ? "已选择" : "")
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 36)
        .background(.white.opacity(0.055), in: Capsule())
    }

    private var preview: some View {
        OneTapeTapeThumbnail(
            tilt: 0,
            appearance: appearance,
            cassetteReadout: cassetteReadout,
            customPrint: customPrint
        )
        // The rotated artwork keeps a larger layout rectangle than its visible
        // preview. It is decoration and must never shield the tabs above it.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var choices: some View {
        switch tab {
        case .tape: tapeChoices
        case .print:
            OneTapePrintCustomization(
                appearance: $appearance,
                cassetteReadout: cassetteReadout,
                drawings: drawings,
                artworks: artworks,
                thumbnailForDrawing: thumbnailForDrawing,
                titleForDrawing: titleForDrawing,
                thumbnailForArtwork: thumbnailForArtwork,
                titleForArtwork: titleForArtwork,
                onStartNewDrawing: onStartNewDrawing,
                onStartHalftone: onStartHalftone,
                onEditDrawing: onEditDrawing,
                onToggleInkMode: onToggleInkMode,
                onDeleteDrawing: onDeleteDrawing,
                onEditArtwork: onEditArtwork,
                onReprintArtwork: onReprintArtwork,
                onDeleteArtwork: onDeleteArtwork,
                onGetPaper: onGetPaper,
                onImportFromPhotos: onImportFromPhotos,
                onImportFromFiles: onImportFromFiles
            )
        case .reel: OneTapeReelCustomization(appearance: $appearance)
        case .body: OneTapeBodyCustomization(appearance: $appearance)
        case .screen: OneTapeScreenCustomization(appearance: $appearance,
            readout: readout, visualization: visualization)
        }
    }

    private var tapeChoices: some View {
        let sections: [(title: String, styles: [OneTapeAppearance.TapeStyle])] = [
            ("经典", OneTapeAppearance.TapeStyle.classicGroup),
            ("极简", OneTapeAppearance.TapeStyle.bespoke),
            ("质感", OneTapeAppearance.TapeStyle.retroGroup)
        ]
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                groupTitle(section.title)
                    .padding(.top, index == 0 ? 0 : 12)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(section.styles) { style in
                        tapeTile(for: style)
                    }
                }
            }
        }
    }

    private func tapeTile(for style: OneTapeAppearance.TapeStyle) -> some View {
        let hasStudioMarker = style != .classic
        return OneTapeCustomizationTile(
            title: style.customizationTitle,
            selected: appearance.tapeStyle == style,
            studioMarker: hasStudioMarker,
            identifier: "customization.tape.\(style.rawValue)"
        ) {
            select { $0.selectTapeStyle(style) }
        } thumbnail: {
            OneTapeTapeThumbnail(appearance: previewAppearance(for: style), showsPrint: false)
                .allowsHitTesting(false)
        }
    }

    private func previewAppearance(for style: OneTapeAppearance.TapeStyle) -> OneTapeAppearance {
        var preview = OneTapeAppearance()
        preview.tapeStyle = style
        preview.printStyle = .blank
        return preview
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    }

    private var studioLink: some View {
        Button(action: onStudio) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("Studio")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(red: 0.87, green: 0.55, blue: 0.25))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("customization.studio")
    }

    private func groupTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.75))
            .accessibilityAddTraits(.isHeader)
    }

    private func select(_ change: (inout OneTapeAppearance) -> Void) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
            var next = appearance
            change(&next)
            appearance = next
        }
    }
}
