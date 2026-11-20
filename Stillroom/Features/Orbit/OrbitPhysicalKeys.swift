import SwiftUI

/// Shallow key bodies and printed legends are distinct. Hit areas stay at least 44 points.
struct OrbitPhysicalKeys: View {
    let presentation: OrbitPlaybackPresentation
    let actions: OrbitHomeActions
    let width: CGFloat
    let lightContent: Bool

    private var boundary: Bool { presentation.craftedSession.map { $0.phase != .listening } ?? false }
    private var ink: Color { lightContent ? .white : Color(white: 0.12) }
    private var canPlay: Bool { presentation.libraryReady && !presentation.albums.isEmpty }
    private var playLabel: String {
        if presentation.craftedSession?.phase == .awaitingFlip { return "A 面已播放完，请翻面" }
        if presentation.queueFinished || presentation.craftedSession?.phase == .finished { return "从头重听" }
        return presentation.playing ? "暂停" : "播放"
    }

    var body: some View {
        HStack(alignment: .top, spacing: width * 0.065) {
            key("PLAY", symbol: nil, label: playLabel,
                identifier: "orbit.play", action: actions.toggle)
                .disabled(!canPlay || presentation.craftedSession?.phase == .awaitingFlip)
            Spacer(minLength: 0)
            key(nil, symbol: "backward.end.fill", label: "上一首", identifier: "orbit.previous") { actions.skip(-1) }
                .disabled(!canPlay)
            key(nil, symbol: "forward.end.fill", label: "下一首", identifier: "orbit.next") { actions.skip(1) }
                .disabled(!canPlay || boundary)
        }.padding(.horizontal, width * 0.09)
            .accessibilityElement(children: .contain).accessibilityIdentifier("orbit.physicalKeys")
    }

    private func key(_ title: String?, symbol: String?, label: String,
                     identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Capsule().fill(LinearGradient(colors: [Color(white: 0.19), Color(white: 0.11)],
                                             startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.065), lineWidth: 0.7)).padding(2)
                    .background(.black.opacity(0.24), in: Capsule())
                    .shadow(color: .black.opacity(0.65), radius: 2, y: 2)
                    .frame(width: max(48, width * 0.151), height: max(23, width * 0.0645))
                Group {
                    if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .bold)) }
                    else { Text(title ?? "").font(.system(size: 9, weight: .regular)) }
                }.foregroundStyle(ink.opacity(0.9)).frame(height: 12)
            }.frame(minWidth: 44, minHeight: 52, alignment: .top).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier(identifier)
    }
}
