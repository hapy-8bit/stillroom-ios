import SwiftUI

/// Main destinations are independent of the wheel/grid/turntable presentation preference.
enum RoomDestination: String, CaseIterable {
    case library, player, queue

    var title: String {
        switch self {
        case .library: return "资料库"
        case .player: return "正在播放"
        case .queue: return "播放队列"
        }
    }

    var symbol: String {
        switch self {
        case .library: return "books.vertical.fill"
        case .player: return "opticaldisc"
        case .queue: return "text.line.first.and.arrowtriangle.forward"
        }
    }
}

/// The original library exposes these destinations in a floating capsule. All buttons here
/// submit navigation or audio intent; the selected page never owns another playback flag.
struct RoomMainNavigation: View {
    @Binding var destination: RoomDestination
    let playing: Bool
    let canPlay: Bool
    let onToggle: () -> Void
    var embedded = false
    var artwork: UIImage? = nil
    var reducedMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 2) {
            destinationButton(.library)
            HStack(spacing: 0) {
                destinationButton(.player)
                Button(action: onToggle) {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(iconColor(for: .player))
                        .frame(width: 44, height: embedded ? 42 : 48)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(!canPlay)
                    .accessibilityLabel(playing ? "暂停" : "播放")
                    .accessibilityIdentifier("room.navigation.play")
            }.background { selectionBackground(for: .player) }
            destinationButton(.queue)
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
        .padding(.horizontal, embedded ? 0 : 20).padding(.vertical, embedded ? 0 : 8)
        .frame(maxWidth: embedded ? nil : .infinity)
        .environment(\.colorScheme, .dark)
        // Selection owns this short visual transition only. Repeated taps retarget the
        // same SwiftUI animation; they never schedule delayed navigation or audio work.
        .animation(reducedMotion || systemReducedMotion ? nil : .easeInOut(duration: 0.22), value: destination)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("room.navigation")
    }

    private func destinationButton(_ target: RoomDestination) -> some View {
        Button { destination = target } label: {
            Group {
                if target == .player, let artwork {
                    Image(uiImage: artwork).resizable().scaledToFill()
                        .frame(width: 25, height: 25).clipShape(Circle())
                        .saturation(destination == target ? 1 : 0.55)
                        .opacity(destination == target ? 1 : 0.58)
                } else {
                    Image(systemName: target.symbol).font(.system(size: 21))
                        .foregroundStyle(iconColor(for: target))
                }
            }
                .frame(width: 52, height: embedded ? 42 : 48)
                .contentShape(Rectangle())
                .background {
                    if target != .player { selectionBackground(for: target) }
                }
        }.buttonStyle(.plain)
            .accessibilityLabel(target.title)
            .accessibilityAddTraits(destination == target ? .isSelected : [])
            .accessibilityIdentifier("room.navigation." + target.rawValue)
    }

    private func iconColor(for target: RoomDestination) -> Color {
        .white.opacity(destination == target ? 1 : 0.52)
    }

    @ViewBuilder private func selectionBackground(for target: RoomDestination) -> some View {
        if destination == target {
            Capsule()
                .fill(.white.opacity(0.16))
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.6))
                .matchedGeometryEffect(id: "room.destination.selection", in: selectionNamespace)
        }
    }
}
