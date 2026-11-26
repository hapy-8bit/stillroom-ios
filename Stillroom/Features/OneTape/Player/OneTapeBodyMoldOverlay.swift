import SwiftUI

/// Unified 3D iPhone 393×852 hardware molding layer shared across body materials.
/// Supplies outer curved rim lighting, recessed cassette pocket and LCD bevels,
/// transport/mode key seats, and subtle ambient occlusion so every finish reads
/// as one physically molded chassis rather than a flat masked texture.
struct OneTapeBodyMoldOverlay: View {
    let isDarkShell: Bool
    var tilt: CGSize = OneTapeTiltMonitor.restingTilt
    var showsEdgeMicroSpec: Bool = true

    private let canvasRect = CGRect(x: 0, y: 0, width: 393, height: 852)
    private let pocketFrame = OneTapeCassettePocketMask.openingFrame
    private let lcdFrame = CGRect(x: 100.33, y: 651.12, width: 264.39, height: 165.63)

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 393, y: size.height / 852)
            drawOuterHousingBevel(in: &context)
            drawCassettePocketBevel(in: &context)
            drawLCDViewportBevel(in: &context)
            drawKeyWells(in: &context)
        }
        .frame(width: 393, height: 852)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawOuterHousingBevel(in context: inout GraphicsContext) {
        let lightX = 0.25 + Double(tilt.width) * 0.28
        let lightY = 0.12 + Double(tilt.height) * 0.20
        let start = CGPoint(x: 393 * lightX, y: 852 * lightY)
        let end = CGPoint(x: 393 * (1 - lightX), y: 852 * (1 - lightY))

        // Subtle curved shell falloff near the vertical perimeter (suggests real rounded housing depth).
        context.fill(
            Path(canvasRect),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .black.opacity(isDarkShell ? 0.24 : 0.11), location: 0.0),
                    .init(color: .clear, location: 0.055),
                    .init(color: .clear, location: 0.945),
                    .init(color: .black.opacity(isDarkShell ? 0.30 : 0.14), location: 1.0)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 393, y: 0)
            )
        )

        // Outer machined rim highlight + inner return groove.
        let outerRim = Path(roundedRect: canvasRect.insetBy(dx: 1.3, dy: 1.3), cornerRadius: 57.7)
        let innerChamfer = Path(roundedRect: canvasRect.insetBy(dx: 3.6, dy: 3.6), cornerRadius: 55.4)
        let highlightAlpha = isDarkShell ? 0.28 : 0.62
        let shadowAlpha = isDarkShell ? 0.58 : 0.26

        context.stroke(
            outerRim,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(showsEdgeMicroSpec ? highlightAlpha : highlightAlpha * 0.6), location: 0.0),
                    .init(color: .white.opacity(highlightAlpha * 0.18), location: 0.38),
                    .init(color: .black.opacity(shadowAlpha), location: 0.78),
                    .init(color: .white.opacity(highlightAlpha * 0.28), location: 1.0)
                ]),
                startPoint: start,
                endPoint: end
            ),
            lineWidth: 1.6
        )

        context.stroke(
            innerChamfer,
            with: .linearGradient(
                Gradient(colors: [
                    .black.opacity(isDarkShell ? 0.22 : 0.10),
                    .white.opacity(isDarkShell ? 0.08 : 0.28)
                ]),
                startPoint: CGPoint(x: 393, y: 0),
                endPoint: CGPoint(x: 0, y: 852)
            ),
            lineWidth: 0.7
        )
    }

    private func drawCassettePocketBevel(in context: inout GraphicsContext) {
        // Recessed stepped molding lip hugging the exact cassette opening.
        let outerStep = pocketFrame.insetBy(dx: -2.4, dy: -2.4)
        let innerLip = pocketFrame.insetBy(dx: -0.6, dy: -0.6)

        // Ambient occlusion drop shadow around the cassette bay.
        context.stroke(
            Path(roundedRect: outerStep, cornerRadius: 21.4),
            with: .linearGradient(
                Gradient(colors: [
                    .black.opacity(isDarkShell ? 0.56 : 0.28),
                    .black.opacity(isDarkShell ? 0.32 : 0.14),
                    .white.opacity(isDarkShell ? 0.16 : 0.52)
                ]),
                startPoint: CGPoint(x: outerStep.minX, y: outerStep.minY),
                endPoint: CGPoint(x: outerStep.maxX, y: outerStep.maxY)
            ),
            lineWidth: 2.2
        )

        // Crisp dark seat edge right where the body meets the pocket recess.
        context.stroke(
            Path(roundedRect: innerLip, cornerRadius: 19.6),
            with: .color(.black.opacity(isDarkShell ? 0.72 : 0.45)),
            lineWidth: 1.3
        )
    }

    private func drawLCDViewportBevel(in context: inout GraphicsContext) {
        let bezelOuter = lcdFrame.insetBy(dx: -4.2, dy: -4.2)
        let bezelInner = lcdFrame.insetBy(dx: -1.1, dy: -1.1)

        // Deep recessed bezel surround matching the molded LCD housing.
        context.stroke(
            Path(roundedRect: bezelOuter, cornerRadius: 6.4),
            with: .linearGradient(
                Gradient(colors: [
                    .black.opacity(isDarkShell ? 0.62 : 0.34),
                    .black.opacity(isDarkShell ? 0.34 : 0.16),
                    .white.opacity(isDarkShell ? 0.22 : 0.58)
                ]),
                startPoint: CGPoint(x: bezelOuter.minX, y: bezelOuter.minY),
                endPoint: CGPoint(x: bezelOuter.maxX, y: bezelOuter.maxY)
            ),
            lineWidth: 2.8
        )

        // Crisp dark inner aperture lip framing the LCD glass.
        context.stroke(
            Path(roundedRect: bezelInner, cornerRadius: 3.4),
            with: .color(.black.opacity(isDarkShell ? 0.80 : 0.56)),
            lineWidth: 2.1
        )
    }

    private func drawKeyWells(in context: inout GraphicsContext) {
        // Three circular transport button wells (Prev / Play / Next).
        for y in OneTapeTransportGeometry.centersY {
            drawCircularWell(
                in: &context,
                center: CGPoint(x: OneTapeTransportGeometry.centerX, y: y),
                diameter: OneTapeTransportGeometry.visualDiameter + 4.4
            )
        }
        // Top-left circular playback mode button well.
        drawCircularWell(
            in: &context,
            center: CGPoint(x: OneTapeTransportGeometry.centerX, y: 34),
            diameter: OneTapePlaybackModeKey.visualDiameter + 4.0
        )
    }

    private func drawCircularWell(in context: inout GraphicsContext, center: CGPoint, diameter: CGFloat) {
        let wellRect = CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        let path = Path(ellipseIn: wellRect)
        // Outer recessed seat bevel: top-left shadow, bottom-right catch light.
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    .black.opacity(isDarkShell ? 0.68 : 0.38),
                    .black.opacity(isDarkShell ? 0.24 : 0.10),
                    .white.opacity(isDarkShell ? 0.20 : 0.55)
                ]),
                startPoint: CGPoint(x: wellRect.minX, y: wellRect.minY),
                endPoint: CGPoint(x: wellRect.maxX, y: wellRect.maxY)
            ),
            lineWidth: 1.8
        )
        // Tight dark shadow crevice directly around the key cap rim.
        let crevice = Path(ellipseIn: wellRect.insetBy(dx: 1.4, dy: 1.4))
        context.stroke(crevice, with: .color(.black.opacity(0.62)), lineWidth: 1.4)
    }
}
