import SwiftUI

/// Physical horizontal Norelco polystyrene cassette jewel case (`329 : 211.7`).
/// Preserves the album artwork's full 1:1 square composition on the left while
/// pairing it with a color-matched J-card fold panel and clear acrylic optics.
struct OneTapeCaseArtwork: View {
    let collection: MusicCollection
    let artwork: UIImage?
    var showsFront = true
    var layout: OneTapeLibraryLayout = .shelf
    var compact = false
    var isCurrent = false
    var isPlaying = false
    /// Shifts the subtle diagonal acrylic glass reflection as a crate case tilts.
    var sheenShift: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 329.0
            let radius = max(2.2, 4.5 * scale)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(white: 0.042))
                if showsFront {
                    landscapeFront(scale: scale)
                } else {
                    OneTapeCaseBack().padding(9 * scale)
                }
                plasticShellOverlay(scale: scale, radius: radius)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .aspectRatio(OneTapeCaseGeometry.landscapeAspectRatio, contentMode: .fit)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var palette: OneTapeCasePalette { OneTapeCasePalette(artwork: artwork) }

    private var tapeFormatBadge: String {
        let minutes = collection.duration / 60.0
        if minutes <= 0 { return "C60" }
        if minutes <= 46 { return "C46" }
        if minutes <= 62 { return "C60" }
        if minutes <= 92 { return "C90" }
        return "C120"
    }

    private func landscapeFront(scale: CGFloat) -> some View {
        let innerHeight = 195.7 * scale
        let coverSide = innerHeight
        let jCardWidth = 109.3 * scale

        return HStack(spacing: 0) {
            ZStack {
                if let artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                } else {
                    palette.paper.opacity(0.92)
                    OneTapeCassetteIcon()
                        .foregroundStyle(palette.ink.opacity(0.32))
                        .frame(width: 78 * scale, height: 62 * scale)
                }
            }
            .frame(width: coverSide, height: innerHeight)
            .clipped()

            jCardPanel(scale: scale, width: jCardWidth, height: innerHeight)
        }
        .clipShape(RoundedRectangle(cornerRadius: max(1.0, 2.0 * scale), style: .continuous))
        .overlay(alignment: .leading) {
            // Physical J-card vertical fold score between square art and paper spine flap.
            HStack(spacing: 0) {
                Color.clear.frame(width: coverSide - 0.5 * scale)
                Rectangle()
                    .fill(.black.opacity(0.24))
                    .frame(width: max(0.5, 0.9 * scale))
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(width: max(0.4, 0.7 * scale))
            }
            .frame(height: innerHeight)
        }
        .offset(x: 12 * scale, y: 8 * scale)
    }

    @ViewBuilder
    private func jCardPanel(scale: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [palette.paper, palette.paperShadow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if compact {
                // Miniature 3-column grid J-card: refined index stripes + cassette grade mark
                // without illegible sub-5pt text.
                VStack(alignment: .leading, spacing: 5 * scale) {
                    HStack {
                        Capsule()
                            .fill(isCurrent ? Color(red: 0.87, green: 0.55, blue: 0.25) : palette.accentStrip)
                            .frame(width: 24 * scale, height: max(2.0, 5.5 * scale))
                        Spacer(minLength: 0)
                        if isCurrent {
                            Circle()
                                .fill(Color(red: 0.87, green: 0.55, blue: 0.25))
                                .frame(width: max(4.2, 10 * scale), height: max(4.2, 10 * scale))
                        }
                    }

                    VStack(alignment: .leading, spacing: 4.5 * scale) {
                        Capsule().fill(palette.ink.opacity(0.46)).frame(width: width * 0.68, height: max(1.4, 3.8 * scale))
                        Capsule().fill(palette.ink.opacity(0.28)).frame(width: width * 0.50, height: max(1.2, 3.0 * scale))
                        Capsule().fill(palette.ink.opacity(0.18)).frame(width: width * 0.60, height: max(1.0, 2.5 * scale))
                    }
                    .padding(.top, 6 * scale)

                    Spacer(minLength: 0)

                    Rectangle()
                        .fill(palette.ink.opacity(0.16))
                        .frame(height: max(0.5, 1.0 * scale))

                    Text(tapeFormatBadge)
                        .font(.custom("GeistMono-Regular", size: max(6.5, 13.5 * scale)))
                        .foregroundStyle(palette.ink.opacity(0.68))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12 * scale)
                .padding(.vertical, 14 * scale)
            } else {
                VStack(alignment: .leading, spacing: 6 * scale) {
                    HStack(alignment: .center, spacing: 5 * scale) {
                        Capsule()
                            .fill(isCurrent ? Color(red: 0.87, green: 0.55, blue: 0.25) : palette.accentStrip)
                            .frame(width: 18 * scale, height: 3.2 * scale)
                        Spacer(minLength: 0)
                        if isCurrent {
                            HStack(spacing: 3 * scale) {
                                Circle()
                                    .fill(Color(red: 0.87, green: 0.55, blue: 0.25))
                                    .frame(width: 5.5 * scale, height: 5.5 * scale)
                                Text(isPlaying ? "PLAY" : "DECK")
                                    .font(.custom("GeistMono-Regular", size: 6.2 * scale))
                                    .foregroundStyle(Color(red: 0.87, green: 0.55, blue: 0.25))
                            }
                        }
                    }

                    Text(collection.title)
                        .font(.system(size: 10.8 * scale, weight: .bold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2 * scale)

                    Text(collection.subtitle)
                        .font(.system(size: 7.2 * scale, weight: .medium))
                        .foregroundStyle(palette.ink.opacity(0.64))
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Rectangle()
                        .fill(palette.ink.opacity(0.16))
                        .frame(height: max(0.5, 0.7 * scale))

                    HStack(alignment: .firstTextBaseline) {
                        Text("A 面 · \(tapeFormatBadge)")
                            .font(.custom("GeistMono-Regular", size: 6.2 * scale))
                        Spacer(minLength: 2 * scale)
                        if let year = collection.year, (1920...2099).contains(year) {
                            Text("\(year)")
                                .font(.custom("GeistMono-Regular", size: 6.0 * scale))
                        }
                    }
                    .foregroundStyle(palette.ink.opacity(0.54))
                    .lineLimit(1)
                }
                .padding(.horizontal, 10.5 * scale)
                .padding(.vertical, 12 * scale)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func plasticShellOverlay(scale: CGFloat, radius: CGFloat) -> some View {
        let shift = min(0.28, max(-0.28, sheenShift))
        return ZStack {
            // Subtle 45-degree clear polystyrene surface specular sheen.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: max(0.0, 0.14 + shift)),
                    .init(color: .white.opacity(0.085), location: max(0.05, 0.30 + shift)),
                    .init(color: .white.opacity(0.025), location: max(0.10, 0.42 + shift)),
                    .init(color: .clear, location: min(1.0, 0.56 + shift)),
                    .init(color: .white.opacity(0.045), location: min(1.0, 0.86 + shift)),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Outer sharp acrylic wall refraction + recessed inner styrene lip.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.36), .white.opacity(0.14), .white.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.7, 1.15 * scale)
                )

            RoundedRectangle(cornerRadius: max(1.5, radius - 1.5 * scale), style: .continuous)
                .inset(by: max(1.4, 3.4 * scale))
                .strokeBorder(.white.opacity(0.10), lineWidth: max(0.5, 1.2 * scale))

            // Top specular bevel edge + right-edge subtle recessed shadow wall.
            Rectangle()
                .fill(.white.opacity(0.30))
                .frame(height: max(0.45, 0.8 * scale))
                .padding(.horizontal, 10 * scale)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, max(1.0, 2.2 * scale))

            // Authentic left-edge molded clear hinge lugs (top & bottom).
            VStack {
                hingeLug(scale: scale)
                Spacer()
                hingeLug(scale: scale)
            }
            .padding(.vertical, 24 * scale)
            .padding(.leading, max(1.2, 2.2 * scale))
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right-edge dark inner tray lip + subtle thumb notch mark.
            Rectangle()
                .fill(.black.opacity(0.44))
                .frame(width: max(1.0, 2.2 * scale))
                .padding(.vertical, 7 * scale)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, max(1.2, 3.0 * scale))

            RoundedRectangle(cornerRadius: max(0.8, 1.5 * scale))
                .fill(.white.opacity(0.16))
                .frame(width: max(1.0, 1.8 * scale), height: 26 * scale)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, max(1.2, 2.5 * scale))
        }
    }

    private func hingeLug(scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: max(0.6, 1.2 * scale))
            .fill(.white.opacity(0.22))
            .frame(width: max(1.2, 2.6 * scale), height: max(5.0, 18 * scale))
            .overlay {
                RoundedRectangle(cornerRadius: max(0.6, 1.2 * scale))
                    .stroke(.black.opacity(0.32), lineWidth: max(0.3, 0.5 * scale))
            }
    }
}

