import SwiftUI

/// A key owns its whole visible circle, including the rim, glyph and lamp. That
/// prevents an orientation or playing overlay from putting a black asset back
/// over a light-colored button. All dimensions remain logical design points.
struct OneTapeTransportKeyVisual: View {
    let appearance: OneTapeAppearance
    let action: OneTapeTransportAction
    let illuminated: Bool
    let quarterTurns: Int
    var artworkColor: OneTapeTransportMaterial.RGB? = nil

    private var material: OneTapeTransportMaterial {
        OneTapeTransportMaterial(appearance: appearance, artworkColor: artworkColor)
    }
    private var diameter: CGFloat { OneTapeTransportGeometry.visualDiameter }
    private var symbol: String {
        switch action {
        case .previous: "backward.end.fill"
        case .play: "play.fill"
        case .next: "forward.end.fill"
        }
    }

    var body: some View {
        Group {
            if let surface = appearance.bodyMaterial {
                materialKey(surface)
            } else if material.usesOriginalArtwork || appearance.bodyStyle == .graphite {
                originalKey
            } else {
                finishedKey
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func materialKey(_ surface: OneTapeBodyMaterial) -> some View {
        ZStack {
            OneTapeMaterialKeySurface(material: surface, palette: surface.palette(color: appearance.bodyColor))
            if action == .play, illuminated {
                Circle().fill(RadialGradient(
                    colors: [Color(red: 1, green: 0.94, blue: 0.76).opacity(0.26), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 49))
                    .padding(6).blendMode(.screen)
            }
            glyph
        }
        .clipShape(Circle())
    }

    private var originalKey: some View {
        ZStack {
            photographedKey
                .rotationEffect(.degrees(Double(quarterTurns) * 90))
            if action == .play {
                OneTapePlayKeyVisual(illuminated: illuminated, quarterTurns: quarterTurns,
                                     graphite: appearance.bodyStyle == .graphite)
            }
        }
    }

    private var photographedKey: some View {
        Canvas { context, _ in
            let index = action == .previous ? 0 : action == .play ? 1 : 2
            let sourceFrame = OneTapeTransportGeometry.sourceFrame(
                centerY: OneTapeTransportGeometry.sourceCentersY[index])
            let scale = OneTapeTransportGeometry.visualScale
            context.clip(to: Path(ellipseIn: CGRect(x: 0, y: 0, width: diameter, height: diameter)))
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -sourceFrame.minX, y: -sourceFrame.minY)
            context.draw(context.resolve(Image("OneTapeBody")),
                         in: CGRect(x: 0, y: 0, width: 393, height: 852))
        }
    }

    private var finishedKey: some View {
        let face = material.face.color
        return ZStack {
            Circle().fill(Color.black.opacity(0.82))
            Circle()
                .fill(LinearGradient(colors: [face.lighter(0.26), face.darker(0.12),
                    face.darker(0.23), face.lighter(0.15)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(1)
            Circle()
                .fill(LinearGradient(colors: [face.lighter(0.10), face, face.darker(0.07)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(4)
                .overlay {
                    Circle().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.32), .clear, .black.opacity(0.22)],
                            startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                        .padding(4)
                }
            if action == .play, illuminated {
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.91, blue: 0.65).opacity(0.30),
                        .clear], center: .center, startRadius: 0, endRadius: diameter * 0.51))
                    .padding(4)
                    .blendMode(.screen)
            }
            glyph
        }
        .clipShape(Circle())
    }

    private var glyph: some View {
        Image(systemName: symbol)
            .font(.system(size: 25 * OneTapeTransportGeometry.visualScale, weight: .medium))
            .foregroundStyle(material.symbol.color)
            .rotationEffect(.degrees(Double(quarterTurns) * 90))
    }
}

private extension OneTapeTransportMaterial.RGB {
    var color: Color { Color(red: red, green: green, blue: blue) }
}

private extension Color {
    // A relative white/black mix retains the finish hue in bevel highlights.
    func lighter(_ fraction: Double) -> Color {
        let color = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Color(red: red + (1 - red) * fraction, green: green + (1 - green) * fraction,
                     blue: blue + (1 - blue) * fraction)
    }

    func darker(_ fraction: Double) -> Color {
        let color = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Color(red: red * (1 - fraction), green: green * (1 - fraction),
                     blue: blue * (1 - fraction))
    }
}
