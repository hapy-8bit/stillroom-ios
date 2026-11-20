import SwiftUI
import CoreText
import UIKit

/// Runtime typography, never a baked song title. A bitmap CoreText mask retains
/// fallback glyphs, including color emoji that have no vector outline.
struct OneTapeParticleTitle: View {
    let readout: OneTapePlaybackReadout
    let phase: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var layout = Layout.empty

    private var title: String {
        OneTapeNameSand.normalizedText(title: readout.title, artist: readout.artist,
                                      hasTrack: readout.hasTrack).title
    }

    var body: some View {
        let cached = layout
        let seconds = reduceMotion || !phase.isFinite ? 0 : max(0, phase)
        GeometryReader { geometry in
            let key = Self.layoutKey(title: title, size: geometry.size)
            // A track switch must never display the previous cached title while
            // onChange awaits its State commit. Build the new bounded mask now.
            let current = cached.key == key ? cached : Self.makeLayout(title: title, size: geometry.size)
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .color(Color(red: 0.022, green: 0.031, blue: 0.034)))
                var artwork = context
                artwork.clip(to: Path(OneTapeApprovedScreenLayout.artworkRect(style: .name, size: size)))
                if let image = current.image {
                    var silhouette = artwork
                    silhouette.opacity = 0.30
                    silhouette.draw(Image(decorative: image, scale: 3),
                                    in: CGRect(origin: .zero, size: size))
                }
                let cycle = seconds.truncatingRemainder(dividingBy: 6) / 6 * 2 * .pi
                let departure = pow(sin(cycle / 2), 2)
                let scale = OneTapeScreenLayoutGeometry(size: size).unit
                for (index, grain) in current.grains.enumerated() {
                    let seed = Double(index + 1)
                    let distance = grain.moving ? (2 + 2.5 * Self.noise(seed * 3.71)) * departure * scale : 0
                    let curl = 0.0
                    let x = grain.point.x + grain.normal.dx * distance - grain.normal.dy * curl
                    let y = grain.point.y + grain.normal.dy * distance + grain.normal.dx * curl
                    let radius = (0.24 + Self.noise(seed * 7.3) * 0.12) * scale
                    artwork.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                                        width: radius * 2, height: radius * 2)),
                                 with: .color(Color(red: 238 / 255.0, green: 234 / 255.0, blue: 223 / 255.0)
                                    .opacity(0.65 + Self.noise(seed * 2.9) * 0.30)))
                }
            }
            .onChange(of: key, initial: true) { _, _ in
                layout = current
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    struct Grain {
        let point: CGPoint
        let normal: CGVector
        var moving: Bool
    }
    struct Layout {
        let key: String
        let image: CGImage?
        let grains: [Grain]
        let lineCount: Int
        static let empty = Self(key: "", image: nil, grains: [], lineCount: 0)
    }

    nonisolated static func layoutKey(title: String, size: CGSize) -> String {
        title + "\u{0}\(size.width),\(size.height)"
    }

    nonisolated static func makeLayout(title: String, size: CGSize) -> Layout {
        guard size.width.isFinite, size.height.isFinite, size.width > 20, size.height > 20 else { return .empty }
        let width = Int(ceil(size.width * 3)), height = Int(ceil(size.height * 3))
        guard width <= 3000, height <= 3000,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return .empty }
        let visible = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let value = visible.isEmpty ? "未命名歌曲" : visible
        let scale = OneTapeScreenLayoutGeometry(size: size).unit
        let textLayout = OneTapeApprovedScreenLayout.nameTextLayout(title: value, size: size)
        let pointSize = textLayout.fontSize
        let systemFont = UIFont.systemFont(ofSize: pointSize, weight: .regular)
        // Pass the same system UIFont used by the shared text measurement.
        // Reopening its private .SFUI name through CTFontCreateWithName can
        // silently substitute Times, invalidating both wrapping and mask bounds.
        let attributes: [NSAttributedString.Key: Any] = [
            .font: systemFont,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                CGColor(red: 238 / 255.0, green: 234 / 255.0, blue: 223 / 255.0, alpha: 1)
        ]
        let lines = textLayout.lines.map {
            CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: attributes))
        }
        context.scaleBy(x: 3, y: 3)
        for (index, line) in lines.enumerated() {
            let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
            // The approved preview centers the group of baselines, rather than
            // glyph bounding boxes. Keep that distinction for mixed CJK/emoji.
            let baseline = textLayout.firstBaseline + Double(index) * textLayout.linePitch
            context.textPosition = CGPoint(x: size.width / 2 - lineWidth / 2,
                                           y: size.height - baseline)
            CTLineDraw(line, context)
        }
        guard let image = context.makeImage(), let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return .empty }
        func alpha(_ x: Int, _ y: Int) -> Double {
            let x = min(width - 1, max(0, x)), y = min(height - 1, max(0, y))
            return Double(data[(y * width + x) * 4 + 3]) / 255
        }
        var grains: [Grain] = [], edges: [Int] = []
        let pitch = max(3, Int((scale * 3).rounded()))
        for y in stride(from: 0, to: height, by: pitch) {
            for x in stride(from: 0, to: width, by: pitch) where alpha(x, y) > 0.45 {
                let dx = alpha(x - 2, y) - alpha(x + 2, y)
                let dy = alpha(x, y - 2) - alpha(x, y + 2)
                let norm = hypot(dx, dy)
                if norm > 0.2 { edges.append(grains.count) }
                grains.append(Grain(point: CGPoint(x: Double(x) / 3, y: Double(y) / 3),
                    normal: norm > 0.02 ? CGVector(dx: dx / norm, dy: dy / norm) : CGVector(dx: 0, dy: -1),
                    moving: false))
            }
        }
        let selection = edges.sorted { noise(Double($0) * 5.71) < noise(Double($1) * 5.71) }
        for index in selection.prefix(Int(Double(grains.count) * 0.2)) { grains[index].moving = true }
        return Layout(key: layoutKey(title: title, size: size), image: image, grains: grains, lineCount: lines.count)
    }

    nonisolated private static func noise(_ seed: Double) -> Double {
        let x = sin(seed * 12.9898 + 78.233) * 43758.5453123
        return x - floor(x)
    }
}
