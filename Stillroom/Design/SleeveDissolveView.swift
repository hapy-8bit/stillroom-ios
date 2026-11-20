import SwiftUI

/// Captures the unchanged artwork once per track/size, then shares one texture across all fragments.
/// The Canvas owns visual transforms only; no playback state or persistent file access lives here.
struct SleeveDissolveView: View {
    let track: Track
    let artwork: UIImage?
    let progress: Double
    let reducedMotion: Bool
    let artworkTop: CGFloat
    let viewportSize: CGSize
    let onPlayer: (SleeveFlightOrigin) -> Void
    let onShelf: () -> Void
    var artworkTransition: Namespace.ID? = nil
    var recordPresented = false
    var albumPresented = false
    @Environment(\.displayScale) private var displayScale
    @State private var snapshot: UIImage?
    @State private var globalViewport = CGRect.zero

    private var sourceSize: CGSize { CGSize(width: viewportSize.width, height: viewportSize.width * 0.83) }
    private var renderKey: String { "\(track.id)-\(artwork?.hash ?? 0)-\(sourceSize.width)-\(displayScale)" }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if progress < 0.001 || reducedMotion || snapshot == nil {
                SleeveArrangement(track: track, artwork: artwork, artworkTransition: artworkTransition,
                                  recordPresented: recordPresented, albumPresented: albumPresented)
                    .frame(width: sourceSize.width, height: sourceSize.height).offset(y: artworkTop)
            } else if let snapshot {
                fragments(snapshot)
            }
            if progress < 0.035 {
                Button {
                    guard globalViewport.width > 0 else { return }
                    onPlayer(SleeveFlightOrigin(viewport: globalViewport, artworkTop: artworkTop))
                } label: { Color.clear.contentShape(Circle()) }
                    .buttonStyle(.plain)
                    .frame(width: sourceSize.width * 0.38, height: sourceSize.width * 0.66)
                    .offset(x: sourceSize.width * 0.61, y: artworkTop + sourceSize.width * 0.09)
                    .accessibilityLabel("黑胶唱片，落针聆听").accessibilityIdentifier("listen.record")
                Button(action: onShelf) { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .frame(width: sourceSize.width * 0.62, height: sourceSize.width * 0.62)
                    .rotationEffect(.degrees(-8))
                    .offset(x: sourceSize.width * 0.035, y: artworkTop + sourceSize.width * 0.065)
                    .accessibilityLabel("专辑封套，展开唱片廊").accessibilityIdentifier("listen.sleeve")
            }
        }
        // Keep the same viewport before/after rasterization; intrinsic artwork height would
        // otherwise recenter the hit regions and make the first scroll frame jump.
        .frame(width: viewportSize.width, height: viewportSize.height, alignment: .topLeading)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { globalViewport = $0 }
        .task(id: renderKey) { renderSnapshot() }
    }

    private func fragments(_ image: UIImage) -> some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, _ in
            let source = context.resolve(Image(uiImage: image))
            for fragment in PaperFragmentLayout.fragments {
                let pose = PaperFragmentLayout.pose(for: fragment, progress: progress)
                guard pose.opacity > 0.001 else { continue }
                let rect = CGRect(x: fragment.rect.minX * sourceSize.width, y: fragment.rect.minY * sourceSize.height,
                                  width: fragment.rect.width * sourceSize.width, height: fragment.rect.height * sourceSize.height)
                var piece = context
                piece.opacity = pose.opacity
                piece.translateBy(x: rect.midX + pose.x * viewportSize.width,
                                  y: artworkTop + rect.midY + pose.y * viewportSize.height * 0.8)
                piece.rotate(by: .radians(pose.rotation))
                // Affine perspective approximates a folding paper face without duplicating the source image.
                piece.concatenate(CGAffineTransform(a: pose.fold, b: pose.shear, c: 0, d: 1, tx: 0, ty: 0))
                piece.clip(to: Path(CGRect(x: -rect.width / 2, y: -rect.height / 2,
                                          width: rect.width + 0.25, height: rect.height + 0.25)))
                let boundary = PaperFragmentLayout.burnBoundary(for: fragment, progress: progress)
                let paths = erodedPaths(boundary, rect: rect)
                piece.clip(to: paths.mask)
                piece.drawLayer { layer in
                    layer.draw(source, in: CGRect(x: -rect.midX, y: -rect.midY,
                                                  width: sourceSize.width, height: sourceSize.height))
                    // Tint/stroke only existing artwork alpha, so transparent corners never become square papers.
                    layer.blendMode = .sourceAtop
                    if pose.backside {
                        layer.fill(Path(CGRect(x: -rect.width / 2, y: -rect.height / 2,
                                               width: rect.width, height: rect.height)),
                                   with: .linearGradient(Gradient(colors: [RoomStyle.paper, Color(hex: 0x9EAA91)]),
                                                         startPoint: CGPoint(x: -rect.width / 2, y: 0),
                                                         endPoint: CGPoint(x: rect.width / 2, y: rect.height / 2)))
                    }
                    if boundary.contains(where: { $0 > 0.001 }) {
                        layer.stroke(paths.edge, with: .color(Color(hex: 0x32271A)), lineWidth: 3)
                        layer.stroke(paths.edge, with: .color(Color(hex: 0xA26432).opacity(0.85)), lineWidth: 0.8)
                    }
                }
            }
        }.frame(width: viewportSize.width, height: viewportSize.height).accessibilityHidden(true)
    }

    private func erodedPaths(_ heights: [Double], rect: CGRect) -> (mask: Path, edge: Path) {
        let points = heights.enumerated().map { index, height in
            CGPoint(x: -rect.width / 2 + CGFloat(index) / CGFloat(heights.count - 1) * rect.width,
                    y: -rect.height / 2 + height * rect.height)
        }
        var edge = Path()
        edge.addLines(points)
        var mask = edge
        mask.addLine(to: CGPoint(x: rect.width / 2, y: rect.height / 2))
        mask.addLine(to: CGPoint(x: -rect.width / 2, y: rect.height / 2))
        mask.closeSubpath()
        return (mask, edge)
    }

    @MainActor private func renderSnapshot() {
        let renderer = ImageRenderer(content: SleeveArrangement(track: track, artwork: artwork)
            .frame(width: sourceSize.width, height: sourceSize.height))
        renderer.scale = min(3, max(1, displayScale))
        renderer.proposedSize = ProposedViewSize(sourceSize)
        snapshot = renderer.uiImage
    }
}

private struct SleeveArrangement: View {
    let track: Track
    let artwork: UIImage?
    var artworkTransition: Namespace.ID? = nil
    var recordPresented = false
    var albumPresented = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let layout = SleeveArtworkLayout(width: width)
            ZStack(alignment: .topLeading) {
                if !recordPresented {
                    VinylRecord(track: track, artwork: artwork).frame(width: layout.record.width, height: layout.record.height)
                        .position(x: layout.record.midX, y: layout.record.midY)
                }
                if !albumPresented && !recordPresented {
                    ArtworkView(track: track, image: artwork, printed: true).frame(width: layout.sleeve.width, height: layout.sleeve.height)
                        .overlay(Rectangle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                        .shadow(color: .black.opacity(0.45), radius: 14, x: 5, y: 16)
                        .listeningHero(ListeningArtworkTransition.cover(track), in: artworkTransition)
                        .rotationEffect(.degrees(-8))
                        .position(x: layout.sleeve.midX, y: layout.sleeve.midY)
                }
            }
        }.accessibilityHidden(true)
    }
}
