import SwiftUI

/// Floating Liquid Glass bottom dock. Metadata and expansion follow the same
/// authoritative readout as the physical LCD. Remains mounted while the player
/// owns the scene so show/hide runs purely on GPU transforms with zero glass
/// or miniature-cassette teardown stutter.
struct OneTapeNavigation: View {
    let destination: OneTapeDestination
    let isVisible: Bool
    let customizationVisible: Bool
    let tapeStyle: OneTapeAppearance.TapeStyle
    let readout: OneTapePlaybackReadout
    let hasPlayedCurrentTrack: Bool
    let onPlayer: () -> Void
    let onLibrary: () -> Void
    let onInsights: () -> Void
    let onCustomize: () -> Void
    let onImport: () -> Void
    let onSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    @State private var playerActivation = 0
    @State private var libraryActivation = 0
    @State private var insightsActivation = 0
    @State private var customizeActivation = 0
    @State private var actionActivation = 0
    @State private var selectionFeedbackTick = 0
    @State private var chipPulse = false
    @State private var scrubTarget: OneTapeDestination?
    @State private var pillWidth: CGFloat = 0

    // Sleek 64pt floating dock matching Cassette 1.0.5 proportions.
    private let dockHeight: CGFloat = 64
    private let itemHeight: CGFloat = 52
    private let itemWidth: CGFloat = 54

    private var showsMetadata: Bool {
        readout.hasTrack && (readout.isPlaying || hasPlayedCurrentTrack)
    }