struct OneTapeCasePalette {
    let paper: Color
    let paperShadow: Color
    let accentStrip: Color
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
        let pr = red * 0.62 + 0.16
        let pg = green * 0.62 + 0.16
        let pb = blue * 0.62 + 0.16
        paper = Color(red: pr, green: pg, blue: pb)
        paperShadow = Color(red: max(0, pr - 0.055), green: max(0, pg - 0.055), blue: max(0, pb - 0.055))
        accentStrip = Color(
            red: min(1, red * 0.85 + 0.15),
            green: min(1, green * 0.85 + 0.12),
            blue: min(1, blue * 0.85 + 0.10)
        )
        ink = luma > 0.55 ? Color(white: 0.07) : Color(white: 0.94)
        atmosphere = Color(red: red * 0.28, green: green * 0.28, blue: blue * 0.28)
    }
}

private struct OneTapeCaseBack: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.20)))
            let inner = CGRect(
                x: size.width * 0.04, y: size.height * 0.08,
                width: size.width * 0.92, height: size.height * 0.72
            )
            context.fill(Path(inner), with: .color(Color(white: 0.035)))
            for fraction in [0.32, 0.68] {
                let center = CGPoint(x: size.width * fraction, y: size.height * 0.43)
                let radius = min(size.width, size.height) * 0.085
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
