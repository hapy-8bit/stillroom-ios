import SwiftUI

/// Metadata and expansion follow the same engine readout as the physical LCD.
struct OneTapeNavigation: View {
    let destination: OneTapeDestination
    let customizationVisible: Bool
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
    @State private var actionActivation = 0

    // Both glass surfaces share logical-point height and vertical center.
    private let dockHeight: CGFloat = 72
    private let itemHeight: CGFloat = 60
    private let itemWidth: CGFloat = 56
    // A catalog may preselect a song before it has ever played. Real listening
    // history keeps an actual paused session expanded, including after restore.
    private var showsMetadata: Bool {
        readout.hasTrack && (readout.isPlaying || hasPlayedCurrentTrack)
    }
    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .spring(duration: 0.34, bounce: 0.12)
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            // Render the two separate surfaces in one native glass context.
            // Zero joining distance preserves their gap as metadata expands.
            GlassEffectContainer(spacing: 0) {
                dock
            }
            .buttonStyle(.plain)
        } else {
            dock.buttonStyle(OneTapeNavigationPressStyle())
        }
    }

    private var dock: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 2) {
                playerButton
                destinationButton(.library, icon: .library, activation: libraryActivation,
                                  label: "磁带架", identifier: "nav.library") {
                    libraryActivation += 1
                    onLibrary()
                }
                destinationButton(.insights, icon: .insights, activation: insightsActivation,
                                  label: "洞察", identifier: "nav.insights") {
                    insightsActivation += 1
                    onInsights()
                }
            }
            .padding(6)
            .frame(height: dockHeight)
            .modifier(OneTapeNavigationSurface(shape: Capsule()))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("nav.destinations")
            .layoutPriority(1)

            Spacer(minLength: 12)
            contextAction
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(selectionAnimation, value: showsMetadata)
        .animation(selectionAnimation, value: destination)
    }

    private var playerButton: some View {
        Button {
            playerActivation += 1
            withAnimation(selectionAnimation) { onPlayer() }
        } label: {
            HStack(spacing: 8) {
                OneTapeNavigationGlyph(kind: .player, activation: playerActivation)
                    .frame(width: 36, height: 32)
                if showsMetadata {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(readout.title).font(.system(size: 13, weight: .semibold))
                        Text(readout.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.58))
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
            .foregroundStyle(showsMetadata ? .white.opacity(0.96) : iconColor(.player))
            .contentShape(Capsule())
        }
        .accessibilityLabel(showsMetadata ? "播放器：\(readout.title)，\(readout.artist)" : "播放器")
        .accessibilityIdentifier("nav.nowPlaying")
        .accessibilityAddTraits(destination == .player ? .isSelected : [])
    }

    @ViewBuilder private var playerSurface: some View {
        if showsMetadata {
            // This is the expanded player item, not the moving page selection.
            // Its song and surface stay together while another page is active.
            Capsule().fill(.white.opacity(destination == .player ? 0.14 : 0.075))
        } else {
            selectionBackground(.player)
        }
    }

    private func destinationButton(_ target: OneTapeDestination, icon: OneTapeNavigationGlyph.Kind,
                                   activation: Int, label: String, identifier: String,
                                   action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(selectionAnimation) { action() }
        } label: {
            OneTapeNavigationGlyph(kind: icon, activation: activation)
                .frame(width: 31, height: 32)
                .frame(width: itemWidth, height: itemHeight)
                .foregroundStyle(iconColor(target))
                .background { selectionBackground(target) }
                .contentShape(Capsule())
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(destination == target ? .isSelected : [])
    }

    private var contextAction: some View {
        Button {
            actionActivation += 1
            withAnimation(selectionAnimation) {
                switch destination {
                case .player: onCustomize()
                case .library: onImport()
                case .insights: onSettings()
                }
            }
        } label: {
            actionSymbol
            .font(.system(size: 25, weight: .regular))
            .foregroundStyle(.white.opacity(0.8))
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
        .white.opacity(destination == target ? 0.96 : 0.55)
    }

    @ViewBuilder private func selectionBackground(_ target: OneTapeDestination) -> some View {
        if destination == target {
            Capsule().fill(.white.opacity(0.1))
                .matchedGeometryEffect(id: "nav.selection", in: selection)
        }
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

private struct OneTapeNavigationPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.74 : 1)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.94 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
