import SwiftUI

/// Album, artist and license stay beside the actual recording, without adding print over the
/// original cover. Source links are optional presentation metadata, not playback adapters.
struct ReferenceAlbumCreditView: View {
    let track: Track

    var body: some View {
        if let credit = BundledAlbumCatalog.credit(for: track.id) {
            VStack(alignment: .leading, spacing: 8) {
                Text(track.album + " · " + String(credit.year)).font(.subheadline.weight(.medium))
                Text("\(track.title) — \(track.artist)").font(.caption)
                Text("本机收录这张专辑的 1 首原曲。")
                    .font(.caption).foregroundStyle(.secondary)
                Link("艺人官网 · 专辑与完整曲目", destination: credit.albumPage)
                    .accessibilityIdentifier("room.library.reference.source")
                Link("Music licensed under CC BY 4.0", destination: credit.license)
                    .accessibilityIdentifier("room.library.reference.license")
                if let artworkCredit = credit.artworkCredit {
                    Text(artworkCredit).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .font(.caption).foregroundStyle(.white.opacity(0.8))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("room.library.reference.credit")
        }
    }
}
