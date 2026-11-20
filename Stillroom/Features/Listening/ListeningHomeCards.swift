import SwiftUI

struct ListeningAlbumCard: View {
    let track: Track
    let artwork: UIImage?
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ArtworkView(track: track, image: artwork, printed: true)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(alignment: .bottomTrailing) {
                        if active {
                            Image(systemName: "waveform").font(.system(size: 10))
                                .foregroundStyle(RoomStyle.paper).padding(8)
                                .background(RoomStyle.background.opacity(0.8), in: Circle()).padding(7)
                        }
                    }
                Text(track.album).font(.system(.subheadline, design: .serif)).lineLimit(1)
                    .foregroundStyle(RoomStyle.paper)
                Text(track.artist)
                    .font(RoomStyle.caption(8))
                    .foregroundStyle(RoomStyle.secondary).lineLimit(1)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("专辑，\(track.album)")
            .accessibilityIdentifier("home.album." + track.id)
    }
}
