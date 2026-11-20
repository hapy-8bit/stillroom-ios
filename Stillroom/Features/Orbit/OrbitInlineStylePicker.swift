import SwiftUI
import UIKit

/// The parent keeps the large turntable mounted and gives this editor its lower viewport.
/// Audio and persistence remain outside the component; edits only change the supplied value.
struct OrbitInlineStylePicker: View {
    let presentation: OrbitPlaybackPresentation
    @Binding var preferences: OrbitVisualPreferences
    let onClose: () -> Void
    @State private var target: InlineStyleTarget
    @State private var albumOnly: Bool
    @State private var stickerDraft: InlineStickerDraft?
    @State private var showingCustomBackground = false
    @State private var colorNotice: String?

    private let materials: [OrbitRecordMaterial] = [.black, .smoke, .silver, .radial, .resinGreen, .artwork, .split]
    private let backgrounds: [OrbitBackground] = [.atmosphere, .silver, .black, .white, .spectrum, .sage, .lavender, .blue]

    init(presentation: OrbitPlaybackPresentation, preferences: Binding<OrbitVisualPreferences>,
         onClose: @escaping () -> Void) {
        self.presentation = presentation
        _preferences = preferences
        self.onClose = onClose
        // State captures the opening identity once. Live track ticks or a skip must not redirect
        // a sticker save or album override to whichever song happens to be playing later.
        _target = State(initialValue: InlineStyleTarget(key: presentation.styleKey,
            title: presentation.displayRecordTitle, track: presentation.displayTrack,
            artwork: presentation.displayArtwork))
        _albumOnly = State(initialValue: preferences.wrappedValue.albumStyles[presentation.styleKey] != nil)
    }

