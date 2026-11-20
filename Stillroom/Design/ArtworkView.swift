import SwiftUI

/// Artwork is passed in by the state owner. This view never reads files or resolves picker URLs.
struct ArtworkView: View {
    let track: Track
    var image: UIImage?
    var printed = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                    PaintedCover(palette: track.palette)
                }
                // Reference albums keep their supplied cover intact; Stillroom's decorative
                // session typography belongs only to our own painted/original sleeve designs.
                if printed && !BundledAlbumCatalog.isReferenceID(track.id) {
                    LinearGradient(colors: [.black.opacity(0.18), .clear, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: geometry.size.width * 0.045) {
                        Text(track.isDemo ? "STILLROOM / SESSIONS" : "PRIVATE COLLECTION")
                            .font(RoomStyle.caption(max(6, geometry.size.width * 0.028))).tracking(1.5)
                        Text(track.album).font(RoomStyle.serif(geometry.size.width * 0.12))
                            .lineLimit(2).minimumScaleFactor(0.7)
                        Spacer()
                        Text(track.artist).font(.system(size: max(8, geometry.size.width * 0.038))).lineLimit(1)
                    }.padding(geometry.size.width * 0.09).foregroundStyle(Color(hex: 0xFFF6E1))
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.aspectRatio(1, contentMode: .fit)
    }
}

struct PaintedCover: View {
    let palette: CoverPalette

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let bounds = CGRect(origin: .zero, size: size)
            if palette == .window {
                context.fill(Path(bounds), with: .linearGradient(Gradient(colors: [Color(hex: 0xCDC2A2), Color(hex: 0x7D8066)]),
                                                               startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
                let light = CGRect(x: w * 0.28, y: h * 0.1, width: w * 0.5, height: h * 0.62)
                context.fill(Path(light), with: .color(Color(hex: 0xEDE1B8)))
                for x in [0.28, 0.52, 0.76] {
                    context.fill(Path(CGRect(x: w * x, y: h * 0.1, width: w * 0.018, height: h * 0.62)),
                                 with: .color(Color(hex: 0x737564)))
                }
                context.fill(Path(CGRect(x: w * 0.28, y: h * 0.4, width: w * 0.5, height: h * 0.018)), with: .color(Color(hex: 0x737564)))
                var shadow = Path()
                shadow.move(to: CGPoint(x: w * 0.28, y: h * 0.72))
                shadow.addLines([CGPoint(x: w * 0.78, y: h * 0.72), CGPoint(x: w, y: h), CGPoint(x: w * 0.44, y: h)])
                shadow.closeSubpath()
                context.fill(shadow, with: .color(Color(hex: 0xF8E2AF).opacity(0.3)))
            } else if palette == .night {
                context.fill(Path(bounds), with: .linearGradient(Gradient(colors: [Color(hex: 0x515D72), Color(hex: 0x182B36)]),
                                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
                context.fill(Path(ellipseIn: CGRect(x: w * 0.65, y: h * 0.18, width: w * 0.17, height: w * 0.17)),
                             with: .color(Color(hex: 0xE8DDC6)))
                for i in 0..<8 {
                    let y = h * (0.64 + Double(i) * 0.045)
                    let length = w * (0.3 - Double(i) * 0.025)
                    context.fill(Path(CGRect(x: w * 0.73 - length / 2, y: y, width: length, height: 1)),
                                 with: .color(Color(hex: 0xCCCBB7).opacity(0.35 - Double(i) * 0.03)))
                }
            } else {
                context.fill(Path(bounds), with: .linearGradient(Gradient(colors: [Color(hex: 0x73816A), Color(hex: 0x344E49)]),
                                                               startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
                for i in 0..<5 {
                    let inset = w * (0.1 + Double(i) * 0.055)
                    context.stroke(Path(ellipseIn: bounds.insetBy(dx: inset, dy: inset)),
                                   with: .color(RoomStyle.paper.opacity(0.12)), lineWidth: 1)
                }
            }
        }
    }
}

