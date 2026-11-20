import SwiftUI

/// The root keeps this scene in the same artwork namespace as the listening room, with no modal presenter.
struct AlbumGalleryScreen: View {
    @EnvironmentObject private var player: PlayerStore
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    let albums: [Track]
    let artworkTransition: Namespace.ID
    @State private var selection: Int
    private var reducedMotion: Bool { player.reducedMotion || systemReducedMotion }
    private var focused: Track? { albums.indices.contains(selection) ? albums[selection] : albums.first }

    init(albums: [Track], focusedKey: String, artworkTransition: Namespace.ID) {
        self.albums = albums
        self.artworkTransition = artworkTransition
        _selection = State(initialValue: albums.firstIndex { $0.albumKey == focusedKey } ?? 0)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoomBackground()
                ScrollView {
                    VStack(spacing: 0) {
                        header.padding(.horizontal, 24).padding(.top, 12)
                        AlbumCoverFlow(albums: albums, artworks: player.artworks, selection: $selection,
                                       side: min(geometry.size.width * 0.67, max(180, geometry.size.height * 0.4)),
                                       artworkTransition: reducedMotion ? nil : artworkTransition,
                                       reducedMotion: reducedMotion, onChoose: placeOnTurntable)
                            .padding(.top, 24)
                        if let focused {
                            information(focused).padding(.horizontal, 28).padding(.top, 16)
                            Button { playAlbum(focused) } label: {
                                Label("聆听这张专辑", systemImage: "play.fill").font(.system(.subheadline, weight: .medium))
                                    .frame(maxWidth: .infinity).frame(minHeight: 48)
                                    .foregroundStyle(RoomStyle.background).background(RoomStyle.paper, in: Capsule())
                            }.buttonStyle(.plain).padding(.horizontal, 42).padding(.vertical, 24)
                                .accessibilityIdentifier("album.play")
                            VStack(spacing: 0) {
                                ForEach(player.albumTracks(focused)) { track in
                                    TrackRow(track: track, image: player.artworks[track.id], active: player.current.id == track.id,
                                             playing: player.isPlaying) {
                                        player.choose(track, in: player.albumTracks(focused))
                                        player.showingShelf = false
                                        player.showingPlayer = true
                                    }
                                }
                            }.padding(.horizontal, 24)
                        } else {
                            ContentUnavailableView("还没有专辑", systemImage: "square.stack", description: Text("导入音乐后，封面会出现在这里。"))
                        }
                    }.padding(.bottom, 36)
                }.scrollIndicators(.hidden)
            }
        }.accessibilityIdentifier("gallery.scene")
            .accessibilityAction(.escape) { player.showingShelf = false }
    }

    private var header: some View {
        HStack {
            RoundControl(symbol: "chevron.down", label: "收起唱片廊", action: { player.showingShelf = false })
                .accessibilityIdentifier("gallery.close")
            Spacer()
            Text("唱片廊").font(.system(.headline, design: .serif)).foregroundStyle(RoomStyle.paper)
            Spacer()
            Text(String(format: "%02d", albums.count)).font(RoomStyle.caption(11)).foregroundStyle(RoomStyle.secondary)
                .frame(width: 44, height: 44)
        }
    }

    private func information(_ track: Track) -> some View {
        VStack(spacing: 9) {
            Text(track.album).font(.system(.title, design: .serif)).foregroundStyle(RoomStyle.paper)
                .multilineTextAlignment(.center).accessibilityIdentifier("gallery.album-title")
            Text(track.artist).font(.system(.subheadline)).foregroundStyle(RoomStyle.secondary)
            Text("\(min(selection + 1, albums.count)) / \(albums.count)  ·  \(player.albumTracks(track).count) 首")
                .font(RoomStyle.caption(10)).foregroundStyle(RoomStyle.muted)
        }.frame(maxWidth: .infinity)
    }

    private func placeOnTurntable(_ track: Track) {
        // Preserve a pending audio-session activation as well as an already audible playback.
        player.choose(track, in: player.albumTracks(track), autoplay: player.isPlaying || player.snapshot.isPreparing)
        player.showingShelf = false
    }

    private func playAlbum(_ track: Track) {
        guard let first = player.albumTracks(track).first else { return }
        player.choose(first, in: player.albumTracks(track))
        player.showingShelf = false
        player.showingPlayer = true
    }
}
