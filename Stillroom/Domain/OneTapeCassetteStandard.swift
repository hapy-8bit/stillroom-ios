import CoreGraphics

/// Single authoritative physical cassette specification shared by every tape edition
/// (standard shells, sculpted moulds, bespoke CAD mechanisms, brand print, and future styles).
/// All geometric coordinates are logical points independent of screen scale or media time.
enum OneTapeCassetteStandard {
    static let portraitCanvasSize = CGSize(width: 376.33, height: 576)
    static let landscapeCanvasSize = CGSize(width: 576, height: 376.33)

    /// Visible plastic bounds inside the cassette's portrait and landscape canvases.
    static let portraitShellFrame = CGRect(x: 13.33, y: 13.33, width: 349.67, height: 549.33)
    static let landscapeShellFrame = CGRect(x: 13.33, y: 13.33, width: 549.33, height: 349.67)

    /// Canonical supply and take-up reel spindle centers in portrait 376.33×576 space.
    static let portraitSupplyCenter = CGPoint(x: 204.01, y: 171.81)
    static let portraitTakeupCenter = CGPoint(x: 204.01, y: 403.93)

    /// Canonical spindle centers in 576×376.33 landscape space (rotated +90° into portrait).
    static let landscapeSupplyCenter = CGPoint(x: 171.81, y: 172.32)
    static let landscapeTakeupCenter = CGPoint(x: 403.93, y: 172.32)

    static let axleSpacing: CGFloat = 232.12

    /// Unified standard reel aperture (58pt drive core inside 77pt bezel collar) and pin (18pt).
    static let driveHubRadius: CGFloat = 29.0
    static let driveHubDiameter: CGFloat = 58.0
    static let reelCollarRadius: CGFloat = 38.5
    static let reelCollarDiameter: CGFloat = 77.0
    static let shaftPinRadius: CGFloat = 9.0
    static let shaftPinDiameter: CGFloat = 18.0
    static let classicGearFrameDiameter: CGFloat = 242.0 / 3.0

    /// Converts a canonical portrait point on `376.33×576` into any 288×195 landscape CAD grid
    /// transformed by `portraitTransform` (used by bespoke & bronze CAD constructions).
    static func landscape288Point(fromPortrait point: CGPoint, via portraitTransform: CGAffineTransform) -> CGPoint {
        point.applying(portraitTransform.inverted())
    }
}