    private var ink: Color { preferences.usesLightContent ? .white : Color(white: 0.12) }
    private var albumStyle: OrbitRecordStyle? { preferences.albumStyles[target.key] }
    private var style: OrbitRecordStyle {
        albumOnly ? preferences.style(for: target.key) : preferences.globalStyle
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 13) {
                albumSection
                HStack {
                    Text(albumOnly ? "专属材质" : "通用").font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 8)
                    if albumStyle != nil {
                        Button(albumOnly ? "编辑通用" : "编辑专属") { albumOnly.toggle() }
                            .font(.system(size: 11, weight: .medium)).frame(minHeight: 44)
                            .accessibilityIdentifier("orbit.style.scope.toggle")
                    }
                    styleMenu
                }.frame(minHeight: 44)
                materialRow
                if style.material == .split { splitColors }
                backgroundRow
                if !albumOnly, albumStyle != nil {
                    Text("此专辑保留专属样式").font(.caption2).foregroundStyle(ink.opacity(0.6))
                }
                if presentation.styleKey != target.key {
                    Text("正在编辑打开时的“\(target.title)”")
                        .font(.caption2).foregroundStyle(ink.opacity(0.65)).lineLimit(2)
                }
                if let colorNotice {
                    Text(colorNotice).font(.caption2).foregroundStyle(ink)
                        .accessibilityIdentifier("orbit.style.color.error")
                }
                Button(action: onClose) {
                    Image(systemName: "chevron.down").font(.system(size: 16, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(ink.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                        .frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("收起唱片外观")
                    .accessibilityIdentifier("orbit.style.done")
            }.padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 8)
        }.scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize)
            .foregroundStyle(ink).tint(ink)
            .accessibilityElement(children: .contain).accessibilityIdentifier("orbit.style.panel")
            .popover(isPresented: $showingCustomBackground) { customBackgroundEditor }
            .sheet(item: $stickerDraft) { draft in
                OrbitStickerEditor(track: draft.target.track, artwork: draft.target.artwork,
                    style: draft.style, background: preferences.background) { stickers in
                        var next = draft.albumKey.map { preferences.style(for: $0) } ?? preferences.globalStyle
                        next.stickers = stickers
                        preferences.setStyle(next, albumKey: draft.albumKey)
                    }.presentationDragIndicator(.visible)
            }
    }

    private var albumSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("专属于 \(target.title)").font(.system(size: 13, weight: .semibold))
                .lineLimit(2).accessibilityIdentifier("orbit.style.album.title")
            if let albumStyle {
                HStack(spacing: 12) {
                    Button { albumOnly = true } label: {
                        materialThumbnail(albumStyle, selected: albumOnly)
                    }.buttonStyle(.plain).accessibilityLabel("编辑此专辑的专属样式")
                        .accessibilityIdentifier("orbit.style.album.selected")
                        .accessibilityAddTraits(albumOnly ? .isSelected : [])
                    Button("跟随通用") {
                        preferences.albumStyles.removeValue(forKey: target.key)
                        albumOnly = false
                    }.font(.system(size: 11, weight: .medium)).frame(minHeight: 44)
                        .accessibilityIdentifier("orbit.style.restoreGlobal")
                }
            } else {
                Button {
                    preferences.setStyle(preferences.globalStyle, albumKey: target.key)
                    albumOnly = true
                } label: {
                    Image(systemName: "plus").font(.system(size: 23, weight: .regular))
                        .frame(width: 40, height: 40).background(ink.opacity(0.14), in: Circle())
                        .overlay(Circle().strokeBorder(ink.opacity(0.2), lineWidth: 0.7))
                        .frame(width: 44, height: 44)
                }.buttonStyle(.plain).disabled(target.key.isEmpty || presentation.albums.isEmpty)
                    .accessibilityLabel("为这张专辑添加专属样式")
                    .accessibilityIdentifier("orbit.style.album.add")
            }
        }
    }

    private var materialRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 11) {
                Button {
                    let choices = materials.filter { $0 != style.material }
                    guard let material = choices.randomElement() else { return }
                    selectMaterial(material)
                } label: {
                    Image(systemName: "shuffle").font(.system(size: 18, weight: .medium))
                        .frame(width: 40, height: 40).background(ink.opacity(0.08), in: Circle())
                        .overlay(Circle().strokeBorder(ink.opacity(0.35), lineWidth: 1))
                        .frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("随机选择一种唱片材质")
                    .accessibilityHint("只更改外观，不更改歌曲或播放队列")
                    .accessibilityIdentifier("orbit.style.material.random")
                ForEach(materials) { material in
                    Button { selectMaterial(material) } label: {
                        var preview = style
                        preview.material = material
                        return materialThumbnail(preview, selected: style.material == material)
                    }.buttonStyle(.plain).accessibilityLabel(material.title)
                        .accessibilityIdentifier("orbit.style.material." + material.rawValue)
                        .accessibilityAddTraits(style.material == material ? .isSelected : [])
                }
            }.padding(.vertical, 2)
        }.scrollIndicators(.hidden).accessibilityIdentifier("orbit.style.materials")
    }

    private var backgroundRow: some View {
        HStack(spacing: 9) {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(backgrounds) { background in
                        Button { preferences.background = background } label: {
                            backgroundSwatch(background)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(preferences.background == background ? ink : ink.opacity(0.18),
                                                  lineWidth: preferences.background == background ? 2 : 0.8))
                                .frame(width: 44, height: 44)
                        }.buttonStyle(.plain).accessibilityLabel(background.title + "背景")
                            .accessibilityIdentifier("orbit.style.background." + background.rawValue)
                            .accessibilityAddTraits(preferences.background == background ? .isSelected : [])
                    }
                }.padding(.vertical, 2)
            }.scrollIndicators(.hidden).accessibilityIdentifier("orbit.style.backgrounds")
            Button { preferences.armLight = preferences.armLight.next } label: {
                Image(systemName: "sun.max").font(.system(size: 20, weight: .regular))
                    .foregroundStyle(preferences.armLight == .off ? ink : OrbitInk.color(preferences.armLight.hex))
                    .frame(width: 40, height: 40).background(ink.opacity(0.1), in: Circle())
                    .overlay(Circle().strokeBorder(preferences.armLight == .off ? .clear : OrbitInk.color(preferences.armLight.hex), lineWidth: 1))
                    .frame(width: 44, height: 44)
            }.buttonStyle(.plain).accessibilityLabel("唱臂灯")
                .accessibilityValue(preferences.armLight.title)
                .accessibilityHint("依次切换红色、蓝色、紫色和关闭")
                .accessibilityIdentifier("orbit.style.armLight")
        }
    }

    private var styleMenu: some View {
        Menu {
            Button("自定义背景颜色", systemImage: "paintpalette") { showingCustomBackground = true }
                .accessibilityIdentifier("orbit.style.background.custom")
            Button("编辑唱片贴纸", systemImage: "star.square.on.square") {
                stickerDraft = InlineStickerDraft(target: target, style: style,
                                                 albumKey: albumOnly ? target.key : nil)
            }.disabled(presentation.albums.isEmpty).accessibilityIdentifier("orbit.style.editStickers")
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.accessibilityLabel("更多外观编辑")
            .accessibilityIdentifier("orbit.style.more")
    }

    private var splitColors: some View {
        HStack(spacing: 16) {
            ColorPicker("左侧", selection: materialColor(secondary: false), supportsOpacity: false)
            ColorPicker("右侧", selection: materialColor(secondary: true), supportsOpacity: false)
        }.font(.caption).frame(minHeight: 44)
    }

    private func selectMaterial(_ material: OrbitRecordMaterial) {
        var next = style
        next.material = material
        preferences.setStyle(next, albumKey: albumOnly ? target.key : nil)
    }

    private func materialThumbnail(_ value: OrbitRecordStyle, selected: Bool) -> some View {
        var preview = value
        preview.stickers = []
        return OrbitDiscArtwork(track: target.track, artwork: target.artwork, style: preview)
            .frame(width: 38, height: 38).clipShape(Circle())
            .padding(3).overlay(Circle().strokeBorder(selected ? ink : ink.opacity(0.25), lineWidth: selected ? 2 : 0.7))
            .frame(width: 44, height: 44)
    }

    @ViewBuilder private func backgroundSwatch(_ value: OrbitBackground) -> some View {
        if value == .atmosphere {
            LinearGradient(colors: [Color(white: 0.4), Color(hex: 0x182A38), Color(hex: 0x070B11)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if value == .spectrum {
            AngularGradient(colors: [.cyan, .blue, .purple, .pink, .orange, .yellow, .cyan], center: .center)
                .blur(radius: 7)
        } else { Color(hex: value.hex) }
    }

    private var backgroundColor: Binding<Color> {
        Binding(get: { OrbitInk.color(preferences.customBackgroundHex) }, set: { value in
            guard let hex = rgbHex(value), preferences.setCustomBackgroundHex(hex) else {
                colorNotice = "颜色未能读取，请重新选择。"
                return
            }
            colorNotice = nil
        })
    }

    private var customBackgroundEditor: some View {
        VStack(alignment: .leading, spacing: 18) {
            ColorPicker("自定义背景", selection: backgroundColor, supportsOpacity: false)
                .accessibilityIdentifier("orbit.style.custom.color")
            Text("#" + preferences.customBackgroundHex)
                .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            Button("完成") { showingCustomBackground = false }.accessibilityIdentifier("orbit.style.custom.done")
        }.padding(20).frame(minWidth: 230).presentationCompactAdaptation(.popover)
    }

    private func materialColor(secondary: Bool) -> Binding<Color> {
        Binding(get: { OrbitInk.color(secondary ? style.secondaryHex : style.primaryHex) }, set: { value in
            guard let hex = rgbHex(value) else { colorNotice = "颜色未能读取，请重新选择。"; return }
            var next = style
            if secondary { next.secondaryHex = hex } else { next.primaryHex = hex }
            preferences.setStyle(next, albumKey: albumOnly ? target.key : nil)
            colorNotice = nil
        })
    }

    private func rgbHex(_ value: Color) -> String? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(value).getRed(&red, green: &green, blue: &blue, alpha: &alpha),
              red.isFinite, green.isFinite, blue.isFinite else { return nil }
        func byte(_ channel: CGFloat) -> Int { Int((min(1, max(0, channel)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}

private struct InlineStyleTarget {
    let key: String
    let title: String
    let track: Track
    let artwork: UIImage?
}

private struct InlineStickerDraft: Identifiable {
    let id = UUID()
    let target: InlineStyleTarget
    let style: OrbitRecordStyle
    let albumKey: String?
}
