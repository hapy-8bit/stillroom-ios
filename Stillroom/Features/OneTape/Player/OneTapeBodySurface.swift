import SwiftUI

/// The shell restores the old photographed keys before applying its finish;
/// each visible transport key is drawn by OneTapeTransportKeyVisual instead.
/// Empty-library adaptive/cover modes use fixed fallback colors, never artwork
/// presented as if it came from a user's music library.
struct OneTapeBodySurface: View {
    let appearance: OneTapeAppearance
    var artworkColor: OneTapeTransportMaterial.RGB? = nil
    var artwork: UIImage? = nil
    var tilt: CGSize = OneTapeTiltMonitor.restingTilt
    var energy: Double = 0

    private var finish: OneTapeBodyFinish {
        OneTapeBodyFinish(appearance: appearance, artworkColor: artworkColor)
    }

    var body: some View {
        ZStack {
            base
            if let material = appearance.bodyMaterial {
                OneTapeMaterialShell(material: material, color: appearance.bodyColor, tilt: tilt, energy: energy)
                    .mask {
                        OneTapeBodyShellMask()
                            .fill(.white, style: FillStyle(eoFill: true))
                    }
            } else if !finish.isOriginalBlack {
                base
                    .saturation(0)
                    .contrast(0.88)
                    .brightness(finish.brightness)
                    .overlay {
                        finish.tint.opacity(0.72).blendMode(.color)
                    }
                    .overlay {
                        finish.tint.opacity(0.18).blendMode(.multiply)
                    }
                    .overlay {
                        if appearance.bodyStyle == .cover, appearance.bodyColor == .black,
                           let artwork {
                            Image(uiImage: artwork).resizable().scaledToFill()
                                .frame(width: 393, height: 852).clipped()
                                .opacity(0.32).blendMode(.softLight)
                        }
                    }
                    .mask {
                        OneTapeBodyShellMask()
                            .fill(.white, style: FillStyle(eoFill: true))
                    }
            }
        }
        .frame(width: 393, height: 852)
        // The photo's real outer radius is about 59 design points. The old
        // 82-point tint mask left black crescents at both ends. Remove its
        // photographed grey corner padding, then carry the finish to the edge.
        .clipShape(RoundedRectangle(cornerRadius: finish.isOriginalBlack ? 0 : 59))
        .background(finish.backdrop)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var base: some View {
        Canvas { context, size in
            let source = context.resolve(Image("OneTapeBody"))
            let bounds = CGRect(origin: .zero, size: size)
            context.draw(source, in: bounds)

            // The original photograph contains all three round keys. Restore
            // only those old circles from the adjacent unoccupied shell strip.
            // Key visuals are separate so body, rim, glyph and lamp all follow
            // one finish without retaining a black photographed patch below.
            var oldCircles = Path()
            for y in OneTapeTransportGeometry.sourceCentersY {
                oldCircles.addEllipse(in: OneTapeTransportGeometry.sourceFrame(centerY: y)
                    .insetBy(dx: -2, dy: -2))
            }
            var shell = context
            shell.clip(to: oldCircles)
            let targetX = OneTapeTransportGeometry.centerX
                - OneTapeTransportGeometry.sourceDiameter / 2 - 2
            let targetWidth = OneTapeTransportGeometry.sourceDiameter + 4
            let horizontalScale = targetWidth / 7.5
            shell.translateBy(x: targetX - 83.5 * horizontalScale, y: 0)
            shell.scaleBy(x: horizontalScale, y: 1)
            shell.draw(source, in: bounds)

        }
        .frame(width: 393, height: 852)
    }

}

/// Shared only by drawing layers; changing a finish never touches media state.
struct OneTapeBodyFinish {
    let appearance: OneTapeAppearance
    var artworkColor: OneTapeTransportMaterial.RGB? = nil

    var isOriginalBlack: Bool {
        appearance.bodyMaterial == nil && appearance.bodyStyle == .black && appearance.bodyColor == .black
    }

