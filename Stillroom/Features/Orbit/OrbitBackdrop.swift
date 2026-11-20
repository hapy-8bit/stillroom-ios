import SwiftUI

/// A deck-wide atmosphere derived only from the supplied artwork. The small blur texture
/// changes with artwork identity, never with playback ticks or the disc's visual rotation.
struct OrbitBackdrop: View {
    let presentation: OrbitPlaybackPresentation
    let background: OrbitBackground
    var customBackgroundHex = "0B1420"
    @State private var artworkTexture: UIImage?

    private var artwork: UIImage? { presentation.displayArtwork ?? presentation.albumArtwork }
    private var artworkKey: String {
        "\(presentation.displayTrack.id)|\(artwork?.hash ?? 0)|\(background.rawValue)"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if background == .atmosphere {
                    atmosphere(size: geometry.size)
                } else if background == .spectrum {
                    LinearGradient(colors: [Color(hex: 0x6275B7), Color(hex: 0x9C777D),
                                            Color(hex: 0x315B67), Color(hex: 0x0A1018)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                } else if background == .custom {
                    OrbitInk.color(customBackgroundHex)
                } else {
                    Color(hex: background.hex)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .task(id: artworkKey) {
            guard background == .atmosphere else { artworkTexture = nil; return }
            let texture = await ArtworkRasterizer.atmosphere(track: presentation.displayTrack, artwork: artwork)
            // A newer album or a dismissed picker cancels the owning task. Do not install
            // its older texture into the currently displayed record's background.
            guard !Task.isCancelled else { return }
            artworkTexture = texture
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func atmosphere(size: CGSize) -> some View {
        ZStack {
            Color(hex: 0x101923)
            if let artworkTexture {
                Image(uiImage: artworkTexture).resizable().scaledToFill()
                    .frame(width: size.width, height: size.height).clipped()
                    .saturation(0.55).opacity(0.42)
            }
            // The reference keeps a quiet gray plinth around the upper hardware and an
            // almost-black lower control area. Artwork tint shows through the middle band.
            LinearGradient(stops: [
                .init(color: Color(hex: 0x5E6259).opacity(0.94), location: 0),
                .init(color: Color(hex: 0x555B54).opacity(0.88), location: 0.19),
                .init(color: Color(hex: 0x24343B).opacity(0.44), location: 0.42),
                .init(color: Color(hex: 0x07111B).opacity(0.90), location: 0.67),
                .init(color: Color(hex: 0x050B12).opacity(0.99), location: 0.83),
                .init(color: Color(hex: 0x050A10), location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
    }
}
