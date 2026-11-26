import SwiftUI

/// Smoked charcoal interior cavity, Delrin white guide rollers, tangent tape ribbon, and head block for `.clear`.
struct OneTapeClearInteriorDeck: View {
    let size: CGSize

    private let shellFrame = OneTapeCassettePocketMask.shellFrame

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.145, green: 0.155, blue: 0.165),
                            Color(red: 0.105, green: 0.115, blue: 0.125),
                            Color(red: 0.130, green: 0.138, blue: 0.148)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: shellFrame.width, height: shellFrame.height)
                .position(x: shellFrame.midX, y: shellFrame.midY)

            Canvas { context, _ in
                // Recessed smoked acrylic inner frame wall (no bright white borders).
                let innerWall = Path(
                    roundedRect: shellFrame.insetBy(dx: 5.5, dy: 5.5),
                    cornerRadius: 12.5
                )
                context.stroke(innerWall, with: .color(.white.opacity(0.065)), lineWidth: 1.0)
                let midDivider = Path { p in
                    p.move(to: CGPoint(x: 110, y: 288))
                    p.addLine(to: CGPoint(x: 348, y: 288))
                }
                context.stroke(midDivider, with: .color(.black.opacity(0.28)), lineWidth: 0.8)

                // Four molded smoky cylindrical screw standoffs in the corners.
                for pt in OneTapeCrystalHardware.cornerScrews {
                    let ring = Path(ellipseIn: CGRect(x: pt.x - 13, y: pt.y - 13, width: 26, height: 26))
                    context.fill(ring, with: .color(.black.opacity(0.32)))
                    context.stroke(ring, with: .color(.white.opacity(0.07)), lineWidth: 0.75)
                }

                // Tensioned magnetic oxide tape path travelling tangent from reel packs around top & bottom rollers.
                var ribbon = Path()
                ribbon.move(to: CGPoint(x: 204, y: 64))
                ribbon.addLine(to: CGPoint(x: 48, y: 45))
                ribbon.addLine(to: CGPoint(x: 35, y: 58))
                ribbon.addLine(to: CGPoint(x: 35, y: 518))
                ribbon.addLine(to: CGPoint(x: 48, y: 531))
                ribbon.addLine(to: CGPoint(x: 204, y: 512))
                context.stroke(ribbon, with: .color(Color(red: 0.36, green: 0.27, blue: 0.21).opacity(0.85)), lineWidth: 1.4)
                context.stroke(ribbon, with: .color(.white.opacity(0.20)), lineWidth: 0.5)

                // Head block metal frame + warm bronze spring leaf + felt pad on far-left bay.
                let headFrame = Path(roundedRect: CGRect(x: 19, y: 264, width: 16, height: 48), cornerRadius: 2)
                context.fill(headFrame, with: .color(Color(white: 0.38).opacity(0.65)))
                let bronzeLeaf = Path(roundedRect: CGRect(x: 22, y: 274, width: 5, height: 28), cornerRadius: 1)
                context.fill(bronzeLeaf, with: .color(Color(red: 0.68, green: 0.54, blue: 0.36).opacity(0.92)))

                // Two crisp matte pearl-white Delrin guide rollers at top & bottom corners.
                for y in [58.0, 518.0] {
                    let c = CGPoint(x: 48, y: y)
                    let roller = Path(ellipseIn: CGRect(x: c.x - 13, y: c.y - 13, width: 26, height: 26))
                    context.fill(
                        roller,
                        with: .radialGradient(
                            Gradient(colors: [Color(white: 0.94), Color(white: 0.78), Color(white: 0.87)]),
                            center: c,
                            startRadius: 2,
                            endRadius: 13
                        )
                    )
                    context.stroke(roller, with: .color(.black.opacity(0.55)), lineWidth: 0.8)
                    let pin = Path(ellipseIn: CGRect(x: c.x - 3.6, y: c.y - 3.6, width: 7.2, height: 7.2))
                    context.fill(pin, with: .color(Color(white: 0.14)))
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .drawingGroup()
    }
}

/// Smoked polycarbonate outer wall and raised translucent dark trapezoid head bridge drawn above reels for `.clear`.
struct OneTapeClearShellOverlay: View {
    let size: CGSize

