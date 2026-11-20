import SwiftUI

struct OneTapeMouldOutline: Shape {
    let style: OneTapeAppearance.TapeStyle

    func path(in rect: CGRect) -> Path {
        let canvas = OneTapeMouldGeometry.size
        return OneTapeMouldGeometry(style: style).outline.applying(
            CGAffineTransform(a: rect.width / canvas.width, b: 0, c: 0,
                d: rect.height / canvas.height, tx: rect.minX, ty: rect.minY))
    }
}

/// All sculpted mould assets are pre-registered to `OneTapeCassetteStandard.landscapeCanvasSize`
/// (`576×376.33`) with identical supply/take-up spindle centers and identical 58pt/77pt hubs.
/// Source outlines and landing pads map cleanly onto `frameRect` so outer contours,
/// corner hardware, and brand typography stay calibrated across every style.
struct OneTapeMouldGeometry {
    static let size = OneTapeCassetteStandard.landscapeCanvasSize
    let style: OneTapeAppearance.TapeStyle

    private struct SourceLayout {
        let name: String
        let canonicalSlots: [CGRect]
        let word: CGRect
        let duration: CGRect
        let count: CGRect
        let headTop: CGFloat
        let ports: [CGRect]
    }

    private var layout: SourceLayout {
        switch style {
        case .strata:
            return SourceLayout(name: "Strata",
                canonicalSlots: [CGRect(x: 234, y: 151, width: 108, height: 44)],
                word: CGRect(x: 182, y: 146, width: 363, height: 62),
                duration: CGRect(x: 1085, y: 141, width: 318, height: 66),
                count: CGRect(x: 666, y: 635, width: 210, height: 60), headTop: 742,
                ports: [CGRect(x: 422, y: 872, width: 55, height: 58), CGRect(x: 537, y: 848, width: 62, height: 69), CGRect(x: 943, y: 848, width: 63, height: 69), CGRect(x: 1063, y: 872, width: 56, height: 58)])
        case .facet:
            return SourceLayout(name: "Facet",
                canonicalSlots: [CGRect(x: 249, y: 166, width: 78, height: 13)],
                word: CGRect(x: 173, y: 193, width: 412, height: 72),
                duration: CGRect(x: 1174, y: 173, width: 239, height: 129),
                count: CGRect(x: 1255, y: 607, width: 172, height: 128), headTop: 741,
                ports: [CGRect(x: 398, y: 861, width: 65, height: 65), CGRect(x: 529, y: 839, width: 65, height: 71), CGRect(x: 929, y: 839, width: 66, height: 71), CGRect(x: 1064, y: 861, width: 65, height: 65)])
        case .islands:
            return SourceLayout(name: "Islands",
                canonicalSlots: [],
                word: CGRect(x: 657, y: 430, width: 230, height: 65),
                duration: CGRect(x: 1216, y: 126, width: 219, height: 125),
                count: CGRect(x: 94, y: 125, width: 170, height: 125), headTop: 765,
                ports: [CGRect(x: 393, y: 850, width: 65, height: 66), CGRect(x: 548, y: 825, width: 83, height: 93), CGRect(x: 902, y: 825, width: 84, height: 93), CGRect(x: 1072, y: 850, width: 66, height: 66)])
        case .ribs:
            return SourceLayout(name: "Ribs",
                canonicalSlots: [],
                word: CGRect(x: 635, y: 435, width: 290, height: 65),
                duration: CGRect(x: 91, y: 96, width: 249, height: 120),
                count: CGRect(x: 1285, y: 95, width: 150, height: 127), headTop: 774,
                ports: [CGRect(x: 378, y: 883, width: 65, height: 65), CGRect(x: 512, y: 869, width: 65, height: 73), CGRect(x: 972, y: 869, width: 65, height: 73), CGRect(x: 1099, y: 883, width: 65, height: 65)])
        case .stream:
            return SourceLayout(name: "Stream",
                canonicalSlots: [],
                word: CGRect(x: 638, y: 451, width: 290, height: 74),
                duration: CGRect(x: 1171, y: 119, width: 230, height: 128),
                count: CGRect(x: 83, y: 657, width: 169, height: 131), headTop: 773,
                ports: [CGRect(x: 388, y: 878, width: 64, height: 66), CGRect(x: 529, y: 847, width: 65, height: 80), CGRect(x: 987, y: 847, width: 65, height: 80), CGRect(x: 1114, y: 878, width: 65, height: 66)])
        case .eclipse:
            return SourceLayout(name: "Eclipse",
                canonicalSlots: [],
                word: CGRect(x: 665, y: 429, width: 222, height: 65),
                duration: CGRect(x: 1103, y: 114, width: 281, height: 59),
                count: CGRect(x: 139, y: 707, width: 221, height: 67), headTop: 798,
                ports: [CGRect(x: 387, y: 880, width: 66, height: 68), CGRect(x: 515, y: 874, width: 68, height: 68), CGRect(x: 944, y: 874, width: 69, height: 68), CGRect(x: 1077, y: 880, width: 68, height: 68)])
        default: return OneTapeMouldGeometry(style: .strata).layout
        }
    }

