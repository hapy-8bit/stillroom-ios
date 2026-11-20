import SwiftUI

enum ListeningCollection: Identifiable {
    case favorites
    case album(Track)

    var id: String {
        switch self {
        case .favorites: return "favorites"
        case .album(let track): return "album-" + track.albumKey
        }
    }
}

struct ListeningCollectionSheet: View {
    @EnvironmentObject private var player: PlayerStore
    @Environment(\.dismiss) private var dismiss
    let selection: ListeningCollection

    private var favorites: [Track] { player.tracks.filter { player.favorites.contains($0.id) } }

    var body: some View {
        NavigationStack {
            Group {
                switch selection {
                case .album(let track):
                    AlbumDetailScreen(track: track)
                case .favorites:
                    ZStack {
                        RoomBackground()
                        if favorites.isEmpty {
                            ContentUnavailableView("还没有喜欢的音乐", systemImage: "heart",
                                                   description: Text("在播放器里点亮爱心，收好想再听的声音。"))
                                .foregroundStyle(RoomStyle.secondary)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(favorites) { track in
                                        TrackRow(track: track, image: player.artworks[track.id],
                                                 active: player.current.id == track.id, playing: player.isPlaying) {
                                            player.choose(track, in: favorites)
                                        }
                                    }
                                }.padding(.horizontal, 24).padding(.top, 16)
                            }
                        }
                    }.navigationTitle("喜欢的音乐").navigationBarTitleDisplayMode(.inline)
                }
            }.toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.accessibilityIdentifier("home.collection.close")
                }
            }.toolbarBackground(.hidden, for: .navigationBar)
        }.tint(RoomStyle.accent).preferredColorScheme(.dark)
    }
}
