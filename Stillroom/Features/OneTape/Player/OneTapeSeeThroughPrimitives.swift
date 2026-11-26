import CoreGraphics

/// Reusable 3D-shaded electro-mechanical hardware drawing primitives used by
/// `OneTapeSeeThroughBaker` to bake photorealistic gears, flywheels, DC motors,
/// shaded coil springs, PCB components, solder domes, and glossy insulated wires.
enum OneTapeSeeThroughPrimitives {
    static let cs = CGColorSpaceCreateDeviceRGB()

    static func drawTurnedFlywheel(in ctx: CGContext, center: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.5, height: 2.0), blur: 3.2, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.78))
        ctx.setFillColor(red: 0.25, green: 0.25, blue: 0.24, alpha: 1.0)
        ctx.fillEllipse(in: rect)
        ctx.restoreGState()

        // Outer bright chamfered machined stainless rim.
        ctx.saveGState()
        ctx.addEllipse(in: rect)
        ctx.clip()
        drawLinearGradient(
            in: ctx,
            stops: [(0, 0.86, 0.85, 0.82, 1), (0.45, 0.42, 0.41, 0.39, 1), (1, 0.72, 0.70, 0.67, 1)],
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        ctx.restoreGState()

        // Recessed satin gunmetal flywheel web.
        let web = rect.insetBy(dx: 1.9, dy: 1.9)
        ctx.saveGState()
        ctx.addEllipse(in: web)
        ctx.clip()
        drawLinearGradient(
            in: ctx,
            stops: [(0, 0.19, 0.19, 0.18, 1), (0.5, 0.34, 0.33, 0.31, 1), (1, 0.22, 0.21, 0.20, 1)],
            start: CGPoint(x: web.minX, y: web.minY),
            end: CGPoint(x: web.maxX, y: web.maxY)
        )
        ctx.restoreGState()

        // Inner turned boss & gleaming brass capstan shaft.
        let hub = rect.insetBy(dx: radius * 0.52, dy: radius * 0.52)
        ctx.setFillColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1.0)
        ctx.fillEllipse(in: hub)
        ctx.setStrokeColor(red: 0.74, green: 0.72, blue: 0.68, alpha: 0.82)
        ctx.setLineWidth(1.0)
        ctx.strokeEllipse(in: hub)

        let spindle = CGRect(x: center.x - 2.6, y: center.y - 2.6, width: 5.2, height: 5.2)
        ctx.saveGState()
        ctx.addEllipse(in: spindle)
        ctx.clip()
        drawLinearGradient(
            in: ctx,
            stops: [(0, 0.94, 0.84, 0.56, 1), (0.6, 0.66, 0.54, 0.28, 1), (1, 0.82, 0.70, 0.42, 1)],
            start: CGPoint(x: spindle.minX, y: spindle.minY),
            end: CGPoint(x: spindle.maxX, y: spindle.maxY)
        )
        ctx.restoreGState()
    }

    static func drawPrecisionSpurGear(
        in ctx: CGContext,
        center: CGPoint,
        outerR: CGFloat,
        rootR: CGFloat,
        teeth: Int,
        phase: CGFloat
    ) {
        // Flat-topped involute-like trapezoidal spur gear profile.
        let path = CGMutablePath()
        let step = (CGFloat.pi * 2) / CGFloat(teeth)
        for i in 0..<teeth {
            let a0 = phase + CGFloat(i) * step
            let p0 = CGPoint(x: center.x + cos(a0 + step * 0.08) * rootR, y: center.y + sin(a0 + step * 0.08) * rootR)
            let p1 = CGPoint(x: center.x + cos(a0 + step * 0.22) * outerR, y: center.y + sin(a0 + step * 0.22) * outerR)
            let p2 = CGPoint(x: center.x + cos(a0 + step * 0.48) * outerR, y: center.y + sin(a0 + step * 0.48) * outerR)
            let p3 = CGPoint(x: center.x + cos(a0 + step * 0.62) * rootR, y: center.y + sin(a0 + step * 0.62) * rootR)
            if i == 0 { path.move(to: p0) } else { path.addLine(to: p0) }
            path.addLine(to: p1)
            path.addLine(to: p2)
            path.addLine(to: p3)
        }
        path.closeSubpath()

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.5, height: 1.5), blur: 2.2, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.72))
        ctx.setFillColor(red: 0.72, green: 0.68, blue: 0.58, alpha: 1.0)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let bounds = CGRect(x: center.x - outerR, y: center.y - outerR, width: outerR * 2, height: outerR * 2)
        drawLinearGradient(
            in: ctx,
            stops: [(0, 0.88, 0.84, 0.74, 1), (0.5, 0.66, 0.62, 0.52, 1), (1, 0.46, 0.43, 0.36, 1)],
            start: CGPoint(x: bounds.minX, y: bounds.minY),
            end: CGPoint(x: bounds.maxX, y: bounds.maxY)
        )
        ctx.restoreGState()

        ctx.setStrokeColor(red: 0.16, green: 0.15, blue: 0.12, alpha: 0.65)
        ctx.setLineWidth(0.45)
        ctx.addPath(path)
        ctx.strokePath()

        let webR = rootR * 0.66
        ctx.setFillColor(red: 0.36, green: 0.34, blue: 0.29, alpha: 0.88)
        ctx.fillEllipse(in: CGRect(x: center.x - webR, y: center.y - webR, width: webR * 2, height: webR * 2))
        let boreR = rootR * 0.28
        ctx.setFillColor(red: 0.14, green: 0.15, blue: 0.16, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: center.x - boreR, y: center.y - boreR, width: boreR * 2, height: boreR * 2))
        ctx.setStrokeColor(red: 0.88, green: 0.86, blue: 0.80, alpha: 0.7)
        ctx.setLineWidth(0.55)
        ctx.strokeEllipse(in: CGRect(x: center.x - boreR - 0.6, y: center.y - boreR - 0.6, width: (boreR + 0.6) * 2, height: (boreR + 0.6) * 2))
    }

    static func drawTurnedBrassPulley(in ctx: CGContext, center: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.4, height: 1.4), blur: 2.0, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.7))
        ctx.addEllipse(in: rect)
        ctx.clip()
        drawLinearGradient(
            in: ctx,
            stops: [(0, 0.94, 0.82, 0.48, 1), (0.5, 0.70, 0.56, 0.26, 1), (1, 0.46, 0.36, 0.16, 1)],
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        ctx.restoreGState()

        ctx.setStrokeColor(red: 0.96, green: 0.88, blue: 0.58, alpha: 0.82)
        ctx.setLineWidth(0.75)
        ctx.strokeEllipse(in: rect.insetBy(dx: 1.8, dy: 1.8))
        ctx.setFillColor(red: 0.20, green: 0.21, blue: 0.22, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: center.x - 2.0, y: center.y - 2.0, width: 4.0, height: 4.0))
    }

    static func drawDCMicroMotor(in ctx: CGContext, rect: CGRect) {
        let body = CGPath(roundedRect: rect, cornerWidth: 3.0, cornerHeight: 3.0, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 2.0), blur: 3.2, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.78))
        ctx.setFillColor(red: 0.34, green: 0.36, blue: 0.38, alpha: 1.0)
        ctx.addPath(body)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()
        drawLinearGradient(
            in: ctx,
            stops: [
                (0.00, 0.34, 0.36, 0.38, 1),
                (0.22, 0.76, 0.78, 0.80, 1),
                (0.42, 0.48, 0.50, 0.52, 1),
                (0.76, 0.16, 0.17, 0.19, 1),
                (1.00, 0.42, 0.44, 0.46, 1)
            ],
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.minX, y: rect.maxY)
        )
        ctx.setFillColor(red: 0.20, green: 0.21, blue: 0.23, alpha: 0.72)
        ctx.fill(CGRect(x: rect.minX + 5.5, y: rect.minY, width: 1.2, height: rect.height))
        ctx.fill(CGRect(x: rect.maxX - 7.5, y: rect.minY, width: 1.2, height: rect.height))
        ctx.restoreGState()

        ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.45)
        ctx.setLineWidth(0.7)
        ctx.addPath(body)
        ctx.strokePath()

        // Recessed motor vents showing multi-strand shaded copper stator windings.
        for x in [rect.minX + 13.5, rect.minX + 32.0] {
            for dy in [CGFloat(3.4), rect.height - 7.6] {
                let slot = CGRect(x: x, y: rect.minY + dy, width: 13.0, height: 4.2)
                let sp = CGPath(roundedRect: slot, cornerWidth: 1.6, cornerHeight: 1.6, transform: nil)
                ctx.saveGState()
                ctx.addPath(sp)
                ctx.clip()
                drawLinearGradient(
                    in: ctx,
                    stops: [(0, 0.36, 0.16, 0.06, 1), (0.45, 0.78, 0.42, 0.18, 1), (1, 0.28, 0.12, 0.05, 1)],
                    start: CGPoint(x: slot.minX, y: slot.minY),
                    end: CGPoint(x: slot.minX, y: slot.maxY)
                )
                ctx.setStrokeColor(red: 0.94, green: 0.62, blue: 0.30, alpha: 0.42)
                ctx.setLineWidth(0.55)
                for wx in stride(from: slot.minX + 1.4, through: slot.maxX - 1.2, by: 1.6) {
                    ctx.move(to: CGPoint(x: wx, y: slot.minY))
                    ctx.addLine(to: CGPoint(x: wx, y: slot.maxY))
                }
                ctx.strokePath()
                ctx.restoreGState()
            }
        }
        drawPhillipsScrew(in: ctx, center: CGPoint(x: rect.minX + 2.8, y: rect.minY + 3.5), radius: 1.9, brass: false)
        drawPhillipsScrew(in: ctx, center: CGPoint(x: rect.minX + 2.8, y: rect.maxY - 3.5), radius: 1.9, brass: false)
    }

    static func drawDriveBelt(in ctx: CGContext, from a: CGPoint, r1: CGFloat, to b: CGPoint, r2: CGFloat) {
        let topPath = CGMutablePath()
        topPath.move(to: CGPoint(x: a.x, y: a.y - r1))
        topPath.addLine(to: CGPoint(x: b.x, y: b.y - r2))
        let botPath = CGMutablePath()
        botPath.move(to: CGPoint(x: a.x, y: a.y + r1))
        botPath.addLine(to: CGPoint(x: b.x, y: b.y + r2))

        for path in [topPath, botPath] {
            ctx.setStrokeColor(red: 0.035, green: 0.038, blue: 0.042, alpha: 0.96)
            ctx.setLineWidth(2.6)
            ctx.addPath(path)
            ctx.strokePath()
            ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.14)
            ctx.setLineWidth(0.6)
            ctx.addPath(path)
            ctx.strokePath()
        }
    }

    static func drawHorizontalConicalSpring(
        in ctx: CGContext,
        startX: CGFloat,
        endX: CGFloat,
        centerY: CGFloat,
        startR: CGFloat,
        endR: CGFloat,
        turns: Int
    ) {
        ctx.setLineCap(.round)
        for i in 0..<turns {
            let t = CGFloat(i) / CGFloat(max(1, turns - 1))
            let x = startX + (endX - startX) * t
            let r = startR + (endR - startR) * t
            let coil = CGRect(x: x - 1.5, y: centerY - r, width: 3.0, height: r * 2)
            ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.55)
            ctx.setLineWidth(2.4)
            ctx.strokeEllipse(in: coil.offsetBy(dx: 0.6, dy: 0.8))
            ctx.setStrokeColor(red: 0.62, green: 0.65, blue: 0.68, alpha: 0.95)
            ctx.setLineWidth(1.55)
            ctx.strokeEllipse(in: coil)
            ctx.setStrokeColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 0.82)
            ctx.setLineWidth(0.7)
            ctx.move(to: CGPoint(x: x, y: centerY - r + 1.0))
            ctx.addLine(to: CGPoint(x: x + 0.5, y: centerY - r * 0.15))
            ctx.strokePath()
        }
    }

    static func drawVerticalCoilSpring(
        in ctx: CGContext,
        centerX: CGFloat,
        startY: CGFloat,
        endY: CGFloat,
        radiusX: CGFloat,
        turns: Int
    ) {
        let step = (endY - startY) / CGFloat(max(1, turns))
        ctx.setFillColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 0.85)
        ctx.fill(CGRect(x: centerX - 1.2, y: startY, width: 2.4, height: endY - startY))

        for i in 0..<turns {
            let y = startY + CGFloat(i) * step + step * 0.5
            let band = CGRect(x: centerX - radiusX, y: y - 1.15, width: radiusX * 2, height: 2.3)
            let p = CGPath(roundedRect: band, cornerWidth: 1.15, cornerHeight: 1.15, transform: nil)
            ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 0.62)
            ctx.fill(CGRect(x: band.minX, y: band.maxY - 0.3, width: band.width, height: 1.1))
            ctx.saveGState()
            ctx.addPath(p)
            ctx.clip()
            drawLinearGradient(
                in: ctx,
                stops: [(0, 0.34, 0.36, 0.38, 1), (0.36, 0.92, 0.94, 0.96, 1), (0.72, 0.58, 0.60, 0.62, 1), (1, 0.28, 0.30, 0.32, 1)],
                start: CGPoint(x: band.minX, y: band.midY),
                end: CGPoint(x: band.maxX, y: band.midY)
            )
            ctx.restoreGState()
        }
    }

    static func drawICChip(in ctx: CGContext, rect: CGRect, vertical: Bool) {
        ctx.setFillColor(red: 0.78, green: 0.80, blue: 0.82, alpha: 0.92)
        if vertical {
            for pin in 0..<5 {
                let py = rect.minY + 1.8 + CGFloat(pin) * ((rect.height - 4.4) / 4.0)
                ctx.fill(CGRect(x: rect.minX - 1.5, y: py, width: rect.width + 3.0, height: 1.1))
            }
        } else {
            for pin in 0..<5 {
                let px = rect.minX + 1.8 + CGFloat(pin) * ((rect.width - 4.4) / 4.0)
                ctx.fill(CGRect(x: px, y: rect.minY - 1.5, width: 1.1, height: rect.height + 3.0))
            }
        }

        let p = CGPath(roundedRect: rect, cornerWidth: 1.2, cornerHeight: 1.2, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.4, height: 1.1), blur: 1.6, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.72))
        ctx.setFillColor(red: 0.085, green: 0.090, blue: 0.098, alpha: 1.0)
        ctx.addPath(p)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.14)
        ctx.setLineWidth(0.5)
        ctx.addPath(p)
        ctx.strokePath()
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.24)
        ctx.fillEllipse(in: CGRect(x: rect.minX + 1.8, y: rect.minY + 1.8, width: 1.8, height: 1.8))
    }

    static func drawElectrolyticCap(in ctx: CGContext, center: CGPoint, radius: CGFloat) {
        let outer = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.6, height: 1.5), blur: 2.2, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.75))
        ctx.setFillColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1.0)
        ctx.fillEllipse(in: outer)
        ctx.restoreGState()

        let top = outer.insetBy(dx: 0.9, dy: 0.9)
        ctx.saveGState()
        ctx.addEllipse(in: top)
        ctx.clip()
        drawLinearGradient(
            in: ctx,
            stops: [(0, 0.84, 0.86, 0.89, 1), (0.5, 0.56, 0.59, 0.63, 1), (1, 0.34, 0.37, 0.41, 1)],
            start: CGPoint(x: top.minX, y: top.minY),
            end: CGPoint(x: top.maxX, y: top.maxY)
        )
        ctx.restoreGState()

        ctx.setStrokeColor(red: 0.16, green: 0.18, blue: 0.20, alpha: 0.85)
        ctx.setLineWidth(0.75)
        let arm = radius * 0.54
        ctx.move(to: CGPoint(x: center.x - arm, y: center.y))
        ctx.addLine(to: CGPoint(x: center.x + arm, y: center.y))
        ctx.move(to: CGPoint(x: center.x, y: center.y - arm))
        ctx.addLine(to: CGPoint(x: center.x, y: center.y + arm))
        ctx.strokePath()
    }

    static func drawAxialResistor(in ctx: CGContext, center: CGPoint, length: CGFloat, thickness: CGFloat, vertical: Bool) {
        let rect = vertical
            ? CGRect(x: center.x - thickness / 2, y: center.y - length / 2, width: thickness, height: length)
            : CGRect(x: center.x - length / 2, y: center.y - thickness / 2, width: length, height: thickness)

        if vertical {
            drawSolderDome(in: ctx, center: CGPoint(x: center.x, y: rect.minY - 1.6), radius: 1.4)
            drawSolderDome(in: ctx, center: CGPoint(x: center.x, y: rect.maxY + 1.6), radius: 1.4)
        } else {
            drawSolderDome(in: ctx, center: CGPoint(x: rect.minX - 1.6, y: center.y), radius: 1.4)
            drawSolderDome(in: ctx, center: CGPoint(x: rect.maxX + 1.6, y: center.y), radius: 1.4)
        }

        let p = CGPath(roundedRect: rect, cornerWidth: thickness * 0.42, cornerHeight: thickness * 0.42, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.4, height: 1.0), blur: 1.5, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.65))
        ctx.setFillColor(red: 0.78, green: 0.68, blue: 0.50, alpha: 1.0)
        ctx.addPath(p)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(p)
        ctx.clip()
        drawLinearGradient(
            in: ctx,
            stops: [(0, 0.90, 0.82, 0.66, 1), (0.4, 0.78, 0.67, 0.49, 1), (1, 0.48, 0.40, 0.28, 1)],
            start: vertical ? CGPoint(x: rect.minX, y: rect.midY) : CGPoint(x: rect.midX, y: rect.minY),
            end: vertical ? CGPoint(x: rect.maxX, y: rect.midY) : CGPoint(x: rect.midX, y: rect.maxY)
        )
        let bands: [(CGFloat, CGFloat, CGFloat)] = [(0.74, 0.18, 0.15), (0.14, 0.14, 0.16), (0.82, 0.56, 0.14)]
        for (i, rgb) in bands.enumerated() {
            ctx.setFillColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 0.92)
            if vertical {
                ctx.fill(CGRect(x: rect.minX, y: rect.minY + 2.0 + CGFloat(i) * 2.8, width: rect.width, height: 1.25))
            } else {
                ctx.fill(CGRect(x: rect.minX + 2.0 + CGFloat(i) * 2.8, y: rect.minY, width: 1.25, height: rect.height))
            }
        }
        ctx.restoreGState()
    }

    static func drawInsulatedWire(in ctx: CGContext, path: CGPath, width: CGFloat, red: Bool) {
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setShadow(offset: CGSize(width: 0.6, height: 1.4), blur: 2.0, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.7))
        ctx.setStrokeColor(red: red ? 0.64 : 0.04, green: red ? 0.12 : 0.04, blue: red ? 0.10 : 0.05, alpha: 1.0)
        ctx.setLineWidth(width)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(red: red ? 0.94 : 0.28, green: red ? 0.28 : 0.30, blue: red ? 0.24 : 0.33, alpha: 0.92)
        ctx.setLineWidth(width * 0.52)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: red ? 0.35 : 0.18)
        ctx.setLineWidth(width * 0.20)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }

    static func drawMetallicBlock(in ctx: CGContext, rect: CGRect, radius: CGFloat, brass: Bool) {
        let p = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.5, height: 1.2), blur: 1.8, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.65))
        ctx.setFillColor(red: brass ? 0.72 : 0.56, green: brass ? 0.58 : 0.58, blue: brass ? 0.28 : 0.60, alpha: 1.0)
        ctx.addPath(p)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(p)
        ctx.clip()
        drawLinearGradient(
            in: ctx,
            stops: brass
                ? [(0, 0.92, 0.80, 0.46, 1), (0.48, 0.72, 0.58, 0.26, 1), (1, 0.48, 0.38, 0.16, 1)]
                : [(0, 0.82, 0.84, 0.86, 1), (0.45, 0.54, 0.56, 0.58, 1), (1, 0.30, 0.32, 0.34, 1)],
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.minX, y: rect.maxY)
        )
        ctx.restoreGState()
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.22)
        ctx.setLineWidth(0.5)
        ctx.addPath(p)
        ctx.strokePath()
    }

    static func drawGoldVia(in ctx: CGContext, center: CGPoint) {
        ctx.setFillColor(red: 0.82, green: 0.68, blue: 0.34, alpha: 0.92)
        ctx.fillEllipse(in: CGRect(x: center.x - 1.25, y: center.y - 1.25, width: 2.5, height: 2.5))
        ctx.setFillColor(red: 0.05, green: 0.06, blue: 0.05, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: center.x - 0.55, y: center.y - 0.55, width: 1.1, height: 1.1))
    }

    static func drawSolderDome(in ctx: CGContext, center: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.saveGState()
        ctx.addEllipse(in: rect)
        ctx.clip()
        drawLinearGradient(
            in: ctx,
            stops: [(0, 0.96, 0.97, 0.98, 1), (0.55, 0.64, 0.66, 0.69, 1), (1, 0.36, 0.38, 0.40, 1)],
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        ctx.restoreGState()
    }

    static func drawStandoffBoss(in ctx: CGContext, center: CGPoint, radius: CGFloat) {
        let r = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.setFillColor(red: 0.07, green: 0.075, blue: 0.08, alpha: 0.85)
        ctx.fillEllipse(in: r)
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        ctx.setLineWidth(0.7)
        ctx.strokeEllipse(in: r)
    }

    static func drawPhillipsScrew(in ctx: CGContext, center: CGPoint, radius: CGFloat, brass: Bool) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.3, height: 0.9), blur: 1.2, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.72))
        ctx.addEllipse(in: rect)
        ctx.clip()
        drawLinearGradient(
            in: ctx,
            stops: brass
                ? [(0, 0.94, 0.84, 0.52, 1), (0.55, 0.70, 0.56, 0.26, 1), (1, 0.46, 0.36, 0.16, 1)]
                : [(0, 0.90, 0.92, 0.94, 1), (0.55, 0.58, 0.60, 0.62, 1), (1, 0.34, 0.36, 0.38, 1)],
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        ctx.restoreGState()

        ctx.setStrokeColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 0.88)
        ctx.setLineWidth(0.75)
        ctx.setLineCap(.round)
        let arm = radius * 0.52
        ctx.move(to: CGPoint(x: center.x - arm, y: center.y))
        ctx.addLine(to: CGPoint(x: center.x + arm, y: center.y))
        ctx.move(to: CGPoint(x: center.x, y: center.y - arm))
        ctx.addLine(to: CGPoint(x: center.x, y: center.y + arm))
        ctx.strokePath()
    }

    static func drawLinearGradient(
        in ctx: CGContext,
        stops: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)],
        start: CGPoint,
        end: CGPoint
    ) {
        let colors = stops.map { CGColor(colorSpace: cs, components: [$0.1, $0.2, $0.3, $0.4])! } as CFArray
        let locs = stops.map { $0.0 }
        if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: locs) {
            ctx.drawLinearGradient(grad, start: start, end: end, options: [])
        }
    }
}
