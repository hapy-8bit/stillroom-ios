import SwiftUI

/// Airy pale warm-pearl interior cavity behind the reels for `.window`.
struct OneTapeWindowInteriorDeck: View {
    let size: CGSize

    private let shellFrame = OneTapeCassettePocketMask.shellFrame

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.875, green: 0.868, blue: 0.842),
                            Color(red: 0.822, green: 0.816, blue: 0.790),
                            Color(red: 0.795, green: 0.788, blue: 0.764)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: shellFrame.width, height: shellFrame.height)
                .position(x: shellFrame.midX, y: shellFrame.midY)

            Canvas { context, _ in
                var tapeGuides = Path()
                tapeGuides.move(to: CGPoint(x: 112, y: 120))
                tapeGuides.addLine(to: CGPoint(x: 196, y: 66))
                tapeGuides.move(to: CGPoint(x: 112, y: 456))
                tapeGuides.addLine(to: CGPoint(x: 196, y: 510))
                context.stroke(tapeGuides, with: .color(.black.opacity(0.09)), lineWidth: 0.9)

                let pin = Path(roundedRect: CGRect(x: 200.5, y: 284.5, width: 7, height: 7), cornerRadius: 1.2)
                context.stroke(pin, with: .color(.black.opacity(0.30)), lineWidth: 0.8)
                context.fill(Path(ellipseIn: CGRect(x: 202.5, y: 286.5, width: 3, height: 3)),
                             with: .color(.black.opacity(0.45)))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .drawingGroup()
    }
}

/// Real `OneTapeClassicShell` masked outside the 3D chamfered window cutaway + recessed wall + raised right label pillar.
struct OneTapeWindowShellOverlay: View {
    let size: CGSize
    let shellAssetName: String

    private let shellFrame = OneTapeCassettePocketMask.shellFrame
    private let guidePorts: [(center: CGPoint, square: Bool)] = [
        (CGPoint(x: 35.0, y: 158.3), false),
        (CGPoint(x: 41.6, y: 211.5), true),
        (CGPoint(x: 41.6, y: 363.9), true),
        (CGPoint(x: 35.0, y: 417.2), false)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Subtle milky translucent glazing sheen inside the open window pane.
            OneTapeWindowCutoutPolygon()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.14), .clear, .black.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Dark cylindrical hole liners positioned cleanly behind ClassicShell's open head-bay ports.
            ForEach(Array(guidePorts.enumerated()), id: \.offset) { _, port in
                Circle()
                    .fill(Color(white: 0.14))
                    .frame(width: port.square ? 10 : 12, height: port.square ? 10 : 12)
                    .overlay {
                        Circle()
                            .stroke(Color(red: 0.42, green: 0.43, blue: 0.46), lineWidth: 1.4)
                    }
                    .position(port.center)
            }

            // 1. Photographic ClassicShell outside the stepped window polygon.
            Image(shellAssetName)
                .resizable()
                .frame(width: size.width, height: size.height)
                .colorMultiply(Color(red: 0.99, green: 0.985, blue: 0.96))
                .mask {
                    OneTapeWindowMaskShape(shellFrame: shellFrame)
                        .fill(.white, style: FillStyle(eoFill: true))
                }
                .shadow(color: .black.opacity(0.16), radius: 2.5, x: -1.0, y: 1.0)

