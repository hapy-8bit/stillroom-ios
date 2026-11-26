import CoreGraphics
import Metal

/// Bakes the deterministic 2× (786×1704) static internal sub-chassis for `.seeThrough`
/// (`body.seeThrough.internals.v3`): brushed aluminum internal structural frame,
/// Dynamic-Island-aware frosted AA battery bay + power PCB, central gearbox recess +
/// magnetic tape-head/pinch-roller bridge, vibrant emerald PCBs with silkscreen & gold
/// vias, stainless transport key linkages & coil springs, taut neoprene drive belt,
/// brushed chrome DC micro-motor, and molded translucent polycarbonate gusset ribs.
/// Live rotating brass/steel gears, flywheel, and pulley are composited at 60fps by
/// `seeThroughFragment` right over this baked foundation.
@MainActor
enum OneTapeSeeThroughBaker {
    private typealias P = OneTapeSeeThroughPrimitives

    static func internalsTexture() -> MTLTexture? {
        OneTapeBodyMetalEngine.shared.cachedTexture(key: "body.seeThrough.internals.v3") { ctx, rect in
            drawBrushedAluminumSubChassis(in: ctx, rect: rect)
            drawTopBatteryAndPowerStage(in: ctx)
            drawCentralBridgeGearBayAndTapeHead(in: ctx)
            drawRightPCBAssembly(in: ctx)
            drawLeftAudioHardware(in: ctx)
            drawPrecisionKeyLinkages(in: ctx)
            drawBottomMotorBayAndAmp(in: ctx)
            drawTranslucentPlasticRibs(in: ctx)
        }
    }

    // MARK: - 1. High-Contrast Brushed Aluminum Sub-Frame over Deep Chassis Floor

