import SwiftUI

struct PlayerControls: View {
    let track: Track
    let playing: Bool
    let position: Double
    let duration: Double
    let favorite: Bool
    let shuffled: Bool
    let repeatMode: RepeatMode
    let onFavorite: () -> Void
    let onSeek: (Double) -> Void
    let onShuffle: () -> Void
    let onSkip: (Int) -> Void
    let onToggle: () -> Void
    let onRepeat: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(track.title).font(.system(.title, design: .serif))
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("player.title")
                    Text(track.artist).font(.system(.subheadline)).foregroundStyle(RoomStyle.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                icon(favorite ? "heart.fill" : "heart", label: favorite ? "取消喜欢" : "喜欢这首歌",
                     color: favorite ? RoomStyle.copper : RoomStyle.paper, action: onFavorite)
                    .accessibilityIdentifier("player.favorite")
            }
            VStack(spacing: 0) {
                ProgressScrubber(position: position, duration: duration, onSeek: onSeek).id(track.id)
                HStack {
                    Text(MediaTime.label(position)).accessibilityIdentifier("player.elapsed")
                    Spacer()
                    Text("−" + MediaTime.label(max(0, duration - position)))
                }.font(RoomStyle.caption(10)).monospacedDigit().foregroundStyle(RoomStyle.secondary)
                    .padding(.top, -2)
            }
            HStack(spacing: 0) {
                icon("shuffle", label: shuffled ? "关闭随机播放" : "随机播放",
                     color: shuffled ? RoomStyle.accent : RoomStyle.muted, action: onShuffle)
                    .accessibilityIdentifier("player.shuffle")
                Spacer(minLength: 0)
                icon("backward.end.fill", label: "上一首", size: 25) { onSkip(-1) }
                    .accessibilityIdentifier("player.previous")
                Spacer(minLength: 0)
                Button(action: onToggle) {
                    Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 25, weight: .medium))
                        .offset(x: playing ? 0 : 2).frame(width: 72, height: 72)
                        .foregroundStyle(RoomStyle.background).background(RoomStyle.paper, in: Circle())
                }.buttonStyle(.plain).accessibilityLabel(playing ? "暂停" : "播放").accessibilityIdentifier("player.play")
                Spacer(minLength: 0)
                icon("forward.end.fill", label: "下一首", size: 25) { onSkip(1) }
                    .accessibilityIdentifier("player.next")
                Spacer(minLength: 0)
                icon(repeatMode.symbol, label: repeatMode.label,
                     color: repeatMode == .off ? RoomStyle.muted : RoomStyle.accent, action: onRepeat)
                    .accessibilityIdentifier("player.repeat")
            }.padding(.top, 6)
        }.foregroundStyle(RoomStyle.paper)
    }

    private func icon(_ symbol: String, label: String, size: CGFloat = 20, color: Color = RoomStyle.paper,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size, weight: .light)).foregroundStyle(color)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}