    var asset: String { "OneTapeMould" + layout.name + "Closed" }
    var axles: [CGPoint] {
        [OneTapeCassetteStandard.landscapeSupplyCenter,
         OneTapeCassetteStandard.landscapeTakeupCenter]
    }
    var hubRadii: [CGFloat] {
        [OneTapeCassetteStandard.driveHubRadius,
         OneTapeCassetteStandard.driveHubRadius]
    }
    var shaftRadii: [CGFloat] {
        [OneTapeCassetteStandard.shaftPinRadius,
         OneTapeCassetteStandard.shaftPinRadius]
    }
    var wordRect: CGRect { layout.word.applying(sourceTransform) }
    var durationRect: CGRect { layout.duration.applying(sourceTransform) }
    var countRect: CGRect { layout.count.applying(sourceTransform) }
    var ink: Color { Color(white: 0.13) }

    static let illustrationDurationRect = CGRect(x: 168, y: 286, width: 140, height: 14)
    static let illustrationCountRect = CGRect(x: 328, y: 286, width: 80, height: 14)

    static var frameRect: CGRect { OneTapeCassetteStandard.landscapeShellFrame }

    var axleDistance: CGFloat { OneTapeCassetteStandard.axleSpacing }

    var packScale: CGFloat { 1.0 }

    var hasSlots: Bool { !layout.canonicalSlots.isEmpty }

    var hasTapeWindow: Bool {
        switch style {
        case .strata, .facet:
            return true
        default:
            return false
        }
    }

    var slotsPath: Path {
        guard hasTapeWindow else { return Path() }
        var result = Path()
        for rect in layout.canonicalSlots {
            result.addPath(rounded(rect, radius: 4))
        }
        return result
    }

    /// Standardized shell images are isotropic at `576×376.33`, so turning drives stay pure circles.
    var driveStretch: CGSize { CGSize(width: 1, height: 1) }

    var photoFrame: CGRect { CGRect(origin: .zero, size: Self.size) }

    private static let sourceTransforms: [OneTapeAppearance.TapeStyle: CGAffineTransform] = {
        Dictionary(uniqueKeysWithValues: OneTapeAppearance.TapeStyle.sculpted.map { style in
            let bounds = Self(style: style).sourceOutline.boundingRect
            let target = Self.frameRect
            let xScale = target.width / bounds.width
            let yScale = target.height / bounds.height
            return (style, CGAffineTransform(a: xScale, b: 0, c: 0, d: yScale,
                tx: target.minX - bounds.minX * xScale,
                ty: target.minY - bounds.minY * yScale))
        })
    }()

    private var sourceTransform: CGAffineTransform {
        Self.sourceTransforms[style] ?? Self.sourceTransforms[.strata] ?? .identity
    }

