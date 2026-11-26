import SwiftUI
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Procedural horizontal retro cassette tailored for the Small, Medium, and
/// Large widgets. Geometry uses a canonical 112 × 75.6 unit grid (640:432).
struct OneTapeWidgetCassetteView: View {
    let snapshot: OneTapeWidgetSnapshot
    let artwork: UIImage?

    static let aspectRatio: CGFloat = 640.0 / 432.0

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let u = width / 112.0

            ZStack(alignment: .topLeading) {
                shellLayer(width: width, height: height, u: u)
                labelInkLayer(u: u)
                    .frame(width: 80 * u, height: 12 * u)
                    .position(x: 56 * u, y: 18.8 * u)
                hubLayer(diameter: 14.7 * u, angle: snapshot.hubAngleDegrees, u: u)
                    .position(x: 34.75 * u, y: 34.9 * u)
                hubLayer(diameter: 14.7 * u, angle: snapshot.hubAngleDegrees, u: u)
                    .position(x: 77.25 * u, y: 34.9 * u)
                lowerSpecsLayer(u: u)
                    .frame(width: 81 * u)
                    .position(x: 56 * u, y: 51.8 * u)
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func shellLayer(width: CGFloat, height: CGFloat, u: CGFloat) -> some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let shellCorner = 3.8 * u
            let shellPath = Path(roundedRect: rect, cornerRadius: shellCorner)

            // Matte off-white molded plastic housing.
            let shellGradient = Gradient(stops: [
                .init(color: Color(red: 0.925, green: 0.925, blue: 0.910), location: 0.0),
                .init(color: Color(red: 0.892, green: 0.892, blue: 0.876), location: 0.48),
                .init(color: Color(red: 0.840, green: 0.840, blue: 0.822), location: 1.0)
            ])
            context.fill(
                shellPath,
                with: .linearGradient(shellGradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
            )

            // Crisp top specular lip and perimeter mold bevel.
            let innerLipPath = Path(
                roundedRect: rect.insetBy(dx: 0.35 * u, dy: 0.35 * u),
                cornerRadius: max(0, shellCorner - 0.35 * u)
            )
            let outerBevelPath = Path(
                roundedRect: rect.insetBy(dx: 0.25 * u, dy: 0.25 * u),
                cornerRadius: max(0, shellCorner - 0.25 * u)
            )
            context.stroke(innerLipPath, with: .color(.white.opacity(0.62)), lineWidth: 0.65 * u)
            context.stroke(outerBevelPath, with: .color(.black.opacity(0.14)), lineWidth: 0.45 * u)

            // Subtle upper & mid cassette paper label recessed area.
            let outerLabelRect = CGRect(x: 8.5 * u, y: 8.2 * u, width: 95.0 * u, height: 47.6 * u)
            let outerLabelPath = Path(roundedRect: outerLabelRect, cornerRadius: 2.2 * u)
            context.fill(
                outerLabelPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.940, green: 0.938, blue: 0.924),
                        Color(red: 0.902, green: 0.900, blue: 0.884)
                    ]),
                    startPoint: CGPoint(x: 0, y: outerLabelRect.minY),
                    endPoint: CGPoint(x: 0, y: outerLabelRect.maxY)
                )
            )
            context.stroke(outerLabelPath, with: .color(.black.opacity(0.065)), lineWidth: 0.35 * u)

            // Brighter top title label band where cover + album ink sit.
            let titleBandRect = CGRect(x: 12.2 * u, y: 11.4 * u, width: 87.6 * u, height: 14.8 * u)
            let titleBandPath = Path(roundedRect: titleBandRect, cornerRadius: 1.4 * u)
            context.fill(
                titleBandPath,
                with: .color(Color(red: 0.962, green: 0.960, blue: 0.948))
            )
            context.stroke(titleBandPath, with: .color(.black.opacity(0.05)), lineWidth: 0.3 * u)

            // Center dark tape-transport window cutout between both reels.
            let windowRect = CGRect(x: 24.5 * u, y: 26.8 * u, width: 63.0 * u, height: 16.2 * u)
            let windowPath = Path(roundedRect: windowRect, cornerRadius: 8.1 * u)
            context.fill(windowPath, with: .color(Color(red: 0.815, green: 0.812, blue: 0.796)))
            context.stroke(windowPath, with: .color(.black.opacity(0.08)), lineWidth: 0.4 * u)

            // Central clear viewing slot showing magnetic tape packs winding.
            let slotRect = CGRect(x: 45.2 * u, y: 31.0 * u, width: 21.6 * u, height: 7.8 * u)
            let slotPath = Path(roundedRect: slotRect, cornerRadius: 1.4 * u)
            context.fill(slotPath, with: .color(Color(red: 0.675, green: 0.672, blue: 0.658)))

            let progress = snapshot.clampedProgress
            let leftPackRadius = (16.4 - 5.2 * progress) * u
            let rightPackRadius = (11.2 + 5.2 * progress) * u

            context.drawLayer { layer in
                layer.clip(to: slotPath)
                let leftCenter = CGPoint(x: 34.75 * u, y: 34.9 * u)
                let rightCenter = CGPoint(x: 77.25 * u, y: 34.9 * u)
                let leftCircle = Path(ellipseIn: CGRect(
                    x: leftCenter.x - leftPackRadius, y: leftCenter.y - leftPackRadius,
                    width: leftPackRadius * 2, height: leftPackRadius * 2
                ))
                let rightCircle = Path(ellipseIn: CGRect(
                    x: rightCenter.x - rightPackRadius, y: rightCenter.y - rightPackRadius,
                    width: rightPackRadius * 2, height: rightPackRadius * 2
                ))
                layer.fill(leftCircle, with: .color(Color(red: 0.23, green: 0.21, blue: 0.20)))
                layer.fill(rightCircle, with: .color(Color(red: 0.23, green: 0.21, blue: 0.20)))

                // Translucent acrylic reflection strip and subtle graduation marks.
                let sheenRect = CGRect(x: slotRect.minX, y: slotRect.minY, width: slotRect.width, height: slotRect.height * 0.45)
                layer.fill(Path(sheenRect), with: .color(.white.opacity(0.24)))
                for tick in 1...5 {
                    let tx = slotRect.minX + slotRect.width * CGFloat(tick) / 6.0
                    let tickRect = CGRect(x: tx - 0.18 * u, y: slotRect.minY + 1.4 * u, width: 0.36 * u, height: 1.6 * u)
                    layer.fill(Path(tickRect), with: .color(.white.opacity(0.45)))
                }
            }
            context.stroke(slotPath, with: .color(.black.opacity(0.18)), lineWidth: 0.4 * u)

            // Bottom raised trapezoidal deck housing.
            var trap = Path()
            trap.move(to: CGPoint(x: 20.5 * u, y: size.height))
            trap.addLine(to: CGPoint(x: 24.4 * u, y: 58.0 * u))
            trap.addQuadCurve(to: CGPoint(x: 26.8 * u, y: 56.6 * u), control: CGPoint(x: 25.0 * u, y: 56.6 * u))
            trap.addLine(to: CGPoint(x: 85.2 * u, y: 56.6 * u))
            trap.addQuadCurve(to: CGPoint(x: 87.6 * u, y: 58.0 * u), control: CGPoint(x: 87.0 * u, y: 56.6 * u))
            trap.addLine(to: CGPoint(x: 91.5 * u, y: size.height))
            trap.closeSubpath()

            context.fill(
                trap,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.875, green: 0.875, blue: 0.858),
                        Color(red: 0.818, green: 0.818, blue: 0.800)
                    ]),
                    startPoint: CGPoint(x: 0, y: 56.6 * u),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            context.stroke(trap, with: .color(.black.opacity(0.12)), lineWidth: 0.45 * u)

            // Bottom top-edge highlight on the trapezoid lip.
            var lip = Path()
            lip.move(to: CGPoint(x: 26.6 * u, y: 57.1 * u))
            lip.addLine(to: CGPoint(x: 85.4 * u, y: 57.1 * u))
            context.stroke(lip, with: .color(.white.opacity(0.55)), lineWidth: 0.55 * u)

            // Four recessed capstan and guide holes along the lower deck.
            drawGuideHole(in: &context, center: CGPoint(x: 31.6 * u, y: 68.3 * u), diameter: 4.5 * u, u: u)
            drawGuideHole(in: &context, center: CGPoint(x: 42.6 * u, y: 65.6 * u), diameter: 3.3 * u, u: u)
            drawGuideHole(in: &context, center: CGPoint(x: 69.4 * u, y: 65.6 * u), diameter: 3.3 * u, u: u)
            drawGuideHole(in: &context, center: CGPoint(x: 80.4 * u, y: 68.3 * u), diameter: 4.5 * u, u: u)

            // Four corner recessed Phillips screws.
            let screwInset = 4.6 * u
            let screws = [
                CGPoint(x: screwInset, y: screwInset),
                CGPoint(x: size.width - screwInset, y: screwInset),
                CGPoint(x: screwInset, y: size.height - screwInset),
                CGPoint(x: size.width - screwInset, y: size.height - screwInset)
            ]
            for center in screws {
                drawScrew(in: &context, center: center, diameter: 3.2 * u, u: u)
            }
        }
    }

    private func drawGuideHole(in context: inout GraphicsContext, center: CGPoint, diameter: CGFloat, u: CGFloat) {
        let holeRect = CGRect(
            x: center.x - diameter / 2, y: center.y - diameter / 2,
            width: diameter, height: diameter
        )
        let hole = Path(ellipseIn: holeRect)
        context.fill(hole, with: .color(Color(red: 0.08, green: 0.085, blue: 0.095)))
        context.stroke(hole, with: .color(.white.opacity(0.35)), lineWidth: 0.35 * u)
    }

    private func drawScrew(in context: inout GraphicsContext, center: CGPoint, diameter: CGFloat, u: CGFloat) {
        let wellRect = CGRect(
            x: center.x - diameter / 2, y: center.y - diameter / 2,
            width: diameter, height: diameter
        )
        context.fill(Path(ellipseIn: wellRect), with: .color(Color(white: 0.14)))
        let headRect = wellRect.insetBy(dx: 0.35 * u, dy: 0.35 * u)
        context.fill(Path(ellipseIn: headRect), with: .color(Color(white: 0.28)))
        var cross = Path()
        let arm = diameter * 0.26
        cross.move(to: CGPoint(x: center.x - arm, y: center.y))
        cross.addLine(to: CGPoint(x: center.x + arm, y: center.y))
        cross.move(to: CGPoint(x: center.x, y: center.y - arm))
        cross.addLine(to: CGPoint(x: center.x, y: center.y + arm))
        context.stroke(cross, with: .color(.black.opacity(0.65)), lineWidth: 0.38 * u)
    }

    private func hubLayer(diameter: CGFloat, angle: Double, u: CGFloat) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2

            // Dark anodized outer spline collar.
            let collarRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: collarRect), with: .color(Color(red: 0.125, green: 0.140, blue: 0.195)))
            context.stroke(Path(ellipseIn: collarRect.insetBy(dx: 0.25 * u, dy: 0.25 * u)),
                           with: .color(.black.opacity(0.45)), lineWidth: 0.45 * u)

            // Ivory drive ring + 6 symmetrical radial teeth rotated by tape travel.
            let ringRadius = radius * 0.74
            let holeRadius = radius * 0.44
            let ringRect = CGRect(x: center.x - ringRadius, y: center.y - ringRadius,
                                  width: ringRadius * 2, height: ringRadius * 2)
            context.fill(Path(ellipseIn: ringRect), with: .color(Color(red: 0.90, green: 0.90, blue: 0.88)))

            let holeRect = CGRect(x: center.x - holeRadius, y: center.y - holeRadius,
                                  width: holeRadius * 2, height: holeRadius * 2)
            context.fill(Path(ellipseIn: holeRect), with: .color(Color(red: 0.13, green: 0.145, blue: 0.185)))

            let baseRad = angle * .pi / 180.0
            for index in 0..<6 {
                let theta = baseRad + Double(index) * (.pi / 3.0)
                let cosT = cos(theta)
                let sinT = sin(theta)
                let perpX = -sinT
                let perpY = cosT
                let halfW = radius * 0.115
                let outerR = ringRadius * 0.92
                let innerR = holeRadius * 0.68

                var tooth = Path()
                tooth.move(to: CGPoint(x: center.x + cosT * outerR - perpX * halfW,
                                       y: center.y + sinT * outerR - perpY * halfW))
                tooth.addLine(to: CGPoint(x: center.x + cosT * outerR + perpX * halfW,
                                          y: center.y + sinT * outerR + perpY * halfW))
                tooth.addLine(to: CGPoint(x: center.x + cosT * innerR + perpX * (halfW * 0.85),
                                          y: center.y + sinT * innerR + perpY * (halfW * 0.85)))
                tooth.addLine(to: CGPoint(x: center.x + cosT * innerR - perpX * (halfW * 0.85),
                                          y: center.y + sinT * innerR - perpY * (halfW * 0.85)))
                tooth.closeSubpath()
                context.fill(tooth, with: .color(Color(red: 0.91, green: 0.91, blue: 0.89)))
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func labelInkLayer(u: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 2.5 * u) {
            coverEmblem(u: u)
                .frame(width: 11 * u, height: 11 * u)

            VStack(alignment: .leading, spacing: 0.6 * u) {
                Text(snapshot.labelTitle)
                    .font(.system(size: max(4, 4.1 * u), weight: .semibold))
                    .foregroundStyle(Color(red: 0.16, green: 0.17, blue: 0.15))
                    .lineLimit(1)

                if !snapshot.artist.isEmpty {
                    Text(snapshot.artist.uppercased())
                        .font(.system(size: max(3, 2.4 * u), weight: .medium))
                        .tracking(0.18 * u)
                        .foregroundStyle(Color(red: 0.16, green: 0.17, blue: 0.15).opacity(0.62))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 1 * u)

            Text(snapshot.sideIndexLabel)
                .font(.custom("GeistMono-Regular", fixedSize: max(3, 3.0 * u)))
                .foregroundStyle(Color(white: 0.35))
        }
    }

    @ViewBuilder
    private func coverEmblem(u: CGFloat) -> some View {
        if let artwork {
            fullColorCover(artwork)
                .frame(width: 11 * u, height: 11 * u)
                .clipShape(RoundedRectangle(cornerRadius: 0.8 * u, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 0.8 * u, style: .continuous)
                        .strokeBorder(.black.opacity(0.12), lineWidth: 0.3 * u)
                }
        } else {
            let emblemColor: Color = {
                if let tint = snapshot.tint {
                    return Color(red: tint.red * 0.45, green: tint.green * 0.45, blue: tint.blue * 0.45)
                }
                return Color(red: 0.16, green: 0.17, blue: 0.16)
            }()
            ZStack {
                RoundedRectangle(cornerRadius: 0.8 * u, style: .continuous)
                    .fill(emblemColor)
                Circle()
                    .strokeBorder(.white.opacity(0.75), lineWidth: 0.85 * u)
                    .padding(2.3 * u)
                Circle()
                    .fill(.white.opacity(0.75))
                    .frame(width: 2.4 * u, height: 2.4 * u)
            }
        }
    }

    private func lowerSpecsLayer(u: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Text("A")
                .font(.system(size: max(4, 5.0 * u), weight: .bold))
            Spacer(minLength: 2 * u)
            Text("标准型 • 120µs")
                .font(.custom("GeistMono-Regular", fixedSize: max(2.5, 2.2 * u)))
                .tracking(0.15 * u)
            Spacer(minLength: 2 * u)
            Text("C60")
                .font(.system(size: max(3.5, 4.0 * u), weight: .bold))
        }
        .foregroundStyle(Color(white: 0.25))
    }

    @ViewBuilder
    private func fullColorCover(_ image: UIImage) -> some View {
        #if canImport(WidgetKit)
        Image(uiImage: image)
            .resizable()
            .widgetAccentedRenderingMode(.fullColor)
            .scaledToFill()
        #else
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
        #endif
    }
}