    private let shellFrame = OneTapeCassettePocketMask.shellFrame

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Smoked polycarbonate trapezoid head cover overlapping the bottom edge of both reels.
            OneTapeHeadTrapezoid(shellFrame: shellFrame)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.09, blue: 0.10).opacity(0.76),
                            Color(red: 0.05, green: 0.06, blue: 0.07).opacity(0.84)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.45), radius: 3.5, x: 2.0, y: 0)

            OneTapeHeadTrapezoid(shellFrame: shellFrame)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.24), .white.opacity(0.08), .white.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )

            // Refined smoked acrylic glass reflection gradient across the housing.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.07),
                            .clear,
                            .white.opacity(0.015),
                            .white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: shellFrame.width, height: shellFrame.height)
                .position(x: shellFrame.midX, y: shellFrame.midY)

            // Quiet smoky molded perimeter wall bevel.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(white: 0.19).opacity(0.78), lineWidth: 3.0)
                .frame(width: shellFrame.width - 2.2, height: shellFrame.height - 2.2)
                .position(x: shellFrame.midX, y: shellFrame.midY)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .clear, .black.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.85
                )
                .frame(width: shellFrame.width - 0.8, height: shellFrame.height - 0.8)
                .position(x: shellFrame.midX, y: shellFrame.midY)

            ForEach(Array(OneTapeCrystalHardware.guidePorts.enumerated()), id: \.offset) { _, port in
                OneTapeHardwareHole(center: port.center, square: port.square, dark: true)
            }
            ForEach(Array(OneTapeCrystalHardware.allScrews.enumerated()), id: \.offset) { _, pt in
                OneTapeHardwareScrew(center: pt)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .drawingGroup()
    }
}

private struct OneTapeHeadTrapezoid: Shape {
    let shellFrame: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: shellFrame.minX, y: 78))
        path.addLine(to: CGPoint(x: 99, y: 108))
        path.addLine(to: CGPoint(x: 99, y: 468))
        path.addLine(to: CGPoint(x: shellFrame.minX, y: 498))
        path.closeSubpath()
        return path
    }
}

private enum OneTapeCrystalHardware {
    static let cornerScrews: [CGPoint] = [
        CGPoint(x: 33.5, y: 35.5), CGPoint(x: 343.3, y: 35.5),
        CGPoint(x: 33.5, y: 540.5), CGPoint(x: 343.3, y: 540.5)
    ]

    static let allScrews: [CGPoint] = cornerScrews + [CGPoint(x: 71.5, y: 288.0)]

    static let guidePorts: [(center: CGPoint, square: Bool)] = [
        (CGPoint(x: 35.0, y: 158.3), false),
        (CGPoint(x: 41.6, y: 211.5), true),
        (CGPoint(x: 41.6, y: 363.9), true),
        (CGPoint(x: 35.0, y: 417.2), false)
    ]
}

private struct OneTapeHardwareScrew: View {
    let center: CGPoint

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.24), Color(white: 0.08)], center: .center, startRadius: 1, endRadius: 6.2))
                .frame(width: 12.2, height: 12.2)
                .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 0.55) }
            Path { p in
                p.move(to: CGPoint(x: 3.6, y: 6.1))
                p.addLine(to: CGPoint(x: 8.6, y: 6.1))
                p.move(to: CGPoint(x: 6.1, y: 3.6))
                p.addLine(to: CGPoint(x: 6.1, y: 8.6))
            }
            .stroke(.black.opacity(0.78), lineWidth: 1.15)
            .frame(width: 12.2, height: 12.2)
        }
        .position(center)
    }
}

private struct OneTapeHardwareHole: View {
    let center: CGPoint
    let square: Bool
    let dark: Bool

    var body: some View {
        Group {
            if square {
                RoundedRectangle(cornerRadius: 2.0, style: .continuous)
                    .fill(dark ? Color(white: 0.18).opacity(0.75) : Color(white: 0.14))
                    .frame(width: 9.5, height: 9.5)
                    .overlay {
                        RoundedRectangle(cornerRadius: 2.0, style: .continuous)
                            .stroke(.white.opacity(dark ? 0.18 : 0.16), lineWidth: 0.65)
                    }
            } else {
                Circle()
                    .fill(dark ? Color(white: 0.18).opacity(0.75) : Color(white: 0.14))
                    .frame(width: 10, height: 10)
                    .overlay { Circle().stroke(.white.opacity(dark ? 0.18 : 0.16), lineWidth: 0.65) }
            }
        }
        .position(center)
    }
}
