import SwiftUI

struct AlbumDetailScreen: View {
    @EnvironmentObject private var player: PlayerStore
    let track: Track

    var body: some View {
        ZStack {
            RoomBackground()
            ScrollView {
                VStack(spacing: 19) {
                    ArtworkView(track: track, image: player.albumArtworks[track.id], printed: true)
                        .frame(maxWidth: 280).padding(.horizontal, 40)
                        .shadow(color: .black.opacity(0.35), radius: 20, y: 16)
                    VStack(spacing: 9) {
                        Text(track.album).font(RoomStyle.serif(32)).foregroundStyle(RoomStyle.paper)
                        Text(track.artist).font(.system(size: 13)).foregroundStyle(RoomStyle.secondary)
                        Text("\(player.albumTracks(track).count) 首 · \(track.isDemo ? "随附音乐" : "本地收藏")")
                            .font(.system(size: 11)).foregroundStyle(RoomStyle.muted)
                    }.padding(.top, 12)
                    Button {
                        let items = player.albumTracks(track)
                        if let first = items.first { player.choose(first, in: items); player.showingPlayer = true }
                    } label: {
                        Label("播放这张唱片", systemImage: "play.fill").font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(RoomStyle.paper, in: Capsule()).foregroundStyle(RoomStyle.background)
                    }.buttonStyle(.plain).padding(.horizontal, 42).padding(.vertical, 8)
                        .accessibilityIdentifier("album.play")
                    Menu("歌词与封面", systemImage: "photo.on.rectangle") {
                        Button("导入歌词") { player.importRequest = .lyrics(trackID: track.id) }
                        Button("仅替换这首歌曲封面") { player.importRequest = .cover(trackID: track.id, album: false) }
                        Button("替换整张专辑封面") { player.importRequest = .cover(trackID: track.id, album: true) }
                    }.accessibilityIdentifier("album.media")
                    VStack(spacing: 0) {
                        ForEach(player.albumTracks(track)) { item in
                            TrackRow(track: item, image: player.artworks[item.id], active: player.current.id == item.id,
                                     playing: player.isPlaying) { player.choose(item, in: player.albumTracks(track)) }
                        }
                    }.padding(.horizontal, 25)
                }.padding(.top, 20).padding(.bottom, 30)
            }.scrollIndicators(.hidden)
        }.navigationTitle("专辑").navigationBarTitleDisplayMode(.inline).toolbarBackground(.hidden, for: .navigationBar)
    }
}