    var outline: Path { sourceOutline.applying(sourceTransform) }

    private var sourceOutline: Path {
        switch style {
        case .strata:
            var path = Path()
            path.move(to: CGPoint(x: 59, y: 108))
            path.addQuadCurve(to: CGPoint(x: 105, y: 61), control: CGPoint(x: 59, y: 61))
            // addLines begins a new subpath and would close this shoulder with
            // a diagonal. Continue the current contour through every corner.
            for point in [CGPoint(x: 207, y: 61), CGPoint(x: 237, y: 44),
                          CGPoint(x: 1286, y: 44), CGPoint(x: 1316, y: 61), CGPoint(x: 1444, y: 61)] {
                path.addLine(to: point)
            }
            path.addQuadCurve(to: CGPoint(x: 1492, y: 111), control: CGPoint(x: 1492, y: 61))
            path.addLine(to: CGPoint(x: 1492, y: 906))
            path.addQuadCurve(to: CGPoint(x: 1449, y: 955), control: CGPoint(x: 1492, y: 955))
            path.addLine(to: CGPoint(x: 99, y: 955))
            path.addQuadCurve(to: CGPoint(x: 53, y: 906), control: CGPoint(x: 53, y: 955))
            path.closeSubpath()
            return path
        case .facet:
            return polygon([(98,77),(1437,77),(1480,120),(1492,166),
                (1492,902),(1445,955),(88,955),(47,916),(47,133)])
        case .islands: return rounded(CGRect(x: 42, y: 68, width: 1452, height: 886), radius: 44)
        case .ribs: return rounded(CGRect(x: 28, y: 42, width: 1475, height: 939), radius: 68)
        case .stream: return rounded(CGRect(x: 30, y: 40, width: 1503, height: 930), radius: 74)
        case .eclipse: return rounded(CGRect(x: 52, y: 59, width: 1439, height: 916), radius: 48)
        default: return Path(CGRect(origin: .zero, size: Self.size))
        }
    }

    /// Closed shells expose only drive collars and the remaining small slots.
    /// Both openings follow `OneTapeCassetteStandard` identically across all six moulds.
    var windows: Path {
        var result = Path()
        for center in axles {
            result = result.union(circle(center, radius: OneTapeCassetteStandard.reelCollarRadius + 3))
        }
        for rect in layout.canonicalSlots {
            result = result.union(rounded(rect.insetBy(dx: -2, dy: -2), radius: 6))
        }
        return result
    }

    var guidePorts: Path {
        var result = Path()
        for rect in layout.ports { result.addPath(rounded(rect, radius: rect.width * 0.25)) }
        return result.applying(sourceTransform)
    }

    var headRail: Path {
        let sourceBounds = sourceOutline.boundingRect
        return Path(CGRect(x: sourceBounds.minX + 60, y: layout.headTop,
                           width: sourceBounds.width - 120,
                           height: sourceBounds.maxY - layout.headTop))
            .applying(sourceTransform)
    }

    var face: Path { outline.subtracting(windows).subtracting(guidePorts) }

    private func circle(_ center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                              width: radius * 2, height: radius * 2))
    }

    private func rounded(_ rect: CGRect, radius: CGFloat) -> Path {
        Path(roundedRect: rect, cornerRadius: radius)
    }

    private func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        var result = Path()
        guard let first = points.first else { return result }
        result.move(to: CGPoint(x: first.0, y: first.1))
        for point in points.dropFirst() { result.addLine(to: CGPoint(x: point.0, y: point.1)) }
        result.closeSubpath()
        return result
    }
}

struct OneTapeMouldPortrait<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(width: OneTapeMouldGeometry.size.width, height: OneTapeMouldGeometry.size.height)
            .rotationEffect(.degrees(90))
            .position(x: 188.165, y: 288)
            .frame(width: 376.33, height: 576)
    }
}