    private var activeTab: OneTapeDestination {
        scrubTarget ?? destination
    }

    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.80)
    }

    private var dockRevealAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return isVisible
            ? .spring(response: 0.36, dampingFraction: 0.86)
            : .spring(response: 0.25, dampingFraction: 0.95)
    }

    private var actionRevealAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return isVisible
            ? .spring(response: 0.40, dampingFraction: 0.84)
            : .spring(response: 0.22, dampingFraction: 0.95)
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 14) {
                    dock
                }
            } else {
                dock
            }
        }
        .buttonStyle(OneTapeDockPressStyle())
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .sensoryFeedback(.selection, trigger: selectionFeedbackTick)
    }

    private var dock: some View {
        HStack(alignment: .center, spacing: 0) {
            destinationPill
                .offset(y: isVisible || reduceMotion ? 0 : 88)
                .scaleEffect(isVisible || reduceMotion ? 1 : 0.94, anchor: .bottom)
                .opacity(isVisible ? 1 : 0)
                .animation(dockRevealAnimation, value: isVisible)
                .layoutPriority(1)

            Spacer(minLength: 12)

            contextAction
                .fixedSize()
                .offset(y: isVisible || reduceMotion ? 0 : 102)
                .scaleEffect(isVisible || reduceMotion ? 1 : 0.86, anchor: .bottom)
                .opacity(isVisible ? 1 : 0)
                .animation(actionRevealAnimation, value: isVisible)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(selectionAnimation, value: showsMetadata)
        .animation(selectionAnimation, value: activeTab)
    }

    // MARK: - Left Destination Pill (Tap + Horizontal Finger Scrub)

    private var destinationPill: some View {
        HStack(spacing: 2) {
            playerButton
            destinationButton(.library, icon: .library, activation: libraryActivation,
                              label: "磁带架", identifier: "nav.library") {
                selectDestination(.library)
            }
            destinationButton(.insights, icon: .insights, activation: insightsActivation,
                              label: "洞察", identifier: "nav.insights") {
                selectDestination(.insights)
            }
        }
        .padding(6)
        .frame(height: dockHeight)
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { pillWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in pillWidth = newWidth }
            }
        }
        .modifier(OneTapeNavigationSurface(shape: Capsule()))
        .simultaneousGesture(tabScrubGesture)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nav.destinations")
    }

    /// Horizontal finger-scrub across the 3 segments (iOS 26 Liquid Glass tab feel).
    /// Requires 16pt horizontal motion so normal quick taps go straight to buttons.
    private var tabScrubGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .local)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 0.8 else { return }
                let target = destinationForPillX(value.location.x)
                if scrubTarget != target {
                    scrubTarget = target
                    selectionFeedbackTick += 1
                }
            }
            .onEnded { value in
                guard let target = scrubTarget else { return }
                scrubTarget = nil
                if abs(value.translation.width) >= 16 {
                    selectDestination(target, triggerHaptic: false)
                }
            }
    }

    private func destinationForPillX(_ x: CGFloat) -> OneTapeDestination {
        let total = max(1, pillWidth)
        let insightsStart = total - 6 - itemWidth
        let libraryStart = insightsStart - 2 - itemWidth
        if x >= insightsStart { return .insights }
        if x >= libraryStart { return .library }
        return .player
    }

    private func selectDestination(_ target: OneTapeDestination, triggerHaptic: Bool = true) {
        let alreadySelected = (destination == target)
        switch target {
        case .player: playerActivation += 1
        case .library: libraryActivation += 1
        case .insights: insightsActivation += 1
        }
        if triggerHaptic { selectionFeedbackTick += 1 }

        if alreadySelected {
            triggerChipPulse()
        }

        switch target {
        case .player: onPlayer()
        case .library: onLibrary()
        case .insights: onInsights()
        }
    }

    private func triggerChipPulse() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.20, dampingFraction: 0.62), completionCriteria: .logicallyComplete) {
            chipPulse = true
        } completion: {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                chipPulse = false
            }
        }
    }

    private var playerButton: some View {
        Button {
            selectDestination(.player)
        } label: {
            HStack(spacing: 8) {
                OneTapeNavigationGlyph(kind: .player, activation: playerActivation)
                    .frame(width: 34, height: 30)
                if showsMetadata {
                    VStack(alignment: .leading, spacing: 2.5) {
                        Text(readout.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(readout.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(activeTab == .player ? 0.64 : 0.46))
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, showsMetadata ? 10 : 0)
            .frame(minWidth: itemWidth, maxWidth: showsMetadata ? .infinity : itemWidth)
            .frame(height: itemHeight)
            .background { playerSurface }
            .foregroundStyle(showsMetadata ? .white.opacity(activeTab == .player ? 0.96 : 0.74) : iconColor(.player))
            .contentShape(Capsule())
        }
        .accessibilityLabel(showsMetadata ? "播放器：\(readout.title)，\(readout.artist)" : "播放器")
        .accessibilityIdentifier("nav.nowPlaying")
        .accessibilityAddTraits(destination == .player ? .isSelected : [])
    }

    @ViewBuilder private var playerSurface: some View {
        ZStack {
            // Subtle resting pod behind the expanded track readout while viewing other tabs.
            if showsMetadata, activeTab != .player {
                Capsule().fill(.white.opacity(0.055))
            }
            // Unified matched-geometry luminous selection lens glides smoothly from/to every tab.
            selectionLens(.player)
        }
    }

    private func destinationButton(_ target: OneTapeDestination, icon: OneTapeNavigationGlyph.Kind,
                                   activation: Int, label: String, identifier: String,
                                   action: @escaping () -> Void) -> some View {
        Button(action: action) {
            OneTapeNavigationGlyph(kind: icon, activation: activation)
                .frame(width: 28, height: 29)
                .frame(width: itemWidth, height: itemHeight)
                .foregroundStyle(iconColor(target))
                .background { selectionLens(target) }
                .contentShape(Capsule())
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(destination == target ? .isSelected : [])
    }

    /// Luminous inner glass selection lens that glides smoothly across all three
    /// destinations (including expanding/contracting around the Now Playing chip)
    /// and gently pulses in place when re-tapping the current tab.
    @ViewBuilder private func selectionLens(_ target: OneTapeDestination) -> some View {
        if activeTab == target {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(scrubTarget != nil ? 0.22 : 0.16),
                            .white.opacity(scrubTarget != nil ? 0.12 : 0.09)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.28), .white.opacity(0.06)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.7
                        )
                }
                .scaleEffect(chipPulse ? 1.045 : (scrubTarget != nil ? 1.03 : 1.0))
                .matchedGeometryEffect(id: "nav.selection", in: selection)
        }
    }

    // MARK: - Right Contextual Action Circle

    private var contextAction: some View {
        Button {
            selectionFeedbackTick += 1
            switch destination {
            case .player:
                customizeActivation += 1
                onCustomize()
            case .library:
                actionActivation += 1
                onImport()
            case .insights:
                actionActivation += 1
                onSettings()
            }
        } label: {
            ZStack {
                if destination == .player {
                    OneTapeCustomiseTapeIcon(
                        tapeStyle: tapeStyle,
                        selected: customizationVisible,
                        taps: customizeActivation
                    )
                    .transition(.scale(scale: 0.74).combined(with: .opacity))
                } else {
                    actionSymbol
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.white.opacity(0.86))
                        .transition(.scale(scale: 0.74).combined(with: .opacity))
                }
            }
            .frame(width: dockHeight, height: dockHeight)
            .modifier(OneTapeNavigationSurface(shape: Circle()))
            .contentShape(Circle())
        }
        .accessibilityLabel(actionLabel)
        .accessibilityIdentifier(actionIdentifier)
        .accessibilityAddTraits(destination == .player && customizationVisible ? .isSelected : [])
    }

    @ViewBuilder private var actionSymbol: some View {
        if reduceMotion {
            Image(systemName: actionSymbolName)
        } else {
            Image(systemName: actionSymbolName)
                .symbolEffect(.bounce.byLayer, value: actionActivation)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private var actionSymbolName: String {
        switch destination {
        case .player: "swatchpalette"
        case .library: "plus"
        case .insights: "gearshape"
        }
    }

    private var actionLabel: String {
        switch destination {
        case .player: "自定义播放器"
        case .library: "导入音乐"
        case .insights: "设置"
        }
    }

    private var actionIdentifier: String {
        switch destination {
        case .player: "nav.customize"
        case .library: "nav.import"
        case .insights: "nav.settings"
        }
    }

    private func iconColor(_ target: OneTapeDestination) -> Color {
        .white.opacity(activeTab == target ? 0.96 : 0.54)
    }
}

/// Miniature tilted cassette preview for the bottom-right customize circle,
/// matching Cassette 1.0.5's 46×29 icon geometry inside a 64pt glass circle,
/// GPU-cached via `.drawingGroup()` so dock reveal glides at 120 FPS.
private struct OneTapeCustomiseTapeIcon: View {
    let tapeStyle: OneTapeAppearance.TapeStyle
    let selected: Bool
    let taps: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hop = false

    private let iconWidth: CGFloat = 46
    private let iconHeight: CGFloat = 29

    private var previewAppearance: OneTapeAppearance {
        var value = OneTapeAppearance()
        value.tapeStyle = tapeStyle
        value.printStyle = .blank
        return value
    }

    var body: some View {
        tapeArtwork
            .frame(width: iconWidth, height: iconHeight)
            .clipShape(RoundedRectangle(cornerRadius: 3.6, style: .continuous))
            .drawingGroup()
            .shadow(color: .black.opacity(0.35), radius: 2.5, x: 0, y: 1.5)
            .rotationEffect(.degrees(hop && !reduceMotion ? -12 : -6))
            .scaleEffect(hop && !reduceMotion ? 1.12 : 1)
            .opacity(selected ? 1 : 0.92)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(.white.opacity(selected ? 0.88 : 0))
                    .frame(width: 14, height: 2.4)
                    .offset(y: 8)
            }
            .onChange(of: taps) { _, _ in
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.54),
                              completionCriteria: .logicallyComplete) {
                    hop = true
                } completion: {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                        hop = false
                    }
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.9), value: selected)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var tapeArtwork: some View {
        let canvas = OneTapeCassetteStandard.portraitCanvasSize
        let shell = OneTapeCassetteStandard.portraitShellFrame
        let scale = max(iconWidth / (shell.height - 2), iconHeight / (shell.width - 2))
        return OneTapeCassetteArtwork(
            appearance: previewAppearance,
            showsPrint: false,
            showsFineTexture: false
        )
        .frame(width: canvas.width, height: canvas.height)
        .scaleEffect(scale)
        .rotationEffect(.degrees(-90))
        .frame(width: iconWidth, height: iconHeight)
    }
}

private struct OneTapeNavigationSurface<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.modifier(OneTapeGlassSurface(shape: shape))
        }
    }
}

/// Tactile press-down spring & subtle luminous lift active across all iOS
/// versions (including iOS 26+) so every dock tap feels immediate and crisp.
struct OneTapeDockPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.92 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.20, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}
