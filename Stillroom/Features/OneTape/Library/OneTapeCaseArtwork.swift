import SwiftUI

/// Data-only case presentation. The artwork is the real collection cover; the
/// clear plastic edge is drawn in logical points rather than a screen bitmap.
struct OneTapeCaseArtwork: View {
    let collection: MusicCollection
    let artwork: UIImage?
    var showsFront = true
    var layout: OneTapeLibraryLayout = .grid

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / (layout == .shelf ? 329 : 211.7)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2 * scale)
                    .fill(Color(white: 0.035))
                if showsFront {
                    if layout == .shelf { landscapeFront(scale: scale) }
                    else { portraitFront(scale: scale) }
                } else {
                    OneTapeCaseBack(layout: layout).padding(9 * scale)
                }
                plasticEdge(scale: scale)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 2 * scale))
        }
        .aspectRatio(OneTapeCaseGeometry.aspectRatio(for: layout), contentMode: .fit)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func landscapeFront(scale: CGFloat) -> some View {
        HStack(spacing: 0) {
            Group {
                if let artwork {
                    Image(uiImage: artwork).resizable().scaledToFill()
                } else {
                    ZStack {
                        palette.paper
                        OneTapeCassetteIcon()
                            .foregroundStyle(palette.ink.opacity(0.35))
                            .frame(width: 77 * scale, height: 61 * scale)
                    }
                }
            }
            .frame(width: 195 * scale, height: 195 * scale)
            .clipped()
            VStack(alignment: .leading, spacing: 6 * scale) {
                Text(collection.title)
                    .font(.system(size: 10.5 * scale, weight: .bold))
                    .lineLimit(3)
                Text(collection.subtitle)
                    .font(.system(size: 6.5 * scale))
                    .foregroundStyle(palette.ink.opacity(0.6))
                    .lineLimit(3)
                Spacer(minLength: 0)
                // Reference-case printing, not a duration or playback counter.
                Text("A 面 · C46")
                    .font(.system(size: 5.5 * scale))
                    .foregroundStyle(palette.ink.opacity(0.45))
            }
            .foregroundStyle(palette.ink)
            .padding(.horizontal, 9.5 * scale)
            .padding(.vertical, 12 * scale)
            .frame(width: 110 * scale, height: 195 * scale, alignment: .topLeading)
            .background(palette.paper)
        }
        .offset(x: 12 * scale, y: 4 * scale)
    }

    private func portraitFront(scale: CGFloat) -> some View {
        Group {
            if let artwork {
                // Fill the portrait paper without rotating or stretching the
                // user's image. The source artwork file remains untouched.
                Image(uiImage: artwork).resizable().scaledToFill()
            } else {
                ZStack {
                    palette.paper
                    VStack(alignment: .leading, spacing: 10 * scale) {
                        Text(collection.title)
                            .font(.system(size: 16 * scale, weight: .bold))
                            .lineLimit(3)
                        Spacer(minLength: 0)
                        OneTapeCassetteIcon()
                            .frame(width: 118 * scale, height: 86 * scale)
                            .rotationEffect(.degrees(90))
                            .frame(height: 118 * scale)
                            .frame(maxWidth: .infinity)
                            .opacity(0.5)
                        Spacer(minLength: 0)
                        Text(collection.subtitle)
                            .font(.system(size: 9 * scale))
                            .lineLimit(3)
                    }
                    .foregroundStyle(palette.ink)
                    .padding(14 * scale)
                }
            }
        }
        .frame(width: 195.7 * scale, height: 313 * scale)
        .clipped()
        .offset(x: 8 * scale, y: 8 * scale)
    }

    private var palette: OneTapeCasePalette { OneTapeCasePalette(artwork: artwork) }

    private func plasticEdge(scale: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2 * scale)
                .strokeBorder(.white.opacity(0.3), lineWidth: scale)
            RoundedRectangle(cornerRadius: 1.5 * scale)
                .inset(by: 3 * scale)
                .strokeBorder(.white.opacity(0.09), lineWidth: 1.4 * scale)
            Rectangle().fill(.white.opacity(0.28))
                .frame(height: 0.7 * scale).padding(.horizontal, 9 * scale)
                .frame(maxHeight: .infinity, alignment: .top).padding(.top, 2.5 * scale)
            Rectangle().fill(.white.opacity(0.16))
                .frame(width: 1.5 * scale).padding(.vertical, 8 * scale)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 2 * scale)
            Rectangle().fill(.black.opacity(0.5))
                .frame(width: 2 * scale).padding(.vertical, 6 * scale)
                .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 3 * scale)
        }
    }
}

struct OneTapeCasePalette {
    let paper: Color
    let ink: Color
    let atmosphere: Color

    init(artwork: UIImage?) {
        var red: CGFloat = 0.50, green: CGFloat = 0.53, blue: CGFloat = 0.52
        if let image = artwork?.cgImage {
            var pixel: [UInt8] = [0, 0, 0, 0]
            // CGContext keeps the data pointer after initialization. Drawing
            // and reading must stay inside the array's explicit buffer borrow.
            pixel.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
                guard let base = bytes.baseAddress,
                      let context = CGContext(data: base, width: 1, height: 1, bitsPerComponent: 8,
                                              bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
                context.interpolationQuality = .low
                context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                red = CGFloat(bytes[0]) / 255
                green = CGFloat(bytes[1]) / 255
                blue = CGFloat(bytes[2]) / 255
            }
        }
        let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        paper = Color(red: red * 0.65 + 0.14, green: green * 0.65 + 0.14, blue: blue * 0.65 + 0.14)
        ink = luma > 0.55 ? Color(white: 0.06) : Color(white: 0.94)
        atmosphere = Color(red: red * 0.25, green: green * 0.25, blue: blue * 0.25)
    }
}

private struct OneTapeCaseBack: View {
    let layout: OneTapeLibraryLayout

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.22)))
            let shelf = layout == .shelf
            let inner = shelf ? CGRect(x: size.width * 0.04, y: size.height * 0.08,
                width: size.width * 0.92, height: size.height * 0.72)
                : CGRect(x: size.width * 0.08, y: size.height * 0.04,
                width: size.width * 0.76, height: size.height * 0.92)
            context.fill(Path(inner), with: .color(Color(white: 0.035)))
            for fraction in [0.32, 0.68] {
                let center = shelf ? CGPoint(x: size.width * fraction, y: size.height * 0.43)
                    : CGPoint(x: size.width * 0.47, y: size.height * fraction)
                let radius = shelf ? min(size.width, size.height) * 0.085 : size.width * 0.16
                let ring = CGRect(x: center.x - radius, y: center.y - radius,
                                  width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: ring), with: .color(.white.opacity(0.13)), lineWidth: 2)
                context.fill(Path(ellipseIn: ring.insetBy(dx: radius / 2, dy: radius / 2)), with: .color(.black))
            }
            context.stroke(Path(CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)),
                           with: .color(.white.opacity(0.22)), lineWidth: 2)
        }
    }
}
