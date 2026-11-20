import SwiftUI

/// One immutable print per record/side/art/material change. Audio ticks never rebuild the bitmap.
enum OrbitTurntableTexture {
    @MainActor static func render(track: Track, artwork: UIImage?, style: OrbitRecordStyle,
                                 session: CraftListeningSession?) -> UIImage? {
        let content = ZStack {
            OrbitDiscArtwork(track: track, artwork: artwork, style: style)
            if let session {
                CraftedCenterLabel(record: session.record, image: artwork, side: session.side)
                    .frame(width: 1_024 * 0.49, height: 1_024 * 0.49)
            }
        }.frame(width: 1_024, height: 1_024)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        return renderer.uiImage
    }

    static func key(track: Track, artwork: UIImage?, style: OrbitRecordStyle, session: CraftListeningSession?) -> String {
        let stickers = style.stickers.map { "\($0.id):\($0.kind.rawValue):\($0.x):\($0.y):\($0.size):\($0.rotation)" }.joined(separator: ";")
        let record = session.map { "\($0.record.id)|\($0.record.updatedAt)|\($0.side.rawValue)|\($0.record.title)|\($0.record.color.rawValue)|\($0.record.design.rawValue)|\($0.record.coverAsset ?? "")" } ?? ""
        return "\(track.id)|\(track.title)|\(track.artist)|\(track.album)|\(track.palette.rawValue)|\(artwork?.hash ?? 0)|\(style.material.rawValue)|\(style.primaryHex)|\(style.secondaryHex)|\(stickers)|\(record)"
    }
}

private struct CraftedCenterLabel: View {
    let record: CraftedRecord
    let image: UIImage?
    let side: CraftedSide

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                CraftStyle.color(record.color)
                if record.design == .photo, let image {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: width, height: width).clipped()
                    Color.black.opacity(0.30)
                } else if record.design == .split {
                    VStack(spacing: 0) {
                        CraftStyle.color(record.color).frame(height: width * 0.65)
                        CraftStyle.paper
                    }
                }
                if record.design == .split {
                    Text(record.title).font(.system(size: width * 0.095, weight: .semibold, design: .serif))
                        .lineLimit(2).minimumScaleFactor(0.55).multilineTextAlignment(.center)
                        .foregroundStyle(CraftStyle.paper).frame(width: width * 0.72)
                        .position(x: width * 0.5, y: width * 0.28)
                    Text(side.label).font(.system(size: width * 0.075, weight: .medium)).tracking(width * 0.01)
                        .foregroundStyle(CraftStyle.color(record.color)).position(x: width * 0.5, y: width * 0.80)
                } else {
                    VStack(spacing: width * 0.04) {
                        Text(record.title).font(.system(size: width * 0.095, weight: .semibold, design: .serif))
                            .lineLimit(2).minimumScaleFactor(0.55).multilineTextAlignment(.center)
                        Color.clear.frame(height: width * 0.12)
                        Text(side.label).font(.system(size: width * 0.075, weight: .medium)).tracking(width * 0.01)
                    }.foregroundStyle(.white).padding(width * 0.14)
                }
                Circle().fill(.black).frame(width: width * 0.09)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            }.clipShape(Circle()).overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: 1))
        }.accessibilityHidden(true)
    }
}
