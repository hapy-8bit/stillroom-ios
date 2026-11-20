import SwiftUI

/// Cover/spine planes share the recovered zero-height row. Each Button is projected together
/// with its own surface; no transparent full-viewport hit overlay is placed above other albums.
struct OpeningSleeveRenderer: View, Animatable {
    let track: Track
    let artwork: UIImage?
    let geometry: OpeningStackGeometry
    let pose: OpeningStackPose
    var progress: Double = 0
    var interactive = true
    var accessibilityID: String?
    let onSelect: () -> Void

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let surfaces = pose.surfaces(progress: progress, coverSide: geometry.coverSide,
            spineThickness: geometry.spineThickness, portrait: geometry.axis == .vertical)
        ZStack {
            Button(action: onSelect) {
                ArtworkView(track: track, image: artwork)
                    // Image-local horizontal mirror precedes its frame and +90° Z baseline.
                    .scaleEffect(x: surfaces.mirrorScaleX, y: 1, anchor: .center)
                    .animation(nil, value: surfaces.mirrorScaleX)
                    .frame(width: geometry.coverSide, height: geometry.coverSide)
                    .rotationEffect(.degrees(90))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .rotation3DEffect(.degrees(surfaces.coverDegrees), axis: (x: -1, y: 0, z: 0),
                              anchor: .top, anchorZ: 0, perspective: 1)
            .offset(y: surfaces.coverOffsetY)
            .accessibilityHidden(true)

            Button(action: onSelect) { spine }
                .buttonStyle(.plain)
                .rotation3DEffect(.degrees(surfaces.spineDegrees), axis: (x: -1, y: 0, z: 0),
                                  anchor: UnitPoint(x: 0.5, y: surfaces.spineAnchorY), anchorZ: 0, perspective: 1)
                .accessibilityLabel(track.album + "，" + track.artist)
                .accessibilityHint("轻点，展开这张封套")
                .accessibilityIdentifier(accessibilityID ?? "recordOpening.selectedSleeve")
        }
        .frame(width: geometry.coverSide, height: 0)
        .offset(y: surfaces.innerOffsetY)
        // The recovered top-aligned C-height frame centers the open cover before inner Z.
        // Adding a guessed horizontal correction here would move the selected object twice.
        .frame(height: surfaces.innerHeight, alignment: .top)
        .rotationEffect(.degrees(surfaces.innerZDegrees), anchor: .center)
        .rotationEffect(.degrees(surfaces.wrapperZDegrees), anchor: .center)
        .allowsHitTesting(interactive)
        .accessibilityHidden(!interactive)
    }

    private var spine: some View {
        ZStack {
            // Palette binding remains an adapter. Sample the supplied real cover for edge
            // material; do not invent another cover or claim this coloration was recovered.
            ArtworkView(track: track, image: artwork)
                .frame(width: geometry.spineThickness, height: geometry.coverSide)
                .rotationEffect(.degrees(90))
                .frame(width: geometry.coverSide, height: geometry.spineThickness)
                .clipped()
            Color.black.opacity(0.48)
            Text(track.album + "  " + track.artist)
                .font(.system(size: geometry.spineFontSize, weight: .medium))
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(.white).padding(.horizontal, 6)
        }
        .frame(width: geometry.coverSide, height: geometry.spineThickness)
        .overlay(Rectangle().strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
        .contentShape(OpeningSpineTouchShape())
    }
}

/// Enlarge the physical edge's target in its local coordinates before applying the same hinge.
private struct OpeningSpineTouchShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: 0, dy: -max(0, (44 - rect.height) / 2)))
    }
}
