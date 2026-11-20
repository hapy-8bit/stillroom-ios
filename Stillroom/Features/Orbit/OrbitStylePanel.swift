import SwiftUI

struct OrbitStylePanel: View {
    let presentation: OrbitPlaybackPresentation
    @Binding var preferences: OrbitVisualPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var albumOnly = false
    @State private var openedAlbumKey: String?
    @State private var openedTrack: Track?
    @State private var openedArtwork: UIImage?
    @State private var stickerDraft: OrbitStickerDraft?
    private let colors = ["A7BCE8", "F1F4FB", "E4A5BA", "C7D3AE", "E2CB9B", "343844"]

    private var style: OrbitRecordStyle {
        albumOnly ? preferences.style(for: targetAlbumKey) : preferences.globalStyle
    }
    private var targetAlbumKey: String { openedAlbumKey ?? presentation.styleKey }
    private var previewTrack: Track { openedTrack ?? presentation.displayTrack }
    private var previewArtwork: UIImage? { openedTrack == nil ? presentation.displayArtwork : openedArtwork }
    private func update(_ value: OrbitRecordStyle) {
        preferences.setStyle(value, albumKey: albumOnly ? targetAlbumKey : nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    Picker("唱片样式应用范围", selection: $albumOnly) {
                        Text("全局唱片").tag(false)
                        Text("仅此专辑").tag(true)
                    }.pickerStyle(.segmented).accessibilityIdentifier("orbit.style.scope")
                    OrbitDiscArtwork(track: previewTrack, artwork: previewArtwork, style: style)
                        .frame(width: 220, height: 220).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(OrbitBackdrop(presentation: presentation, background: preferences.background,
                                                  customBackgroundHex: preferences.customBackgroundHex))
                        .clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityIdentifier("orbit.style.preview")
                    sectionTitle("唱片模板")
                    HStack(spacing: 9) {
                        ForEach(OrbitRecordMaterial.allCases) { material in
                            choice(material.title, selected: style.material == material,
                                   identifier: "orbit.style.material." + material.rawValue) {
                                var next = style; next.material = material; update(next)
                            }
                        }
                    }
                    if style.material == .split {
                        colorRow("左侧颜色", secondary: false)
                        colorRow("右侧颜色", secondary: true)
                    }
                    Button {
                        stickerDraft = OrbitStickerDraft(track: previewTrack, artwork: previewArtwork, style: style,
                                                        albumKey: albumOnly ? targetAlbumKey : nil)
                    } label: {
                        HStack {
                            Image(systemName: "star.square.on.square")
                            Text("编辑唱片贴纸")
                            Spacer()
                            Text("\(style.stickers.count)/12").foregroundStyle(.white.opacity(0.5))
                            Image(systemName: "chevron.right").font(.caption)
                        }.font(.subheadline).foregroundStyle(.white).padding(16)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).accessibilityIdentifier("orbit.style.editStickers")
                    if albumOnly, preferences.albumStyles[targetAlbumKey] != nil {
                        Button("恢复跟随全局唱片") { preferences.albumStyles.removeValue(forKey: targetAlbumKey) }
                            .foregroundStyle(OrbitInk.accent).accessibilityIdentifier("orbit.style.restoreGlobal")
                    }
                    Divider().overlay(.white.opacity(0.15))
                    sectionTitle("背景 · 所有唱片共用")
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(OrbitBackground.allCases) { background in
                                Button { preferences.background = background } label: {
                                    VStack(spacing: 9) {
                                        Circle().fill(Color(hex: background.hex)).frame(width: 40, height: 40)
                                            .overlay(Circle().strokeBorder(preferences.background == background ? OrbitInk.accent : .white.opacity(0.15), lineWidth: 2))
                                        Text(background.title).font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                                    }.frame(width: 44).frame(minHeight: 44)
                                }.buttonStyle(.plain).accessibilityIdentifier("orbit.style.background." + background.rawValue)
                                    .accessibilityAddTraits(preferences.background == background ? .isSelected : [])
                            }
                        }.padding(.vertical, 2)
                    }.scrollIndicators(.hidden)
                }.padding(22)
            }.background(Color(white: 0.055)).navigationTitle("唱片外观").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.accessibilityIdentifier("orbit.style.done") } }
                .toolbarColorScheme(.dark, for: .navigationBar)
        }.preferredColorScheme(.dark)
            .accessibilityElement(children: .contain).accessibilityIdentifier("orbit.style.panel")
            .onAppear {
                // The panel edits the album that opened it, even when playback changes underneath the sheet.
                guard openedAlbumKey == nil else { return }
                openedAlbumKey = presentation.styleKey; openedTrack = presentation.displayTrack
                openedArtwork = presentation.displayArtwork
            }
            .sheet(item: $stickerDraft) { draft in
                OrbitStickerEditor(track: draft.track, artwork: draft.artwork, style: draft.style,
                                   background: preferences.background) { stickers in
                    var next = draft.albumKey.map { preferences.style(for: $0) } ?? preferences.globalStyle
                    next.stickers = stickers; preferences.setStyle(next, albumKey: draft.albumKey)
                }.presentationDragIndicator(.visible)
            }
    }

    private func sectionTitle(_ value: String) -> some View {
        Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
    }
    private func colorRow(_ title: String, secondary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)
            HStack {
                ForEach(colors, id: \.self) { color in
                    let selected = (secondary ? style.secondaryHex : style.primaryHex) == color
                    Button {
                        var next = style
                        if secondary { next.secondaryHex = color } else { next.primaryHex = color }
                        update(next)
                    } label: {
                        Circle().fill(OrbitInk.color(color)).frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(selected ? OrbitInk.accent : .white.opacity(0.2), lineWidth: 2))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.plain).accessibilityLabel(title + color)
                        .accessibilityIdentifier("orbit.style.color.\(secondary ? "secondary" : "primary").\(color)")
                }
            }
        }
    }
    private func choice(_ title: String, selected: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(selected ? OrbitInk.accent : .white)
                .frame(maxWidth: .infinity).frame(height: 48).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? OrbitInk.accent : .white.opacity(0.08)))
        }.buttonStyle(.plain).accessibilityIdentifier(identifier).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct OrbitStickerDraft: Identifiable {
    let id = UUID()
    let track: Track
    let artwork: UIImage?
    let style: OrbitRecordStyle
    let albumKey: String?
}