            // Seamless raised vertical shelf along the left window edge (`x = 92...120`).
            OneTapeLeftWindowBridgeShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.878, green: 0.866, blue: 0.832),
                            Color(red: 0.858, green: 0.846, blue: 0.812)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // 3D recessed window inner wall bevel around the stepped opening.
            OneTapeWindowCutoutPolygon()
                .stroke(Color(red: 0.72, green: 0.705, blue: 0.675), lineWidth: 2.8)
                .opacity(0.55)
                .mask { OneTapeWindowCutoutPolygon().fill(.white) }
            OneTapeWindowCutoutPolygon()
                .stroke(
                    LinearGradient(
                        colors: [.black.opacity(0.20), .white.opacity(0.66)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.95
                )

            // Clean integrated flush right label plane (`x = 264...342, y = 48...528`)
            // framing A, One Cassette, and subtitle smoothly on warm matte ivory.
            OneTapeRightLabelTabShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.892, green: 0.882, blue: 0.854),
                            Color(red: 0.856, green: 0.846, blue: 0.818)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.11), radius: 1.6, x: -1.0, y: 0.5)
            OneTapeRightLabelTabShape()
                .stroke(.white.opacity(0.50), lineWidth: 0.75)
            OneTapeRightLabelTabShape()
                .inset(by: 4.5)
                .stroke(.black.opacity(0.055), lineWidth: 0.6)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .drawingGroup()
    }
}

private struct OneTapeWindowMaskShape: Shape {
    let shellFrame: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: shellFrame, cornerSize: CGSize(width: 16, height: 16))
        path.addPath(OneTapeWindowCutoutPolygon().path(in: rect))
        return path
    }
}

private struct OneTapeWindowCutoutPolygon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 108, y: 54))
        p.addLine(to: CGPoint(x: 306, y: 54))
        p.addQuadCurve(to: CGPoint(x: 314, y: 62), control: CGPoint(x: 314, y: 54))
        p.addLine(to: CGPoint(x: 314, y: 514))
        p.addQuadCurve(to: CGPoint(x: 306, y: 522), control: CGPoint(x: 314, y: 522))
        p.addLine(to: CGPoint(x: 108, y: 522))
        p.addQuadCurve(to: CGPoint(x: 100, y: 514), control: CGPoint(x: 100, y: 522))
        p.addLine(to: CGPoint(x: 100, y: 492))
        p.addLine(to: CGPoint(x: 120, y: 464))
        p.addLine(to: CGPoint(x: 120, y: 112))
        p.addLine(to: CGPoint(x: 100, y: 84))
        p.addLine(to: CGPoint(x: 100, y: 62))
        p.addQuadCurve(to: CGPoint(x: 108, y: 54), control: CGPoint(x: 100, y: 54))
        p.closeSubpath()
        return p
    }
}

private struct OneTapeLeftWindowBridgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 92, y: 78))
        p.addLine(to: CGPoint(x: 96, y: 78))
        p.addLine(to: CGPoint(x: 120, y: 112))
        p.addLine(to: CGPoint(x: 120, y: 464))
        p.addLine(to: CGPoint(x: 96, y: 498))
        p.addLine(to: CGPoint(x: 92, y: 498))
        p.addLine(to: CGPoint(x: 92, y: 468))
        p.addLine(to: CGPoint(x: 94, y: 464))
        p.addLine(to: CGPoint(x: 94, y: 112))
        p.addLine(to: CGPoint(x: 92, y: 108))
        p.closeSubpath()
        return p
    }
}

private struct OneTapeRightLabelTabShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let i = insetAmount
        var p = Path()
        p.move(to: CGPoint(x: 280 + i * 0.4, y: 50 + i))
        p.addLine(to: CGPoint(x: 336 - i, y: 50 + i))
        p.addQuadCurve(to: CGPoint(x: 342 - i, y: 56 + i), control: CGPoint(x: 342 - i, y: 50 + i))
        p.addLine(to: CGPoint(x: 342 - i, y: 520 - i))
        p.addQuadCurve(to: CGPoint(x: 336 - i, y: 526 - i), control: CGPoint(x: 342 - i, y: 526 - i))
        p.addLine(to: CGPoint(x: 280 + i * 0.4, y: 526 - i))
        p.addLine(to: CGPoint(x: 264 + i, y: 508 - i * 0.5))
        p.addLine(to: CGPoint(x: 264 + i, y: 68 + i * 0.5))
        p.closeSubpath()
        return p
    }
}
