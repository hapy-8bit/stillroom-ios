import SwiftUI

/// A composited record has no playback state. Its label uses song art; sleeves use album art upstream.
struct OrbitDiscArtwork: View {
    let track: Track
    var artwork: UIImage?
    var style = OrbitRecordStyle()
    var libraryDisc = false

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            ZStack {
                if libraryDisc || style.material == .artwork {
                    ArtworkView(track: track, image: artwork)
                    Circle().fill(.black.opacity(0.12))
                } else if style.material == .resinGreen {
                    Image("OrbitResinGreen").resizable().scaledToFit()
                } else if style.material == .split {
                    HStack(spacing: 0) { OrbitInk.color(style.primaryHex); OrbitInk.color(style.secondaryHex) }
                } else {
                    OrbitVinylSurface(track: track, artwork: artwork, material: style.material)
                }
                grooves(side: side)
                if !libraryDisc && style.material != .artwork {
                    ArtworkView(track: track, image: artwork).frame(width: side * 0.49, height: side * 0.49)
                        .clipShape(Circle()).overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 0.6))
                }
                if libraryDisc && !BundledAlbumCatalog.isReferenceID(track.id) {
                    Text("© STILLROOM").font(.system(size: side * 0.038, weight: .medium)).offset(y: -side * 0.31)
                    HStack {
                        Text("SIDE A").font(.system(size: side * 0.052, weight: .heavy))
                        Spacer()
                        Text("33⅓").font(.system(size: side * 0.072, weight: .heavy))
                    }.padding(.horizontal, side * 0.13)
                    Image(systemName: "star.fill").font(.system(size: side * 0.31, weight: .black)).rotationEffect(.degrees(15))
                    Text(track.artist.uppercased()).font(.system(size: side * 0.025, weight: .medium)).tracking(1)
                        .lineLimit(1).frame(width: side * 0.65).offset(y: side * 0.42)
                }
                if !libraryDisc {
                    ForEach(style.stickers.prefix(12)) { sticker in
                        OrbitStickerArtwork(kind: sticker.kind).frame(width: side * sticker.size, height: side * sticker.size)
                            .rotationEffect(.degrees(sticker.rotation)).offset(x: side * (sticker.x - 0.5), y: side * (sticker.y - 0.5))
                    }
                }
                Circle().fill(Color(white: 0.045)).frame(width: side * (libraryDisc ? 0.075 : 0.014))
                    .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.7))
            }.foregroundStyle(.white.opacity(0.88)).frame(width: side, height: side).clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(libraryDisc ? 0.55 : 0.18), lineWidth: libraryDisc ? 1 : 0.7))
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }

    private func grooves(side: CGFloat) -> some View {
        Canvas { context, size in
            let count = libraryDisc ? 42 : 122
            for index in 0..<count {
                let ratio = libraryDisc ? 0.405 + Double(index) * 0.0138 : 0.502 + Double(index) * 0.004
                let diameter = side * ratio
                let box = CGRect(x: (size.width - diameter) / 2, y: (size.height - diameter) / 2,
                                 width: diameter, height: diameter)
                let opacity = libraryDisc ? 0.13 : index.isMultiple(of: 9) ? 0.10 : 0.045
                context.stroke(Path(ellipseIn: box), with: .color(.white.opacity(opacity)),
                               lineWidth: libraryDisc ? 0.35 : max(0.18, side * 0.0004))
            }
        }.allowsHitTesting(false)
    }

}

