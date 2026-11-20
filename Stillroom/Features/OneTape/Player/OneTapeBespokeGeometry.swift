import SwiftUI

/// Calibrated 288×195 landscape construction coordinates registered identically
/// to `OneTapeCassettePocketMask.shellFrame` in portrait canvas space.
enum OneTapeBespokeGeometry {
    static let canvasSize = CGSize(width: 288, height: 195)
    static let scale: CGFloat = 2.106
    static let shellFrame = CGRect(x: 13, y: 15, width: 261, height: 166)
    static let supply = OneTapeCassetteStandard.landscape288Point(
        fromPortrait: OneTapeCassetteStandard.portraitSupplyCenter, via: portraitTransform)
    static let takeup = OneTapeCassetteStandard.landscape288Point(
        fromPortrait: OneTapeCassetteStandard.portraitTakeupCenter, via: portraitTransform)
    static let screws = [
        CGPoint(x: 24, y: 26), CGPoint(x: 263, y: 26),
        CGPoint(x: 24, y: 170), CGPoint(x: 263, y: 170),
        CGPoint(x: 144, y: 150)
    ]
    static let bottomCapstans = [CGPoint(x: 82, y: 168), CGPoint(x: 206, y: 168)]
    static let bottomGuides = [CGPoint(x: 108, y: 164), CGPoint(x: 180, y: 164)]

    static let armatureWindow = CGRect(x: 26, y: 46, width: 236, height: 84)
    static let fieldNotesWindow = CGRect(x: 84, y: 74, width: 120, height: 32)
    static let silverOvalWindow = CGRect(x: 34, y: 48, width: 220, height: 84)

    static var drawingScale: CGSize {
        let target = OneTapeCassettePocketMask.shellFrame
        return CGSize(width: target.height / shellFrame.width,
                      height: target.width / shellFrame.height)
    }

    static var portraitTransform: CGAffineTransform {
        let target = OneTapeCassettePocketMask.shellFrame
        return CGAffineTransform(a: 0, b: drawingScale.width, c: -drawingScale.height, d: 0,
            tx: target.maxX + shellFrame.minY * drawingScale.height,
            ty: target.minY - shellFrame.minX * drawingScale.width)
    }

    static var canvasCenter: CGPoint {
        CGPoint(x: 144, y: 97.5).applying(portraitTransform)
    }

    static var shell: Path { Path(roundedRect: shellFrame, cornerRadius: 11) }

    static var lowerHeadDeck: Path {
        polygon([
            CGPoint(x: 66, y: 142), CGPoint(x: 221, y: 142),
            CGPoint(x: 233, y: 181), CGPoint(x: 55, y: 181)
        ])
    }

    static var twinArcFigure8: Path {
        let radius: CGFloat = 46
        var path = Path()
        path.move(to: CGPoint(x: supply.x, y: supply.y - radius))
        for deg in stride(from: -90.0, through: -270.0, by: -5.0) {
            let rad = deg * .pi / 180
            path.addLine(to: CGPoint(x: supply.x + cos(rad) * radius, y: supply.y + sin(rad) * radius))
        }
        path.addQuadCurve(to: CGPoint(x: takeup.x, y: takeup.y + radius),
                          control: CGPoint(x: 144, y: takeup.y + 28))
        for deg in stride(from: 90.0, through: -90.0, by: -5.0) {
            let rad = deg * .pi / 180
            path.addLine(to: CGPoint(x: takeup.x + cos(rad) * radius, y: takeup.y + sin(rad) * radius))
        }
        path.addQuadCurve(to: CGPoint(x: supply.x, y: supply.y - radius),
                          control: CGPoint(x: 144, y: supply.y - 28))
        path.closeSubpath()
        return path
    }

    static func landscapeWindow(for style: OneTapeAppearance.TapeStyle) -> Path {
        switch style {
        case .armature:
            return Path(roundedRect: armatureWindow, cornerRadius: 5)
        case .fieldNotes:
            return Path(roundedRect: fieldNotesWindow, cornerRadius: 16)
                .union(circle(center: supply, radius: 30))
                .union(circle(center: takeup, radius: 30))
        case .silverOval:
            return Path(roundedRect: silverOvalWindow, cornerRadius: silverOvalWindow.height / 2)
        case .twinArc:
            return twinArcFigure8
        default:
            return Path()
        }
    }

    static func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    static func circle(center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                               width: radius * 2, height: radius * 2))
    }

    static func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    static func gear(center: CGPoint, outer: CGFloat, root: CGFloat, teeth: Int) -> Path {
        polygon((0..<(teeth * 4)).map { index in
            let edge = index % 4
            let radius = edge == 1 || edge == 2 ? outer : root
            return point(center: center, radius: radius, angle: Double(index) * 2 * .pi / Double(teeth * 4))
        })
    }

    static func annularSector(center: CGPoint, inner: CGFloat, outer: CGFloat,
                              startDegrees: Double, endDegrees: Double) -> Path {
        let outside = (0...20).map { i in
            point(center: center, radius: outer, angle: (startDegrees + (endDegrees - startDegrees) * Double(i) / 20) * .pi / 180)
        }
        let inside = (0...20).reversed().map { i in
            point(center: center, radius: inner, angle: (startDegrees + (endDegrees - startDegrees) * Double(i) / 20) * .pi / 180)
        }
        return polygon(outside + inside)
    }
}
