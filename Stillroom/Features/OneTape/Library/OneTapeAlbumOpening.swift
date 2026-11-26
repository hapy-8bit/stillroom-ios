import SwiftUI

enum OneTapeAlbumOpeningStage: Equatable, Sendable {
    case folded, standing, docked, revealing, revealed
}

enum OneTapeCaseGeometry {
    static let portraitAspectRatio: CGFloat = 211.7 / 329
    static let landscapeAspectRatio: CGFloat = 329 / 211.7

    /// Asymmetric focal fan-out curve for the vertical crate:
    /// The centered focal cassette tilts open to -18° (exposing ~95% of its
    /// full horizontal artwork plus top spine), while cases above and below tuck
    /// neatly back (-74° upper / -68° lower) without flipping onto the blank back.
    static func shelfAngle(pitch: CGFloat) -> Double {
        let clamped = Double(min(1, max(-1, pitch)))
        let focus = crateFocus(for: pitch)
        let resting = clamped < 0 ? -74.0 : -68.0
        return resting + (-18.0 - resting) * focus
    }

    /// Smooth bell weight in [0, 1] peaking at 1.0 when a crate case is at focal center.
    static func crateFocus(for pitch: CGFloat) -> Double {
        let clamped = Double(min(1, max(-1, pitch)))
        return exp(-clamped * clamped * 4.2)
    }

    /// Both Crate (`.shelf`) and 3-column Horizontal Grid (`.grid`) share one
    /// unified horizontal Norelco cassette aspect ratio (329 : 211.7).
    static func aspectRatio(for layout: OneTapeLibraryLayout) -> CGFloat {
        landscapeAspectRatio
    }

    static func dockedFrame(in viewport: CGSize, layout: OneTapeLibraryLayout) -> CGRect {
        let contentWidth = min(max(0, viewport.width - 64), 470)
        return CGRect(
            x: (viewport.width - contentWidth) / 2,
            y: 53 * contentWidth / 329,
            width: contentWidth,
            height: contentWidth / landscapeAspectRatio
        )
    }
}

/// Frames use the library's safe-area coordinate space, in logical points.
/// The shelf frame starts at the spine hinge; the grid frame is the horizontal cover rect.
struct OneTapeAlbumOpeningPose {
    let frame: CGRect
    let angle: Double

    init(stage: OneTapeAlbumOpeningStage, viewport: CGSize, origin: CGRect, pitch: CGFloat,
         layout: OneTapeLibraryLayout = .shelf) {
        let docked = OneTapeCaseGeometry.dockedFrame(in: viewport, layout: layout)
        switch stage {
        case .folded:
            if layout == .grid, !origin.isEmpty {
                frame = origin
                angle = 0
            } else {
                let width = origin.isEmpty ? docked.width : min(max(0, origin.width), max(0, viewport.width))
                let height = width / OneTapeCaseGeometry.aspectRatio(for: layout)
                let center = origin.isEmpty ? CGPoint(x: viewport.width / 2, y: viewport.height * 0.54)
                    : CGPoint(x: origin.midX, y: origin.midY)
                frame = CGRect(x: center.x - width / 2,
                               y: layout == .shelf ? center.y - height * 0.25 : center.y - height / 2,
                               width: width, height: height)
                angle = layout == .shelf ? OneTapeCaseGeometry.shelfAngle(pitch: pitch) : 0
            }
        case .standing:
            let width = docked.width * 1.04
            let height = docked.height * 1.04
            frame = CGRect(x: (viewport.width - width) / 2,
                           y: viewport.height * 0.52 - height / 2, width: width, height: height)
            angle = 0
        case .docked, .revealing, .revealed:
            frame = docked
            angle = 0
        }
    }
}

/// One rigid box in logical points. All faces share a camera and the front
/// edge of the spine as their hinge, including during the opening animation.
struct OneTapeCaseProjection {
    let width: CGFloat
    let angle: Double
    var height: CGFloat { width * OneTapeCaseGeometry.portraitAspectRatio }
    var thickness: CGFloat { width * 51.1 / 329 }
    private var radians: Double { angle * .pi / 180 }
    var showsFront: Bool { cos(radians) >= 0 }

    private func point(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
        guard width > 0 else { return .zero }
        let sine = CGFloat(sin(radians)), cosine = CGFloat(cos(radians))
        let rotatedY = y * cosine - z * sine
        let rotatedZ = y * sine + z * cosine
        let distance = width * 900 / 329
        let perspective = distance / max(distance * 0.1, distance - rotatedZ)
        // Keep the spine centered in its row at -90°, and the front cover's
        // top edge at y0 when upright. Both source and floating views use this.
        return CGPoint(x: width / 2 + (x - width / 2) * perspective,
                       y: rotatedY * perspective - thickness * sine / 2)
    }

    var front: [CGPoint] {
        [point(0, 0, 0), point(width, 0, 0), point(width, height, 0), point(0, height, 0)]
    }

    var back: [CGPoint] {
        [point(0, height, -thickness), point(width, height, -thickness),
         point(width, 0, -thickness), point(0, 0, -thickness)]
    }

    var spine: [CGPoint] {
        [point(0, 0, -thickness), point(width, 0, -thickness), point(width, 0, 0), point(0, 0, 0)]
    }

    var left: [CGPoint] { [front[0], front[3], back[0], back[3]] }
    var right: [CGPoint] { [front[1], front[2], back[1], back[2]] }

    /// Map the unrotated face onto its projected quadrilateral. A single
    /// homography preserves the shared seams and the perspective of its text.
    static func transform(size: CGSize, corners p: [CGPoint]) -> ProjectionTransform {
        guard size.width > 0, size.height > 0, p.count == 4 else { return ProjectionTransform() }
        let dx1 = p[1].x - p[2].x, dx2 = p[3].x - p[2].x
        let dy1 = p[1].y - p[2].y, dy2 = p[3].y - p[2].y
        let dx3 = p[0].x - p[1].x + p[2].x - p[3].x
        let dy3 = p[0].y - p[1].y + p[2].y - p[3].y
        let denominator = dx1 * dy2 - dx2 * dy1
        // At the edge-on pose a face has zero area. Its vanishing affine
        // projection is still finite, unlike a division by the determinant.
        let g = abs(denominator) > 0.000_001 ? (dx3 * dy2 - dx2 * dy3) / denominator : 0
        let h = abs(denominator) > 0.000_001 ? (dx1 * dy3 - dx3 * dy1) / denominator : 0
        var transform = CATransform3DIdentity
        transform.m11 = (p[1].x - p[0].x + g * p[1].x) / size.width
        transform.m12 = (p[1].y - p[0].y + g * p[1].y) / size.width
        transform.m14 = g / size.width
        transform.m21 = (p[3].x - p[0].x + h * p[3].x) / size.height
        transform.m22 = (p[3].y - p[0].y + h * p[3].y) / size.height
        transform.m24 = h / size.height
        transform.m41 = p[0].x
        transform.m42 = p[0].y
        return ProjectionTransform(transform)
    }
}
