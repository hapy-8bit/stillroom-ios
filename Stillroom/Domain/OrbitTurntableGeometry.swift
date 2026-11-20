import CoreGraphics

/// Layout values are logical points. Portrait ratios come from the user's loaded-player
/// reference, excluding the Mac mirror surround. Safe areas are removed once on conversion.
struct OrbitTurntableGeometry {
    let record: CGRect
    let arm: CGRect
    let armPivot: CGPoint

    init(size: CGSize, safeTop: CGFloat = 0, safeBottom: CGFloat = 0) {
        let width = size.width.isFinite ? max(1, size.width) : 1
        let height = size.height.isFinite ? max(1, size.height) : 1
        let top = safeTop.isFinite ? max(0, safeTop) : 0
        let bottom = safeBottom.isFinite ? max(0, safeBottom) : 0
        let fullHeight = height + top + bottom
        let wide = width / fullHeight > 0.72

        // Short/wide windows need a height bound, otherwise the rim enters the controls. Wide
        // windows use a contained left stage rather than stretching a portrait crop across them.
        let diameter = min(width * (wide ? 0.62 : 1.211), fullHeight * (wide ? 0.64 : 0.57))
        let center = CGPoint(x: width * (wide ? 0.32 : 0.265),
                             y: fullHeight * (wide ? 0.395 : 0.352) - top)
        record = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                        width: diameter, height: diameter)

        // Pickup artwork uses a 120×440 coordinate system with pivot (70,50). Its parked
        // support reaches 47 source units right; keep that geometry inside the trailing edge.
        let scale = min(width * 0.309 / 120, fullHeight * 0.435 / 365)
        let desiredX = wide ? record.maxX + diameter * 0.02 : width * 0.863
        armPivot = CGPoint(x: min(desiredX, width - min(8, width * 0.02) - 47 * scale),
                           y: fullHeight * (wide ? 0.181 : 0.136) - top)
        arm = CGRect(x: armPivot.x - 70 * scale, y: armPivot.y - 50 * scale,
                     width: 120 * scale, height: 440 * scale)
    }
}