    private static func drawBrushedAluminumSubChassis(in ctx: CGContext, rect: CGRect) {
        // Deep shadowed inner floor behind structural aluminum cutouts.
        P.drawLinearGradient(
            in: ctx,
            stops: [
                (0.0, 0.105, 0.112, 0.120, 1),
                (0.5, 0.080, 0.086, 0.094, 1),
                (1.0, 0.095, 0.102, 0.110, 1)
            ],
            start: CGPoint(x: 30, y: 0),
            end: CGPoint(x: 363, y: rect.height)
        )

        // Satin anodized silver-gunmetal internal aluminum structural deck plates so
        // bright metallic structure contrasts sharply against dark cavities & smoked glass.
        let framePlates: [CGRect] = [
            CGRect(x: 8, y: 6, width: 377, height: 62),
            CGRect(x: 6, y: 621, width: 381, height: 32),
            CGRect(x: 6, y: 650, width: 96, height: 196),
            CGRect(x: 96, y: 816, width: 290, height: 32)
        ]
        for plate in framePlates {
            let p = CGPath(roundedRect: plate, cornerWidth: 8, cornerHeight: 8, transform: nil)
            ctx.saveGState()
            ctx.addPath(p)
            ctx.clip()
            P.drawLinearGradient(
                in: ctx,
                stops: [
                    (0.0, 0.31, 0.33, 0.355, 1),
                    (0.5, 0.24, 0.255, 0.275, 1),
                    (1.0, 0.28, 0.295, 0.315, 1)
                ],
                start: CGPoint(x: plate.minX, y: plate.minY),
                end: CGPoint(x: plate.maxX, y: plate.maxY)
            )
            // Fine machined horizontal aluminum milling grain.
            ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.032)
            ctx.setLineWidth(0.5)
            for y in stride(from: plate.minY, through: plate.maxY, by: 2.2) {
                ctx.move(to: CGPoint(x: plate.minX, y: y))
                ctx.addLine(to: CGPoint(x: plate.maxX, y: y))
            }
            ctx.strokePath()
            ctx.restoreGState()

            ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.10)
            ctx.setLineWidth(0.6)
            ctx.addPath(p)
            ctx.strokePath()
        }

        // Precision machined corner screw bosses & gleaming Phillips fasteners.
        let screws: [(CGPoint, Bool)] = [
            (CGPoint(x: 374, y: 20), false),
            (CGPoint(x: 16, y: 636), false),
            (CGPoint(x: 378, y: 636), false),
            (CGPoint(x: 378, y: 834), false),
            (CGPoint(x: 84, y: 838), true)
        ]
        for (pt, brass) in screws {
            P.drawStandoffBoss(in: ctx, center: pt, radius: 5.8)
            P.drawPhillipsScrew(in: ctx, center: pt, radius: 3.3, brass: brass)
        }
    }

    // MARK: - 2. Top Bezel: Dynamic-Island-Aware Frosted AA Battery Bay & Power PCB

    private static func drawTopBatteryAndPowerStage(in ctx: CGContext) {
        // Molded dark battery cradle positioned so twin cells & terminals shine cleanly on
        // the left, right, and lower rim around the iPhone Dynamic Island (x: 134..259, y: 11..48).
        let bay = CGRect(x: 78, y: 18, width: 244, height: 43)
        let bayPath = CGPath(roundedRect: bay, cornerWidth: 6.5, cornerHeight: 6.5, transform: nil)
        ctx.saveGState()
        ctx.addPath(bayPath)
        ctx.clip()
        P.drawLinearGradient(
            in: ctx,
            stops: [(0, 0.055, 0.06, 0.068, 1), (0.5, 0.09, 0.096, 0.105, 1), (1, 0.06, 0.065, 0.072, 1)],
            start: CGPoint(x: bay.minX, y: bay.minY),
            end: CGPoint(x: bay.minX, y: bay.maxY)
        )
        ctx.restoreGState()
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.14)
        ctx.setLineWidth(0.75)
        ctx.addPath(bayPath)
        ctx.strokePath()

        // Left stainless contact plate & bright conical negative compression spring (fully visible at x: 80..102).
        P.drawMetallicBlock(in: ctx, rect: CGRect(x: 80.5, y: 24.5, width: 4.5, height: 30.0), radius: 1.0, brass: false)
        P.drawHorizontalConicalSpring(in: ctx, startX: 85.0, endX: 100.5, centerY: 39.5, startR: 11.5, endR: 7.0, turns: 5)

        // Bright frosted milky-sage AA battery cells peeking visibly left, below, and right of Dynamic Island.
        drawFrostedAACell(in: ctx, rect: CGRect(x: 100.5, y: 22.0, width: 101.0, height: 35.0), capOnRight: true)
        P.drawMetallicBlock(in: ctx, rect: CGRect(x: 203.0, y: 24.5, width: 5.5, height: 30.0), radius: 1.2, brass: false)
        drawFrostedAACell(in: ctx, rect: CGRect(x: 210.0, y: 22.0, width: 101.0, height: 35.0), capOnRight: true)

        // Brass positive spring terminal at x: 312..320 (fully unobstructed right of Dynamic Island!).
        P.drawMetallicBlock(in: ctx, rect: CGRect(x: 312.5, y: 30.5, width: 7.5, height: 18.0), radius: 1.4, brass: true)
        P.drawSolderDome(in: ctx, center: CGPoint(x: 318.0, y: 39.5), radius: 2.2)

        // Compact emerald-green top-right power regulator PCB (x: 325..370, y: 20..61 — completely unobstructed!).
        let pwrPCB = CGRect(x: 325, y: 21, width: 45, height: 39)
        drawGreenPCBBase(in: ctx, rect: pwrPCB, corner: 3.0)
        P.drawElectrolyticCap(in: ctx, center: CGPoint(x: 338, y: 34), radius: 6.0)
        P.drawAxialResistor(in: ctx, center: CGPoint(x: 356, y: 32), length: 11.0, thickness: 4.4, vertical: true)
        P.drawICChip(in: ctx, rect: CGRect(x: 332, y: 45, width: 15, height: 11), vertical: false)
        P.drawGoldVia(in: ctx, center: CGPoint(x: 354, y: 52))
        // Subtle warm-amber/green power status SMD diode dot on top-right PCB.
        ctx.setFillColor(red: 0.96, green: 0.62, blue: 0.18, alpha: 0.92)
        ctx.fillEllipse(in: CGRect(x: 360.5, y: 49.5, width: 4.0, height: 4.0))

        // Glossy red positive wire & black ground wire running from battery bay -> power PCB -> right bezel.
        let redPath = CGMutablePath()
        redPath.move(to: CGPoint(x: 319, y: 39.5))
        redPath.addLine(to: CGPoint(x: 366, y: 39.5))
        redPath.addQuadCurve(to: CGPoint(x: 375.8, y: 52), control: CGPoint(x: 375.8, y: 39.5))
        redPath.addLine(to: CGPoint(x: 375.8, y: 812))
        P.drawInsulatedWire(in: ctx, path: redPath, width: 2.5, red: true)

        let blkPath = CGMutablePath()
        blkPath.move(to: CGPoint(x: 379.0, y: 54))
        blkPath.addLine(to: CGPoint(x: 379.0, y: 806))
        P.drawInsulatedWire(in: ctx, path: blkPath, width: 1.9, red: false)
    }

    private static func drawFrostedAACell(in ctx: CGContext, rect: CGRect, capOnRight: Bool) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 2.4), blur: 3.5, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.72))
        let body = CGPath(roundedRect: rect, cornerWidth: 3.6, cornerHeight: 3.6, transform: nil)
        ctx.setFillColor(red: 0.76, green: 0.82, blue: 0.79, alpha: 1.0)
        ctx.addPath(body)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()
        P.drawLinearGradient(
            in: ctx,
            stops: [
                (0.00, 0.70, 0.77, 0.74, 1),
                (0.18, 0.94, 0.97, 0.95, 1),
                (0.36, 0.84, 0.89, 0.86, 1),
                (0.74, 0.58, 0.64, 0.61, 1),
                (0.92, 0.46, 0.51, 0.49, 1),
                (1.00, 0.66, 0.72, 0.69, 1)
            ],
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.minX, y: rect.maxY)
        )
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.42)
        ctx.fill(CGRect(x: rect.minX + 3, y: rect.minY + 4.2, width: rect.width - 6, height: 3.6))

        for endX in [rect.minX, rect.maxX - 4.5] {
            let capRect = CGRect(x: endX, y: rect.minY, width: 4.5, height: rect.height)
            ctx.saveGState()
            ctx.clip(to: capRect)
            P.drawLinearGradient(
                in: ctx,
                stops: [(0, 0.46, 0.48, 0.50, 1), (0.3, 0.88, 0.90, 0.92, 1), (0.85, 0.34, 0.36, 0.38, 1)],
                start: CGPoint(x: capRect.minX, y: capRect.minY),
                end: CGPoint(x: capRect.minX, y: capRect.maxY)
            )
            ctx.restoreGState()
        }
        ctx.restoreGState()

        ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.32)
        ctx.setLineWidth(0.65)
        ctx.addPath(body)
        ctx.strokePath()

        if capOnRight {
            P.drawMetallicBlock(in: ctx, rect: CGRect(x: rect.maxX - 0.5, y: rect.midY - 6.0, width: 2.8, height: 12.0),
                                radius: 1.0, brass: false)
        }
    }

    // MARK: - 3. Central Mechanical Bridge (Gearbox Sump + Magnetic Tape Head + Logic PCB)

    private static func drawCentralBridgeGearBayAndTapeHead(in ctx: CGContext) {
        // Deep shadowed milled gearbox recess (x: 94..204, y: 622..652) so the 4 LIVE GPU
        // brass & stainless gears pop with watchmaking 3D contrast.
        let gearBay = CGRect(x: 94, y: 622, width: 110, height: 30)
        let bayPath = CGPath(roundedRect: gearBay, cornerWidth: 4.5, cornerHeight: 4.5, transform: nil)
        ctx.setFillColor(red: 0.055, green: 0.060, blue: 0.068, alpha: 0.95)
        ctx.addPath(bayPath)
        ctx.fillPath()
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.14)
        ctx.setLineWidth(0.75)
        ctx.addPath(bayPath)
        ctx.strokePath()

        // Machined horizontal steel bridge bar behind the gears with brass bearing collars.
        P.drawMetallicBlock(in: ctx, rect: CGRect(x: 98, y: 634.5, width: 102, height: 4.5), radius: 1.2, brass: false)

        // Precision magnetic tape-head & rubber pinch-roller carriage (x: 212..298, y: 624..649).
        let headPlate = CGRect(x: 212, y: 625, width: 86, height: 23.5)
        P.drawMetallicBlock(in: ctx, rect: headPlate, radius: 3.0, brass: false)

        // Recessed magnetic stereo read-head block with gleaming twin copper pickup coils.
        let headCore = CGRect(x: 230, y: 627.5, width: 32, height: 18.5)
        ctx.setFillColor(red: 0.12, green: 0.13, blue: 0.145, alpha: 1.0)
        ctx.fill(headCore)
        for cx in [CGFloat(233.5), 247.5] {
            let coil = CGRect(x: cx, y: 630.0, width: 11.0, height: 13.5)
            ctx.saveGState()
            ctx.clip(to: coil)
            P.drawLinearGradient(
                in: ctx,
                stops: [(0, 0.44, 0.20, 0.08, 1), (0.45, 0.88, 0.48, 0.22, 1), (1, 0.34, 0.15, 0.06, 1)],
                start: CGPoint(x: coil.minX, y: coil.minY),
                end: CGPoint(x: coil.minX, y: coil.maxY)
            )
            ctx.setStrokeColor(red: 0.98, green: 0.68, blue: 0.34, alpha: 0.46)
            ctx.setLineWidth(0.55)
            for wx in stride(from: coil.minX + 1.2, through: coil.maxX - 1.0, by: 1.5) {
                ctx.move(to: CGPoint(x: wx, y: coil.minY))
                ctx.addLine(to: CGPoint(x: wx, y: coil.maxY))
            }
            ctx.strokePath()
            ctx.restoreGState()
        }
        // Polished chrome tape guide post & black rubber pinch roller right next to the read head.
        let roller = CGRect(x: 270, y: 628.5, width: 16.5, height: 16.5)
        ctx.setFillColor(red: 0.07, green: 0.075, blue: 0.08, alpha: 1.0)
        ctx.fillEllipse(in: roller)
        ctx.setStrokeColor(red: 0.80, green: 0.82, blue: 0.84, alpha: 0.85)
        ctx.setLineWidth(1.0)
        ctx.strokeEllipse(in: roller.insetBy(dx: 3.8, dy: 3.8))
        P.drawPhillipsScrew(in: ctx, center: CGPoint(x: 220, y: 636.8), radius: 2.8, brass: true)

        // Emerald logic bridge PCB header on the right (x: 304..370, y: 625..649) with gold FPC pins.
        let bridgePCB = CGRect(x: 304, y: 625.5, width: 65, height: 22.5)
        drawGreenPCBBase(in: ctx, rect: bridgePCB, corner: 2.5)
        // Gold ribbon-cable connector pins (FPC header).
        for pin in 0..<8 {
            let px = 310.0 + CGFloat(pin) * 3.8
            P.drawMetallicBlock(in: ctx, rect: CGRect(x: px, y: 629.0, width: 2.1, height: 7.5), radius: 0.4, brass: true)
        }
        P.drawICChip(in: ctx, rect: CGRect(x: 344, y: 629.5, width: 14, height: 14), vertical: false)
        P.drawGoldVia(in: ctx, center: CGPoint(x: 312, y: 643))
        P.drawGoldVia(in: ctx, center: CGPoint(x: 324, y: 643))
        P.drawGoldVia(in: ctx, center: CGPoint(x: 336, y: 643))
    }

    // MARK: - 4. Right Bezel Etched Forest-Green PCB Strip

    private static func drawRightPCBAssembly(in ctx: CGContext) {
        let pcb = CGRect(x: 379.2, y: 72, width: 12.2, height: 742)
        drawGreenPCBBase(in: ctx, rect: pcb, corner: 2.2)

        for y in stride(from: CGFloat(106), through: 766, by: 76) {
            P.drawMetallicBlock(in: ctx, rect: CGRect(x: 373.0, y: y, width: 6.4, height: 2.3), radius: 0.8, brass: true)
        }

        let ySlots: [CGFloat] = [108, 152, 202, 256, 314, 376, 438, 502, 566, 668, 720, 772]
        for (i, y) in ySlots.enumerated() {
            P.drawGoldVia(in: ctx, center: CGPoint(x: 382.5, y: y - 10))
            P.drawGoldVia(in: ctx, center: CGPoint(x: 388.2, y: y - 5))
            switch i % 3 {
            case 0:
                P.drawICChip(in: ctx, rect: CGRect(x: 381.4, y: y, width: 8.2, height: 17.5), vertical: true)
            case 1:
                P.drawAxialResistor(in: ctx, center: CGPoint(x: 385.5, y: y + 6.5), length: 11.5, thickness: 4.8, vertical: true)
            default:
                P.drawElectrolyticCap(in: ctx, center: CGPoint(x: 385.5, y: y + 5.0), radius: 4.5)
            }
        }
    }

    // MARK: - 5. Left Bezel Precision Side Hardware

    private static func drawLeftAudioHardware(in ctx: CGContext) {
        let switchHousing = CGRect(x: 1.5, y: 236, width: 14.5, height: 52)
        P.drawMetallicBlock(in: ctx, rect: switchHousing, radius: 2.5, brass: false)
        ctx.setFillColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1.0)
        ctx.fill(CGRect(x: 4.5, y: 249, width: 8.5, height: 26))
        P.drawMetallicBlock(in: ctx, rect: CGRect(x: 5.5, y: 254, width: 6.5, height: 11.5), radius: 1.2, brass: false)
        P.drawPhillipsScrew(in: ctx, center: CGPoint(x: 8.8, y: 242.5), radius: 2.4, brass: false)
        P.drawPhillipsScrew(in: ctx, center: CGPoint(x: 8.8, y: 281.5), radius: 2.4, brass: false)

        // Knurled chrome volume thumb-wheel peeking out along the left interior wall.
        let wheel = CGRect(x: 2.0, y: 332, width: 14.5, height: 32)
        P.drawMetallicBlock(in: ctx, rect: wheel, radius: 2.0, brass: false)
        ctx.setStrokeColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 0.55)
        ctx.setLineWidth(1.0)
        for wy in stride(from: wheel.minY + 3, through: wheel.maxY - 3, by: 3.2) {
            ctx.move(to: CGPoint(x: wheel.minX + 1, y: wy))
            ctx.addLine(to: CGPoint(x: wheel.maxX - 1, y: wy))
        }
        ctx.strokePath()
    }

    // MARK: - 6. Lower-Left Transport Key Switch Chamber

    private static func drawPrecisionKeyLinkages(in ctx: CGContext) {
        // High-contrast emerald tactile switch PCB tucked right beside the 3 translucent keys.
        let rail = CGRect(x: 78.5, y: 646, width: 17.0, height: 184)
        drawGreenPCBBase(in: ctx, rect: rail, corner: 2.5)

        let bus = CGMutablePath()
        bus.move(to: CGPoint(x: 75.8, y: 648))
        bus.addLine(to: CGPoint(x: 75.8, y: 824))
        bus.addQuadCurve(to: CGPoint(x: 94.0, y: 836), control: CGPoint(x: 75.8, y: 836))
        P.drawInsulatedWire(in: ctx, path: bus, width: 2.1, red: true)

        for (idx, y) in OneTapeTransportGeometry.centersY.enumerated() {
            let bracket = CGRect(x: 68.0, y: y - 5.2, width: 24.0, height: 10.4)
            P.drawMetallicBlock(in: ctx, rect: bracket, radius: 3.2, brass: false)

            ctx.setFillColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 0.85)
            ctx.fill(CGRect(x: 70.5, y: y - 1.2, width: 11.5, height: 2.4))
            P.drawPhillipsScrew(in: ctx, center: CGPoint(x: 86.8, y: y), radius: 3.0, brass: false)

            P.drawMetallicBlock(in: ctx, rect: CGRect(x: 82.0, y: y + 25.5, width: 11.0, height: 3.2), radius: 0.8, brass: true)
            P.drawSolderDome(in: ctx, center: CGPoint(x: 77.2, y: y + 27.0), radius: 1.9)
            P.drawGoldVia(in: ctx, center: CGPoint(x: 92.2, y: y - 12))

            if idx < 2 || y < 810 {
                P.drawVerticalCoilSpring(in: ctx, centerX: 87.5, startY: y + 6.5, endY: y + 24.5, radiusX: 4.0, turns: 6)
            }
        }
    }

    // MARK: - 7. Bottom Drive Sump (Belt behind Live GPU Flywheel/Pulley + Brushed Motor + Amp PCB)

    private static func drawBottomMotorBayAndAmp(in ctx: CGContext) {
        let sump = CGRect(x: 98, y: 817.5, width: 274, height: 32.5)
        let sumpPath = CGPath(roundedRect: sump, cornerWidth: 4.5, cornerHeight: 4.5, transform: nil)
        ctx.setFillColor(red: 0.050, green: 0.054, blue: 0.062, alpha: 0.94)
        ctx.addPath(sumpPath)
        ctx.fillPath()
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.10)
        ctx.setLineWidth(0.75)
        ctx.addPath(sumpPath)
        ctx.strokePath()

        // Taut neoprene rubber drive belt connecting the GPU-rendered 20.5pt flywheel (134, 838.5)
        // and the GPU-rendered 8.4pt brass pulley (212, 835.0).
        P.drawDriveBelt(in: ctx, from: CGPoint(x: 134.0, y: 838.5), r1: 19.6,
                        to: CGPoint(x: 212.0, y: 835.0), r2: 7.8)

        // Turned brushed-steel motor shaft connecting pulley to motor barrel.
        ctx.setFillColor(red: 0.78, green: 0.80, blue: 0.82, alpha: 1.0)
        ctx.fill(CGRect(x: 217.5, y: 833.2, width: 6.5, height: 3.6))

        // Full-scale brushed stainless DC micro-motor with copper stator coil windows.
        P.drawDCMicroMotor(in: ctx, rect: CGRect(x: 222.5, y: 820.5, width: 64.0, height: 26.5))

        let motorRed = CGMutablePath()
        motorRed.move(to: CGPoint(x: 286.5, y: 829.0))
        motorRed.addLine(to: CGPoint(x: 298.0, y: 829.0))
        P.drawInsulatedWire(in: ctx, path: motorRed, width: 1.9, red: true)

        let motorBlk = CGMutablePath()
        motorBlk.move(to: CGPoint(x: 286.5, y: 838.5))
        motorBlk.addLine(to: CGPoint(x: 298.0, y: 838.5))
        P.drawInsulatedWire(in: ctx, path: motorBlk, width: 1.7, red: false)

        // Bottom-right vibrant emerald audio amplifier sub-PCB.
        let ampRect = CGRect(x: 296.0, y: 820.5, width: 73.5, height: 26.5)
        drawGreenPCBBase(in: ctx, rect: ampRect, corner: 2.8)
        P.drawGoldVia(in: ctx, center: CGPoint(x: ampRect.minX + 5.0, y: ampRect.minY + 4.5))
        P.drawGoldVia(in: ctx, center: CGPoint(x: ampRect.maxX - 5.0, y: ampRect.maxY - 4.5))
        P.drawAxialResistor(in: ctx, center: CGPoint(x: ampRect.minX + 12.5, y: ampRect.minY + 8.0), length: 11.0, thickness: 4.4, vertical: false)
        P.drawAxialResistor(in: ctx, center: CGPoint(x: ampRect.minX + 12.5, y: ampRect.maxY - 7.5), length: 11.0, thickness: 4.4, vertical: false)
        P.drawICChip(in: ctx, rect: CGRect(x: ampRect.minX + 26.5, y: ampRect.minY + 5.5, width: 15.5, height: 15.5), vertical: false)
        P.drawElectrolyticCap(in: ctx, center: CGPoint(x: ampRect.minX + 56.5, y: ampRect.midY), radius: 6.5)
    }

    // MARK: - 8. Translucent Molded Polycarbonate Internal Gusset Ribs

    private static func drawTranslucentPlasticRibs(in ctx: CGContext) {
        // Subtle milky-silver translucent ribs molded into the underside of the clear cover.
        let ribs: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 20, y: 632), CGPoint(x: 86, y: 632)),
            (CGPoint(x: 20, y: 642), CGPoint(x: 86, y: 642)),
            (CGPoint(x: 6, y: 699), CGPoint(x: 18, y: 699)),
            (CGPoint(x: 6, y: 767), CGPoint(x: 18, y: 767)),
            (CGPoint(x: 75, y: 66), CGPoint(x: 374, y: 66))
        ]
        ctx.setLineCap(.round)
        for (a, b) in ribs {
            ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0.40)
            ctx.setLineWidth(2.6)
            ctx.move(to: CGPoint(x: a.x, y: a.y + 1.2))
            ctx.addLine(to: CGPoint(x: b.x, y: b.y + 1.2))
            ctx.strokePath()

            ctx.setStrokeColor(red: 0.78, green: 0.84, blue: 0.88, alpha: 0.24)
            ctx.setLineWidth(1.4)
            ctx.move(to: a)
            ctx.addLine(to: b)
            ctx.strokePath()
        }
    }

    private static func drawGreenPCBBase(in ctx: CGContext, rect: CGRect, corner: CGFloat) {
        let p = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 2.5, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.7))
        ctx.setFillColor(red: 0.16, green: 0.34, blue: 0.19, alpha: 1.0)
        ctx.addPath(p)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(p)
        ctx.clip()
        P.drawLinearGradient(
            in: ctx,
            stops: [(0, 0.21, 0.42, 0.23, 1), (0.5, 0.155, 0.33, 0.18, 1), (1, 0.125, 0.26, 0.145, 1)],
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        ctx.setStrokeColor(red: 0.34, green: 0.60, blue: 0.34, alpha: 0.82)
        ctx.setLineWidth(0.8)
        if rect.height > rect.width * 2 {
            for dx in [rect.width * 0.28, rect.width * 0.56, rect.width * 0.80] {
                ctx.move(to: CGPoint(x: rect.minX + dx, y: rect.minY + 4))
                ctx.addLine(to: CGPoint(x: rect.minX + dx, y: rect.maxY - 4))
            }
        } else {
            for dy in [rect.height * 0.30, rect.height * 0.72] {
                ctx.move(to: CGPoint(x: rect.minX + 4, y: rect.minY + dy))
                ctx.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY + dy))
            }
        }
        ctx.strokePath()
        ctx.restoreGState()

        ctx.setStrokeColor(red: 0.46, green: 0.68, blue: 0.44, alpha: 0.62)
        ctx.setLineWidth(0.6)
        ctx.addPath(p)
        ctx.strokePath()
    }
}
