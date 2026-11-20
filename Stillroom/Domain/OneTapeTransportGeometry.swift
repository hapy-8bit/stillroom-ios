import CoreGraphics

/// Artwork and interaction share this logical-point layout. The source centers
/// only locate the three photographed keys inside the unchanged body resource.
enum OneTapeTransportGeometry {
    static let centerX: CGFloat = 48.06
    static let sourceDiameter: CGFloat = 65.33
    static let visualDiameter: CGFloat = 58
    static let visualScale = visualDiameter / sourceDiameter
    static let sourceCentersY: [CGFloat] = [670.89, 733.93, 796.97]
    static let centersY: [CGFloat] = [666, 734, 802]

    static func visualFrame(centerY: CGFloat) -> CGRect {
        CGRect(x: centerX - visualDiameter / 2, y: centerY - visualDiameter / 2,
               width: visualDiameter, height: visualDiameter)
    }

    static func sourceFrame(centerY: CGFloat) -> CGRect {
        CGRect(x: centerX - sourceDiameter / 2, y: centerY - sourceDiameter / 2,
               width: sourceDiameter, height: sourceDiameter)
    }

    static func hitDiameter(scale: CGFloat) -> CGFloat {
        max(visualDiameter, 44 / max(0.01, scale))
    }
}