    var backdrop: Color {
        guard !isOriginalBlack else { return Color(white: 0.66) }
        if let material = appearance.bodyMaterial {
            return material.palette(color: appearance.bodyColor).shell.materialColor
        }
        if appearance.bodyStyle == .graphite { return tint }
        let rgb = OneTapeTransportMaterial(appearance: appearance, artworkColor: artworkColor).face
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    var tint: Color {
        if let material = appearance.bodyMaterial {
            return material.palette(color: appearance.bodyColor).shell.materialColor
        }
        if appearance.bodyColor != .black {
            return appearance.bodyColor.swiftUIColor
        }
        switch appearance.bodyStyle {
        case .black: return .black
        case .graphite: return Color(red: 0.57, green: 0.59, blue: 0.58)
        case .adaptive, .cover:
            let rgb = OneTapeTransportMaterial(appearance: appearance, artworkColor: artworkColor).face
            return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        }
    }

    var brightness: Double {
        switch appearance.bodyColor {
        case .white, .dove: return 0.64
        case .navy, .green: return 0.27
        case .slate, .cognac, .garden: return 0.38
        case .black:
            switch appearance.bodyStyle {
            case .black: return 0
            case .graphite: return 0.39
            case .adaptive: return 0.31
            case .cover: return 0.63
            }
        }
    }
}

extension OneTapeAppearance.BodyColor {
    var swiftUIColor: Color {
        switch self {
        case .black: return Color(red: 0.09, green: 0.10, blue: 0.10)
        case .navy: return Color(red: 0.16, green: 0.24, blue: 0.31)
        case .green: return Color(red: 0.17, green: 0.35, blue: 0.29)
        case .slate: return Color(red: 0.40, green: 0.47, blue: 0.52)
        case .dove: return Color(red: 0.69, green: 0.72, blue: 0.71)
        case .cognac: return Color(red: 0.57, green: 0.34, blue: 0.23)
        case .white: return Color(red: 0.91, green: 0.91, blue: 0.87)
        case .garden: return Color(red: 0.48, green: 0.59, blue: 0.40)
        }
    }
}

private struct OneTapeBodyShellMask: Shape {
    func path(in rect: CGRect) -> Path {
        // The cassette module owns its complete fixed frame, including the lip
        // and dark backing. A body finish stops at that boundary regardless of
        // the selected tape's silhouette or the sliding glass position.
        var path = Path(rect)
        path.addRoundedRect(in: OneTapeCassettePocketMask.openingFrame,
                            cornerSize: CGSize(width: 19.12, height: 19.12))
        path.addRoundedRect(in: CGRect(x: 100.33, y: 651.12, width: 264.39, height: 165.63),
                            cornerSize: CGSize(width: 2.5, height: 2.5))
        return path
    }
}

/// Leaf observer so tilt and audio-energy updates only redraw dynamic body shells
/// (Holo Foil, Silver Foil, Disco Mirror, Circuit Glow) without rebuilding root chrome.
struct OneTapeLiveBodySurface: View {
    let appearance: OneTapeAppearance
    var artworkColor: OneTapeTransportMaterial.RGB? = nil
    var artwork: UIImage? = nil
    @ObservedObject var tiltMonitor: OneTapeTiltMonitor
    var visualization: AudioVisualizationSignal? = nil

    var body: some View {
        if let visualization, appearance.bodyMaterial == .disco || appearance.bodyMaterial == .circuitGlow {
            OneTapeAudioReactiveBodySurface(
                appearance: appearance,
                artworkColor: artworkColor,
                artwork: artwork,
                tilt: tiltMonitor.tilt,
                visualization: visualization
            )
        } else {
            OneTapeBodySurface(
                appearance: appearance,
                artworkColor: artworkColor,
                artwork: artwork,
                tilt: tiltMonitor.tilt
            )
        }
    }
}

private struct OneTapeAudioReactiveBodySurface: View {
    let appearance: OneTapeAppearance
    var artworkColor: OneTapeTransportMaterial.RGB? = nil
    var artwork: UIImage? = nil
    let tilt: CGSize
    @ObservedObject var visualization: AudioVisualizationSignal

    var body: some View {
        let energy = Double(max(visualization.frame.rms, visualization.frame.peak * 0.72))
        OneTapeBodySurface(
            appearance: appearance,
            artworkColor: artworkColor,
            artwork: artwork,
            tilt: tilt,
            energy: energy
        )
    }
}

