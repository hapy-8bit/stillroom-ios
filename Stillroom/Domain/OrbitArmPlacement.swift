import CoreGraphics
import Foundation

enum OrbitArmPlacement {
    /// Source artwork coordinates are 120 x 330, pivot (81,30). The rotated metal/headshell
    /// extends beyond its unrotated frame when parked; bound the drawn geometry before placing
    /// that pivot near the trailing edge. All returned values are logical points, not device pixels.
    static func centerX(viewportWidth: CGFloat, recordLeft: CGFloat, recordSide: CGFloat) -> CGFloat {
        let width = recordSide * 0.39
        let reach = maximumRightReach * width / 120
        let pivot = min(recordLeft + recordSide * 0.98, viewportWidth - 8 - reach)
        return pivot + width * (0.5 - 81.0 / 120)
    }

    private static let maximumRightReach: CGFloat = {
        var geometry: [CGPoint] = [CGPoint(x: 81, y: 25), CGPoint(x: 81, y: 228),
            CGPoint(x: 81, y: 252), CGPoint(x: 59, y: 266), CGPoint(x: 39, y: 287)]
        for corner in [CGPoint(x: -11, y: -24), CGPoint(x: 11, y: -24), CGPoint(x: -11, y: 24), CGPoint(x: 11, y: 24)] {
            let angle = 34.0 * .pi / 180
            geometry.append(CGPoint(x: 32 + corner.x * cos(angle) - corner.y * sin(angle),
                                    y: 290 + corner.x * sin(angle) + corner.y * cos(angle)))
        }
        var maximum: CGFloat = 113 // Fixed pivot support: center81 + radius32.
        for degrees in -14...18 {
            let radians = CGFloat(degrees) * .pi / 180
            for point in geometry {
                let x = 81 + (point.x - 81) * cos(radians) - (point.y - 30) * sin(radians)
                maximum = max(maximum, x + 8) // Metal stroke plus its static shadow.
            }
        }
        return maximum - 81
    }()
}