/// Small original vector stickers; no reference-app pixels, logos or bundled commercial artwork.
struct OrbitStickerArtwork: View {
    let kind: OrbitStickerKind
    @ViewBuilder var body: some View {
        if kind == .cassette {
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.91, green: 0.76, blue: 0.55))
                RoundedRectangle(cornerRadius: 2).strokeBorder(.black.opacity(0.55), lineWidth: 1).padding(4)
                HStack(spacing: 5) { Circle().fill(.black); Circle().fill(.black) }.padding(9)
            }.aspectRatio(1.4, contentMode: .fit)
        } else if kind == .vinyl {
            ZStack {
                Circle().fill(Color(white: 0.08)).overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                ForEach([0.55, 0.7, 0.83], id: \.self) { ratio in Circle().strokeBorder(.white.opacity(0.25)).padding(CGFloat(1 - ratio) * 22) }
                Circle().fill(Color(red: 0.7, green: 0.22, blue: 0.13)).scaleEffect(0.36)
                Circle().fill(.black).scaleEffect(0.08)
            }
        } else {
            Image(systemName: kind == .star ? "star.fill" : "heart.fill").resizable().scaledToFit()
                .foregroundStyle(kind == .heart ?
                    AnyShapeStyle(Color(red: 0.87, green: 0.12, blue: 0.19)) :
                    AnyShapeStyle(LinearGradient(colors: [.white, .gray, .white, Color(white: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
        }
    }
}

/// Rotation is a visual clock only. Pausing captures its angle and hidden/inactive views stop updates.
struct OrbitRotating<Content: View>: View {
    var running: Bool
    let content: Content
    @State private var accumulated: Double = 0
    @State private var started: Date?

    init(running: Bool, @ViewBuilder content: () -> Content) { self.running = running; self.content = content() }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !running)) { context in
            content.rotationEffect(.degrees(angle(at: context.date)))
        }.onAppear { sync() }.onChange(of: running) { _, _ in sync() }
            .onDisappear { if let started { accumulated += Date().timeIntervalSince(started) * 12 }; started = nil }
    }

    private func angle(at date: Date) -> Double { accumulated + (started.map { max(0, date.timeIntervalSince($0)) * 12 } ?? 0) }
    private func sync() {
        if running { if started == nil { started = Date() } }
        else if started != nil { accumulated = angle(at: Date()).truncatingRemainder(dividingBy: 360); started = nil }
    }
}

struct OrbitTonearm: View {
    var fraction: Double?
    var raised: Bool
    var purple = false
    var reducedMotion = false

    private var angle: Double { raised ? -14 : 3 + (fraction ?? 0) * 15 }

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 120
            ZStack(alignment: .topLeading) {
                Circle().fill(.black.opacity(0.16)).overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 0.6))
                    .frame(width: 64 * scale, height: 64 * scale).position(x: 81 * scale, y: 30 * scale)
                arm(scale: scale).rotationEffect(.degrees(angle), anchor: UnitPoint(x: 81 / 120, y: 30 / 330))
                    .animation(reducedMotion ? nil : .easeInOut(duration: raised ? 0.2 : 0.38), value: angle)
                Circle().fill(Color(white: 0.07)).overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    .frame(width: 18 * scale, height: 18 * scale).position(x: 81 * scale, y: 30 * scale)
            }.frame(width: 120 * scale, height: 330 * scale)
        }.aspectRatio(120 / 330, contentMode: .fit).allowsHitTesting(false).accessibilityHidden(true)
    }

    private func arm(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: 81 * scale, y: 25 * scale))
                path.addLine(to: CGPoint(x: 81 * scale, y: 228 * scale))
                path.addQuadCurve(to: CGPoint(x: 59 * scale, y: 266 * scale), control: CGPoint(x: 81 * scale, y: 252 * scale))
                path.addLine(to: CGPoint(x: 39 * scale, y: 287 * scale))
            }.stroke(LinearGradient(colors: [.black, Color(white: 0.94), Color(white: 0.34)], startPoint: .leading, endPoint: .trailing),
                     style: StrokeStyle(lineWidth: 8 * scale, lineCap: .round))
                .shadow(color: .black.opacity(0.5), radius: 3, x: 3, y: 4)
            RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.10)).overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.12)))
                .frame(width: 28 * scale, height: 48 * scale).position(x: 81 * scale, y: 30 * scale)
            RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.055))
                .frame(width: 22 * scale, height: 48 * scale).rotationEffect(.degrees(34)).position(x: 32 * scale, y: 290 * scale)
            Capsule().fill(purple ? OrbitInk.purple : Color(white: 0.3)).frame(width: 4 * scale, height: 28 * scale)
                .rotationEffect(.degrees(34)).position(x: 29 * scale, y: 294 * scale)
                .shadow(color: purple ? OrbitInk.purple : .clear, radius: 4)
        }.frame(width: 120 * scale, height: 330 * scale)
    }
}
