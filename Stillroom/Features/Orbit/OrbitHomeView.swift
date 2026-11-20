import SwiftUI

struct OrbitHomeView: View {
    let presentation: OrbitPlaybackPresentation
    @Binding var preferences: OrbitVisualPreferences
    let actions: OrbitHomeActions
    @Binding var destination: RoomDestination
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.roomMotionVisible) private var motionVisible
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var legacyStyleVisible = false
    @State private var chrome = TurntableChromeState()

    private var isTurntable: Bool { preferences.selectedHome == .turntable }
    private var active: Bool { presentation.active && scenePhase == .active && motionVisible }
    private var model: OrbitPlaybackPresentation {
        var copy = presentation
        copy.reducedMotion = presentation.reducedMotion || systemReducedMotion
        return copy
    }
    private var style: OrbitRecordStyle { preferences.style(for: presentation.styleKey) }
    private var ink: Color { preferences.usesLightContent ? .white : Color(white: 0.12) }
    private var idleKey: String { "\(chrome.revision)|\(active)|\(voiceOverEnabled)|\(isTurntable)" }

    var body: some View {
        GeometryReader { geometry in
            if isTurntable { turntable(size: geometry.size, safeBottom: geometry.safeAreaInsets.bottom) }
            else { legacyPage }
        }
        .ignoresSafeArea(.container, edges: isTurntable ? .all : [])
        .statusBarHidden(isTurntable)
        .preferredColorScheme(isTurntable && !preferences.usesLightContent ? .light : .dark)
        .accessibilityElement(children: .contain).accessibilityIdentifier("orbit.home")
        .sheet(isPresented: $legacyStyleVisible) {
            OrbitStylePanel(presentation: model, preferences: $preferences).presentationDragIndicator(.visible)
        }
        .task(id: idleKey) {
            guard isTurntable, active, chrome.showsTools, !voiceOverEnabled else { return }
            let revision = chrome.revision
            // Six seconds is this local player's idle policy, not a recovered reference constant.
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            guard !Task.isCancelled else { return }
            changeChrome { chrome.finishIdle(revision: revision) }
        }
        .onChange(of: preferences.selectedHome) { _, _ in chrome.collapse() }
        .onChange(of: active) { _, value in if !value { chrome.collapse() } }
    }

    private func turntable(size: CGSize, safeBottom: CGFloat) -> some View {
        let wide = size.width > size.height * 0.72
        let metadataY = size.height * (wide ? 0.30 : 0.75)
        let footerTop = min(size.height * 0.91, size.height - max(16, safeBottom) - 49)
        return ZStack(alignment: .topLeading) {
            OrbitBackdrop(presentation: model, background: preferences.background,
                          customBackgroundHex: preferences.customBackgroundHex).ignoresSafeArea()
            OrbitTurntableView(presentation: model, style: style, active: active,
                               armLight: preferences.armLight,
                               inputEnabled: !chrome.showsAppearance, onSkip: actions.skip, onToggle: actions.toggle)
            if !chrome.showsAppearance {
                // This hit surface must leave the tree during inline editing; its former
                // upper band overlaps the album-specific add control in that lower viewport.
                Button { revealTools() } label: { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain).frame(width: size.width * (wide ? 0.48 : 1), height: max(44, size.height * 0.105))
                    .offset(x: wide ? size.width * 0.52 : 0, y: size.height * 0.64)
                    .accessibilityLabel("显示播放工具").accessibilityIdentifier("orbit.tools.reveal")
            }
            if chrome.showsAppearance {
                OrbitInlineStylePicker(presentation: model, preferences: $preferences) {
                    changeChrome { chrome.collapse() }
                }
                .frame(width: wide ? size.width * 0.48 : size.width,
                       height: size.height * (wide ? 0.74 : 0.37))
                .offset(x: wide ? size.width * 0.52 : 0, y: size.height * (wide ? 0.20 : 0.63))
                .zIndex(2)
                .transition(.opacity)
            } else {
                if presentation.albums.isEmpty {
                    emptyReadout.padding(.horizontal, size.width * 0.079).offset(y: metadataY)
                } else {
                    OrbitTransport(presentation: model, actions: actions, active: active,
                                   turntable: true, lightBackground: !preferences.usesLightContent,
                                   showsPhysicalControls: false,
                                   showsTurntableSecondaryInfo: presentation.craftedSession != nil,
                                   horizontalInset: size.width * 0.079,
                                   openTurntable: actions.sleeve)
                        .frame(width: wide ? size.width * 0.47 : size.width)
                        .offset(x: wide ? size.width * 0.53 : 0, y: metadataY)
                }
                if chrome.showsTools {
                    topTools(width: size.width).offset(y: size.height * 0.036)
                    expandedFooter(size: size).offset(y: footerTop - 2).transition(.opacity)
                } else {
                    OrbitPhysicalKeys(presentation: model, actions: actions, width: size.width,
                                      lightContent: preferences.usesLightContent)
                        .offset(y: footerTop).transition(.opacity)
                }
            }
        }.frame(width: size.width, height: size.height).clipped()
            .accessibilityAction(named: "显示播放工具", revealTools)
    }

    private func topTools(width: CGFloat) -> some View {
        HStack(spacing: width * 0.022) {
            Spacer()
            Button(action: actions.rotate) { toolSymbol("lock.rotation.open") }
                .accessibilityLabel("横竖屏切换").accessibilityIdentifier("orbit.rotate")
            Button(action: actions.settings) {
                ZStack {
                    Image(systemName: "hexagon").font(.system(size: 25, weight: .medium))
                    Circle().strokeBorder(lineWidth: 1.8).frame(width: 8, height: 8)
                }.foregroundStyle(ink).frame(width: 44, height: 44).background(toolBackground)
            }.buttonStyle(.plain).accessibilityLabel("设置").accessibilityIdentifier("orbit.settings")
        }.padding(.trailing, width * 0.04).frame(width: width)
    }

    private func expandedFooter(size: CGSize) -> some View {
        ZStack {
            RoomMainNavigation(destination: $destination, playing: presentation.playing,
                canPlay: presentation.libraryReady && !presentation.albums.isEmpty,
                onToggle: actions.toggle, embedded: true, artwork: presentation.displayArtwork,
                reducedMotion: model.reducedMotion)
                .position(x: size.width * 0.5, y: 26)
            Button { changeChrome { chrome.editAppearance() } } label: {
                OrbitDiscArtwork(track: presentation.displayTrack, artwork: presentation.displayArtwork, style: style)
                    .frame(width: 29, height: 29).padding(3)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    .frame(width: 44, height: 44)
            }.buttonStyle(.plain).disabled(presentation.albums.isEmpty)
                .accessibilityLabel("唱片材质与背景").accessibilityIdentifier("orbit.appearance")
                .position(x: size.width * 0.117, y: 26)
            Menu { moreMenu } label: { toolSymbol("ellipsis") }
                .accessibilityLabel("更多").accessibilityIdentifier("orbit.more")
                .position(x: size.width * 0.895, y: 26)
        }.frame(width: size.width, height: 52)
    }

    private func toolSymbol(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 21, weight: .medium)).foregroundStyle(ink)
            .frame(width: 44, height: 44).background(toolBackground)
    }
    private var toolBackground: some View {
        Circle().fill(.white.opacity(0.075))
            .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.6))
    }

    private var emptyReadout: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(presentation.libraryReady ? "未在播放" : "正在读取本机曲库")
                .font(.system(size: 20, weight: .bold)).foregroundStyle(ink)
            Button("前往资料库", action: actions.library)
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.black)
                .padding(.horizontal, 14).frame(minHeight: 44)
                .background(.white, in: Capsule()).accessibilityIdentifier("orbit.empty.library")
        }
    }

    private var legacyPage: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if preferences.selectedHome == .wheel {
                OrbitWheelView(presentation: model, active: active && !legacyStyleVisible,
                               onSelectAlbum: actions.selectAlbum, onToggle: actions.toggle)
            } else {
                OrbitGridView(presentation: model, active: active && !legacyStyleVisible,
                              onSelectAlbum: actions.selectAlbum, onToggle: actions.toggle)
                    .padding(.top, 66).padding(.bottom, 128)
            }
            VStack {
                HStack {
                    Button("我的唱片", action: actions.craftedRecords).accessibilityIdentifier("orbit.crafted")
                    Spacer()
                    Menu { viewChoices } label: { Image(systemName: "square.grid.2x2").frame(width: 44, height: 44) }
                        .accessibilityLabel("切换首页视图").accessibilityIdentifier("orbit.views")
                    Menu { moreMenu } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                        .accessibilityLabel("更多").accessibilityIdentifier("orbit.more")
                }.padding(.horizontal, 18)
                Spacer()
                OrbitTransport(presentation: model, actions: actions, active: active) {
                    if let open = actions.openCurrent { open() } else { preferences.selectedHome = .turntable }
                }.padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder private var viewChoices: some View {
        ForEach(OrbitHomeMode.allCases) { mode in
            Button { preferences.selectedHome = mode } label: {
                Label(mode.title, systemImage: preferences.selectedHome == mode ? "checkmark" : mode.symbol)
            }.accessibilityIdentifier("orbit.view." + mode.rawValue)
        }
    }

    @ViewBuilder private var moreMenu: some View {
        if isTurntable {
            Menu("播放器视图", systemImage: "square.grid.2x2") { viewChoices }
                .accessibilityIdentifier("orbit.views")
        }
        if let opening = actions.recordOpening {
            Button("选片入场", systemImage: "square.stack.3d.up", action: opening).accessibilityIdentifier("orbit.recordOpening")
        }
        Button("制作与收藏唱片", systemImage: "square.stack.3d.up", action: actions.craftedRecords)
            .accessibilityIdentifier("orbit.crafted.menu")
        Button("封套与记忆", systemImage: "square.on.square", action: actions.sleeve)
            .disabled(presentation.albums.isEmpty).accessibilityIdentifier("unified.sleeve")
        Button("这首歌的记忆", systemImage: "text.bubble", action: actions.songMemories)
            .disabled(presentation.albums.isEmpty).accessibilityIdentifier("orbit.memories")
        if presentation.craftedSession != nil {
            Button("结束本次听音", systemImage: "stop.circle", action: actions.endListening).accessibilityIdentifier("unified.end")
        }
        Divider()
        Button("歌词", systemImage: "text.alignleft", action: actions.lyrics)
            .disabled(presentation.albums.isEmpty).accessibilityIdentifier("orbit.lyrics")
        Button("播放队列", systemImage: "list.bullet", action: actions.queue).accessibilityIdentifier("orbit.queue")
        if !isTurntable {
            Button("唱片外观", systemImage: "paintpalette") { legacyStyleVisible = true }.accessibilityIdentifier("orbit.appearance")
        }
        Divider()
        Button("添加音乐", systemImage: "plus", action: actions.importMusic).accessibilityIdentifier("orbit.import")
        Button("资料库", systemImage: "square.stack", action: actions.library).accessibilityIdentifier("orbit.library")
        Button("设置", systemImage: "gearshape", action: actions.settings).accessibilityIdentifier("orbit.settings")
    }

    private func revealTools() { changeChrome { chrome.reveal() } }
    private func changeChrome(_ change: () -> Void) {
        if model.reducedMotion { change() }
        else { withAnimation(.easeInOut(duration: 0.22), change) }
    }
}
