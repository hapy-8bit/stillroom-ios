import SwiftUI

/// Separate cover artwork inside native case frames. The clipped outer columns
/// and staggered rows belong to the Studio header, not a repeating page texture.
struct OneTapeStudioMontage: View {
    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 393
            ZStack(alignment: .topLeading) {
                cases(scale: scale)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                    .mask {
                        fade([
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.4),
                            .init(color: .clear, location: 0.76)
                        ])
                    }
                cases(scale: scale)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                    .blur(radius: 11 * scale)
                    .mask {
                        fade([
                            .init(color: .clear, location: 0.38),
                            .init(color: .black, location: 0.76),
                            .init(color: .black, location: 1)
                        ])
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .overlay {
                fade([
                    .init(color: .black.opacity(0.21), location: 0),
                    .init(color: .black.opacity(0.24), location: 0.4),
                    .init(color: .black.opacity(0.54), location: 0.73),
                    .init(color: .black.opacity(0.9), location: 1)
                ])
            }
            .mask {
                fade([
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.6),
                    .init(color: .clear, location: 1)
                ])
            }
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func cases(scale: CGFloat) -> some View {
        // These are logical reference-header coordinates. Scale the complete
        // case spacing once with the window width, never with resource pixels.
        ZStack(alignment: .topLeading) {
            column([3, 6, 9], x: -64, y: 0, scale: scale)
            column([5, 8, 0], x: 42, y: -60, scale: scale)
            column([7, 1, 4], x: 148, y: -120, scale: scale)
            column([10, 6, 3], x: 254, y: -22, scale: scale)
            column([8, 11, 2], x: 360, y: -85, scale: scale)
        }
    }

    private func column(_ covers: [Int], x: CGFloat, y: CGFloat, scale: CGFloat) -> some View {
        VStack(spacing: 10 * scale) {
            ForEach(covers, id: \.self) { index in
                OneTapeStudioCase(cover: .all[index], scale: scale)
            }
        }
        .offset(x: x * scale, y: y * scale)
    }

    private func fade(_ stops: [Gradient.Stop]) -> LinearGradient {
        LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }
}

private struct OneTapeStudioCase: View {
    let cover: OneTapeStudioCover
    let scale: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(cover.asset)
                .resizable()
                .scaledToFill()
                .frame(width: 96 * scale, height: 148 * scale)
                .blur(radius: 22 * scale)
                .overlay(.black.opacity(0.62))

            VStack(alignment: .leading, spacing: 0) {
                Image(cover.asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 85 * scale, height: 85 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 1.4 * scale))

                Text(cover.title.uppercased())
                    .font(.system(size: 6.1 * scale, weight: .bold))
                    .tracking(0.7 * scale)
                    .foregroundStyle(.white.opacity(0.79))
                    .padding(.top, 6.5 * scale)
                Text(cover.artist)
                    .font(.system(size: 5.5 * scale))
                    .foregroundStyle(.white.opacity(0.43))
                    .padding(.top, 3 * scale)
            }
            .lineLimit(1)
            .padding(5.5 * scale)

            RoundedRectangle(cornerRadius: 3.3 * scale)
                .strokeBorder(.white.opacity(0.25), lineWidth: 0.9 * scale)
            RoundedRectangle(cornerRadius: 2.2 * scale)
                .inset(by: 2.5 * scale)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1.5 * scale)
            RoundedRectangle(cornerRadius: scale)
                .fill(.white.opacity(0.1))
                .frame(width: 2 * scale, height: 11 * scale)
                .offset(x: 2.4 * scale, y: 5 * scale)
        }
        .frame(width: 96 * scale, height: 148 * scale)
        .clipShape(RoundedRectangle(cornerRadius: 3.3 * scale))
        .shadow(color: .black.opacity(0.7), radius: 2 * scale, y: 2 * scale)
    }
}

private struct OneTapeStudioCover {
    let index: Int
    let title: String
    let artist: String

    var asset: String { String(format: "OneTapeStudioCover%02d", index) }

    static let all: [Self] = [
        .init(index: 0, title: "Slow Drive", artist: "Night Call Tapes"),
        .init(index: 1, title: "Paper Suns", artist: "Mira Sol"),
        .init(index: 2, title: "Blue Hour", artist: "Koen"),
        .init(index: 3, title: "Loops for Rooms", artist: "The Quiet Engines"),
        .init(index: 4, title: "Static Bloom", artist: "Ada Vance"),
        .init(index: 5, title: "Tidal", artist: "Harbour Lights"),
        .init(index: 6, title: "Soft Machines", artist: "Juno Park"),
        .init(index: 7, title: "Night Swim", artist: "Oslo Motel"),
        .init(index: 8, title: "Grass & Wire", artist: "Field Notes"),
        .init(index: 9, title: "After Hours", artist: "Lumen Club"),
        .init(index: 10, title: "Side B", artist: "Tape Hiss"),
        .init(index: 11, title: "Velvet Radio", artist: "Marlowe")
    ]
}
