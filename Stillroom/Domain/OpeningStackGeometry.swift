import CoreGraphics
import Foundation

enum OpeningStackAxis { case vertical, horizontal }

/// Recovered first-run Album3DList/Item formulas, in logical points and degrees. Normal
/// library CoverFlow uses a different renderer. Source: intro-stack-geometry.json.
struct OpeningStackGeometry {
    let size: CGSize
    let axis: OpeningStackAxis
    let isPad: Bool

    init(size: CGSize, isPad: Bool = false) {
        self.size = CGSize(width: size.width.isFinite ? max(1, size.width) : 1,
                           height: size.height.isFinite ? max(1, size.height) : 1)
        self.axis = size.width > size.height ? .horizontal : .vertical
        self.isPad = isPad
    }

    var shortSideFactor: CGFloat { min(1, max(0, (min(size.width, size.height) - 375) / 459)) }
    var coverSide: CGFloat { max(1, min(size.width, size.height) - (70 + 130 * shortSideFactor)) }
    var stride: CGFloat { 87 + 41 * shortSideFactor }
    var spineThickness: CGFloat { isPad ? 20 : 16 }
    var spineFontSize: CGFloat { isPad ? 14 : 10 }
    var axisLength: CGFloat { axis == .vertical ? size.height : size.width }

    /// Safe-area/content-origin binding is not fully recovered. This finite-data adaptation
    /// centers the supplied collection; two albums stay two rows, never nine repeated slots.
    func contentOrigin(count: Int) -> CGFloat { (axisLength - CGFloat(max(0, count)) * stride) / 2 }

    func rowMidpoint(index: Int, count: Int, scrollOffset: CGFloat) -> CGFloat {
        CGFloat(index) * stride + stride / 2 + contentOrigin(count: count) + finite(scrollOffset)
    }

    func pose(midpoint: CGFloat, gravityY: Double) -> OpeningStackPose {
        let gravity = gravityY.isFinite ? gravityY : 0
        let value = 10 * Double((finite(midpoint) - axisLength / 2) / stride) - 30 * gravity
        let raw = value == 0 ? 0.01 : value
        return OpeningStackPose(rawAngle: raw, angle: min(60, max(-60, raw)))
    }

    func point(midpoint: CGFloat) -> CGPoint {
        axis == .vertical ? CGPoint(x: size.width / 2, y: midpoint) : CGPoint(x: midpoint, y: size.height / 2)
    }

    /// Portrait D=W-80 is recovered separately from source C. Vertical target position and
    /// landscape target size remain container adaptations shared with the existing Deck.
    var openFrame: CGRect {
        let side = axis == .vertical ? max(1, isPad ? size.width * 0.8 : size.width - 80) : coverSide
        return CGRect(x: (size.width - side) / 2, y: size.height * 0.46 - side / 2, width: side, height: side)
    }

    var extractionX: CGFloat { -(openFrame.width + size.width + 10) / 2 }

    func retirement(index: Int, selectedIndex: Int?, midpoint: CGFloat) -> OpeningStackRetirement {
        guard let selectedIndex, selectedIndex != index else { return .init(offset: 0, blur: 0, delay: 0) }
        let above = index < selectedIndex
        let distance = axisLength + stride
        let delay = max(0, Double(above ? midpoint : axisLength - midpoint) / 100) * 0.03
        return .init(offset: above ? -distance : distance, blur: 20, delay: delay)
    }

    func centeredScrollOffset(index: Int, count: Int) -> CGFloat {
        axisLength / 2 - (CGFloat(index) * stride + stride / 2 + contentOrigin(count: count))
    }

    private func finite(_ value: CGFloat) -> CGFloat { value.isFinite ? value : 0 }
}

struct OpeningStackPose: Equatable {
    let rawAngle: Double
    let angle: Double
    var zIndex: Double { -abs(rawAngle) }

    func surfaces(progress: Double, coverSide: CGFloat, spineThickness: CGFloat,
                  portrait: Bool) -> OpeningStackSurfaces {
        let t = progress.isFinite ? min(1, max(0, progress)) : 0
        let degrees = angle + (-90 - angle) * t
        // The recovered Transform interpolates its angle payload. Mirror, hinge and anchor
        // branches are re-evaluated from that angle. Mirror switches only at cover edge-on;
        // interpolating scale -1...+1 would wrongly collapse a still-visible face mid-turn.
        return OpeningStackSurfaces(coverDegrees: degrees + 90,
            spineDegrees: degrees,
            mirrorScaleX: degrees >= 0 ? -1 : 1,
            spineAnchorY: degrees > 0 ? 0 : 1,
            coverOffsetY: (coverSide - (degrees > 0 ? spineThickness : -spineThickness)) / 2,
            innerOffsetY: -spineThickness / 2 * t, innerHeight: coverSide * t,
            innerZDegrees: portrait ? -90 * t : 0, wrapperZDegrees: portrait ? 0 : -90 * t)
    }
}

struct OpeningStackSurfaces: Equatable {
    let coverDegrees: Double
    let spineDegrees: Double
    let mirrorScaleX: Double
    let spineAnchorY: Double
    let coverOffsetY: CGFloat
    let innerOffsetY: CGFloat
    let innerHeight: CGFloat
    let innerZDegrees: Double
    let wrapperZDegrees: Double
}

struct OpeningStackRetirement: Equatable {
    let offset: CGFloat
    let blur: CGFloat
    let delay: TimeInterval
}

/// Compatibility endpoint for Deck. Source C and selected target D remain distinct.
struct OpeningShelfPreviewLayout {
    let size: CGSize
    var isPad = false
    private var geometry: OpeningStackGeometry { OpeningStackGeometry(size: size, isPad: isPad) }
    var side: CGFloat { geometry.openFrame.width }
    var openCenterY: CGFloat { geometry.openFrame.midY }
    var openFrame: CGRect { geometry.openFrame }
}
