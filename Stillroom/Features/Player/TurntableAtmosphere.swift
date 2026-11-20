import SwiftUI

struct TurntableBackdrop: View, Equatable {
    let track: Track
    let artwork: UIImage?
    @State private var texture: UIImage?

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.track == rhs.track && lhs.artwork === rhs.artwork }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: 0x141820)
                if let texture {
                    Image(uiImage: texture).resizable().scaledToFill().opacity(0.65)
                        .frame(width: max(geometry.size.width, geometry.size.height) * 1.35,
                               height: max(geometry.size.width, geometry.size.height) * 1.35)
                        .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.36)
                }
                LinearGradient(colors: [.black.opacity(0.18), .black.opacity(0.1), .black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.task(id: "\(track.id)-\(artwork?.hash ?? 0)") {
            let rendered = await ArtworkRasterizer.atmosphere(track: track, artwork: artwork)
            guard !Task.isCancelled else { return }
            texture = rendered
        }.accessibilityHidden(true)
    }
}

/// The reference's small transport sits below the artwork, with no panel or progress strip.
struct TurntableTransport: View {
    let track: Track
    let playing: Bool
    let outgoing: Track?
    let titleProgress: Double
    let onToggle: () -> Void
    let onSkip: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            ZStack(alignment: .leading) {
                if let outgoing { information(outgoing).opacity(1 - titleProgress).accessibilityHidden(true) }
                information(track).opacity(titleProgress)
            }
            HStack(spacing: 12) {
                control(playing ? "pause.fill" : "play.fill", label: playing ? "暂停" : "播放", action: onToggle)
                    .accessibilityIdentifier("player.play")
                Spacer()
                control("backward.end.fill", label: "上一首", action: { onSkip(-1) })
                    .accessibilityIdentifier("player.previous")
                control("forward.end.fill", label: "下一首", action: { onSkip(1) })
                    .accessibilityIdentifier("player.next")
            }
        }.padding(.horizontal, 28)
    }

    private func information(_ item: Track) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title).font(.system(.headline)).foregroundStyle(.white)
                .lineLimit(2).accessibilityIdentifier(item.id == track.id ? "player.title" : "player.previous-title")
            Text(item.artist).font(.system(.caption)).foregroundStyle(.white.opacity(0.6)).lineLimit(2)
        }
    }

    private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                .frame(width: 44, height: 44).background(.black.opacity(0.2), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.06), lineWidth: 0.5))
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}
