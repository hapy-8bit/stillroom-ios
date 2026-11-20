import SwiftUI

/// A page within the listening scene. The parent owns the one continuous vertical scroll.
struct ListeningHome: View {
    @EnvironmentObject private var player: PlayerStore
    @State private var collection: ListeningCollection?
    @State private var foldExpansion = 0.0
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    let width: CGFloat
    let onReturn: () -> Void

    private var favorites: [Track] { player.tracks.filter { player.favorites.contains($0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            header.padding(.horizontal, 24)
            CollectionFolds(localCount: player.tracks.filter { !$0.isDemo }.count,
                            albumCount: Set(player.tracks.filter { !$0.isDemo }.map(\.albumKey)).count,
                            favoriteCount: favorites.count, demoCount: player.tracks.filter(\.isDemo).count,
                            expansion: $foldExpansion, reducedMotion: player.reducedMotion || systemReducedMotion,
                            onImport: { player.showingImport = true }, onAlbums: { player.presentAlbums() },
                            onFavorites: { collection = .favorites }, onSamples: {
                                if let sample = Track.demos.randomElement() { player.choose(sample, in: Track.demos) }
                            })
                .padding(.horizontal, 24)
            MechanicalNowCard(track: player.current, artwork: player.artworks[player.current.id],
                             playing: player.isPlaying, position: player.position, duration: player.duration,
                             ordinal: (player.tracks.firstIndex(where: { $0.id == player.current.id }) ?? 0) + 1,
                             total: player.tracks.count, reducedMotion: player.reducedMotion || systemReducedMotion,
                             onOpen: { player.showingPlayer = true }, onToggle: player.toggle,
                             onNext: { player.skip(1) })
                .padding(.horizontal, 24)
            albums
        }.padding(.top, 22).padding(.bottom, 28)
            .sheet(item: Binding(get: { player.showingPlayer ? nil : collection }, set: { collection = $0 })) { selection in
                ListeningCollectionSheet(selection: selection).environmentObject(player)
                    .presentationDragIndicator(.visible)
            }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR LISTENING ROOM").font(RoomStyle.caption(8)).tracking(2).foregroundStyle(RoomStyle.muted)
                Text("随手听听").font(.system(.largeTitle, design: .serif)).foregroundStyle(RoomStyle.paper)
            }
            Spacer()
            RoundControl(symbol: "chevron.down", label: "回到唱片", size: 42, action: onReturn)
                .accessibilityIdentifier("listen.return")
        }
    }

    private var albums: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Text("从一张唱片开始").font(.system(.headline, design: .serif)).foregroundStyle(RoomStyle.paper)
                Spacer()
                Button { player.presentAlbums() } label: {
                    HStack(spacing: 4) {
                        Text("唱片架")
                        Image(systemName: "arrow.right").font(.system(size: 9))
                    }.font(.system(size: 11)).foregroundStyle(RoomStyle.secondary).frame(minHeight: 30)
                }.buttonStyle(.plain).accessibilityIdentifier("home.shelf")
            }.padding(.horizontal, 24)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(player.albums()) { track in
                        ListeningAlbumCard(track: track, artwork: player.artworks[track.id],
                                           active: player.current.albumKey == track.albumKey) { player.presentAlbums(focusing: track) }
                            .frame(width: min(160, max(120, (width - 64) * 0.43)))
                    }
                }.scrollTargetLayout().padding(.horizontal, 24)
            }.scrollIndicators(.hidden).scrollTargetBehavior(.viewAligned)
        }
    }
}
