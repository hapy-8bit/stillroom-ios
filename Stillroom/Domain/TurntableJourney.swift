import Foundation

/// Logical-point rectangles, before sleeve rotation. Both the room and flight use this layout.
struct SleeveArtworkLayout {
    let record: CGRect
    let sleeve: CGRect

    init(width: CGFloat, top: CGFloat = 0) {
        record = CGRect(x: width * 0.32, y: top + width * 0.09, width: width * 0.66, height: width * 0.66)
        sleeve = CGRect(x: width * 0.035, y: top + width * 0.065, width: width * 0.62, height: width * 0.62)
    }
}

struct SleeveFlightOrigin: Equatable {
    let viewport: CGRect
    let artworkTop: CGFloat

    /// Capture the actual room viewport in global coordinates, including safe area and scrolling.
    func localLayout(in container: CGRect) -> (record: CGRect, sleeve: CGRect) {
        let source = SleeveArtworkLayout(width: viewport.width, top: artworkTop)
        let x = viewport.minX - container.minX
        let y = viewport.minY - container.minY
        return (source.record.offsetBy(dx: x, dy: y), source.sleeve.offsetBy(dx: x, dy: y))
    }
}

struct PlayerStageGeometry {
    let record: CGRect
    let tonearm: CGRect

    init(size: CGSize) {
        let width = max(0, size.width.isFinite ? size.width : 0)
        let height = max(0, size.height.isFinite ? size.height : 0)
        // The reference deliberately lets the left rim leave the canvas. Keep the label,
        // spindle and right rim visible; reserve the lower quarter for compact transport.
        let diameter = max(0, min(width * 1.14, height * 0.64))
        record = CGRect(x: width * 0.43 - diameter / 2, y: height * 0.365 - diameter / 2,
                        width: diameter, height: diameter)
        let armWidth = min(width * 0.26, diameter * 0.25)
        tonearm = CGRect(x: max(0, width - armWidth - width * 0.035),
                         y: max(0, record.minY + diameter * 0.025), width: armWidth, height: armWidth * 330 / 120)
    }
}

/// One normalized visual timeline, unrelated to audio seconds: extract → carry → settle → lower needle.
struct TurntableJourneyPose {
    static let duration = 2.25
    let record: CGRect
    let sleeve: CGRect
    let sleeveAngle: Double
    let sleeveOpacity: Double
    let recordOpacity: Double
    let armOpacity: Double
    let needle: Double
    let backdrop: Double
    let controls: Double
    let placed: Bool

    init(progress: Double, origin: SleeveFlightOrigin?, container: CGRect, reducedMotion: Bool) {
        let p = progress.isFinite ? min(1, max(0, progress)) : 0
        let target = PlayerStageGeometry(size: container.size)
        backdrop = Self.phase(p, from: 0.14, to: 0.76)
        controls = Self.phase(p, from: 0.88, to: 1)
        if reducedMotion || origin == nil {
            record = target.record
            sleeve = .zero
            sleeveAngle = 0
            sleeveOpacity = 0
            recordOpacity = Self.phase(p, from: 0, to: reducedMotion ? 1 : 0.35)
            armOpacity = recordOpacity
            needle = reducedMotion ? 1 : Self.phase(p, from: 0.6, to: 1)
            placed = reducedMotion || p >= 0.6
            return
        }
        let start = origin!.localLayout(in: container)
        let width = container.width
        let liftY = min(start.record.midY, container.height * 0.4)
        // A slight camera pullback lets the rim clear the sleeve entirely inside a phone width.
        let extractedRecord = Self.rect(center: CGPoint(x: width * 0.745, y: liftY), side: width * 0.485)
        let extractedSleeve = Self.rect(center: CGPoint(x: width * 0.21, y: liftY), side: width * 0.455)
        let extract = Self.phase(p, from: 0, to: 0.36)
        let carry = Self.phase(p, from: 0.36, to: 0.76)
        record = p <= 0.36 ? Self.mix(start.record, extractedRecord, extract) : Self.mix(extractedRecord, target.record, carry)
        let departingSleeve = extractedSleeve.offsetBy(dx: -width * 0.62, dy: -width * 0.08)
        sleeve = p <= 0.36 ? Self.mix(start.sleeve, extractedSleeve, extract) : Self.mix(extractedSleeve, departingSleeve, carry)
        sleeveAngle = -8 - 4 * extract - 7 * carry
        sleeveOpacity = 1 - Self.phase(p, from: 0.43, to: 0.7)
        recordOpacity = 1
        armOpacity = Self.phase(p, from: 0.62, to: 0.79)
        needle = Self.phase(p, from: 0.8, to: 1)
        placed = p >= 0.8
    }

    static func phase(_ p: Double, from start: Double, to end: Double) -> Double {
        let t = min(1, max(0, (p - start) / (end - start)))
        return t * t * (3 - 2 * t)
    }

    private static func rect(center: CGPoint, side: CGFloat) -> CGRect {
        CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }

    private static func mix(_ a: CGRect, _ b: CGRect, _ t: Double) -> CGRect {
        CGRect(x: a.minX + (b.minX - a.minX) * t, y: a.minY + (b.minY - a.minY) * t,
               width: a.width + (b.width - a.width) * t, height: a.height + (b.height - a.height) * t)
    }
}
