import SwiftUI

/// Animatable curved parting mask for the upper and lower halves of the factory
/// anti-static sleeve. As `tearProgress` slides left/right across `0...1`, the
/// left portion `[0 ... tearX]` peels smoothly UP (top cap) and DOWN (lower
/// pouch) like a zipper in motion—while preserving a pure matte packaging-film
/// aesthetic rather than literal clothing zipper hardware.
struct OneTapeZipperSleeveShape: Shape {
    let isTopCap: Bool
    var tearProgress: CGFloat

    var animatableData: CGFloat {
        get { tearProgress }
        set { tearProgress = newValue }
    }

    static func zipperMouth(in size: CGSize, isTopCap: Bool, progress: CGFloat)
        -> (tearX: CGFloat, seamY: CGFloat, partedY: CGFloat)
    {
        let p = min(1, max(0, progress))
        let tearX = p * size.width
        if isTopCap {
            let openDepth = min(size.height * 0.90, p * size.height * 0.96 + p * 18)
            return (tearX, size.height, max(0, size.height - openDepth))
        } else {
            let openDepth = min(size.height * 0.54, p * size.height * 0.48 + p * 30)
            return (tearX, 0, min(size.height, openDepth))
        }
    }

    func path(in rect: CGRect) -> Path {
        let m = Self.zipperMouth(in: rect.size, isTopCap: isTopCap, progress: tearProgress)
        var path = Path()
        if isTopCap {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: m.seamY))
            if m.tearX > 0.5 {
                path.addLine(to: CGPoint(x: m.tearX, y: m.seamY))
                path.addCurve(
                    to: CGPoint(x: 0, y: m.partedY),
                    control1: CGPoint(x: m.tearX * 0.74, y: m.seamY),
                    control2: CGPoint(x: m.tearX * 0.34, y: m.partedY)
                )
            } else {
                path.addLine(to: CGPoint(x: 0, y: m.seamY))
            }
            path.closeSubpath()
        } else {
            if m.tearX > 0.5 {
                path.move(to: CGPoint(x: 0, y: m.partedY))
                path.addCurve(
                    to: CGPoint(x: m.tearX, y: m.seamY),
                    control1: CGPoint(x: m.tearX * 0.34, y: m.partedY),
                    control2: CGPoint(x: m.tearX * 0.74, y: m.seamY)
                )
                path.addLine(to: CGPoint(x: rect.width, y: m.seamY))
            } else {
                path.move(to: CGPoint(x: 0, y: m.seamY))
                path.addLine(to: CGPoint(x: rect.width, y: m.seamY))
            }
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
        return path
    }
}

/// Translucent factory anti-static frosted sleeve rendered directly over the
/// live hardware deck. Clips along `OneTapeZipperSleeveShape` so sliding the
/// tear-strip pull-tab left/right parts the matte film smoothly up and down,
/// revealing the razor-sharp cassette player underneath.
struct OneTapeFactorySleeveHalf: View {
    let isTopCap: Bool
    let tearProgress: CGFloat
    let sheenAnchor: UnitPoint
    let peelProgress: CGFloat
    var bottomSafeInset: CGFloat = 34

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)

            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.92, green: 0.91, blue: 0.88).opacity(0.28), location: 0.0),
                    .init(color: Color(red: 0.85, green: 0.86, blue: 0.84).opacity(0.18), location: 0.5),
                    .init(color: Color(red: 0.90, green: 0.89, blue: 0.86).opacity(0.26), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    .white.opacity(0.22),
                    .white.opacity(0.06),
                    .clear
                ],
                center: sheenAnchor,
                startRadius: 10,
                endRadius: 240
            )

            Canvas { context, size in
                drawAntiStaticPattern(in: &context, size: size)
                drawHeatSealCrimps(in: &context, size: size)
                if !isTopCap, peelProgress > 0.01 {
                    drawPeelHighlight(in: &context, size: size)
                }
                if tearProgress > 0.005 {
                    drawPartedFilmEdge(in: &context, size: size)
                }
            }

            if !isTopCap {
                sleeveSilkscreenPrint
                    .offset(y: min(86, tearProgress * 72))
            } else {
                topCapStamp
                    .offset(y: -min(36, tearProgress * 34))
            }
        }
        .clipShape(OneTapeZipperSleeveShape(isTopCap: isTopCap, tearProgress: tearProgress))
        .shadow(
            color: .black.opacity(tearProgress > 0.01 ? 0.38 : 0),
            radius: 14,
            y: isTopCap ? 6 : -6
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawAntiStaticPattern(in context: inout GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 18
        var lines = Path()
        var x: CGFloat = -size.height
        while x < size.width + size.height {
            lines.move(to: CGPoint(x: x, y: 0))
            lines.addLine(to: CGPoint(x: x + size.height, y: size.height))
            x += spacing
        }
        context.stroke(lines, with: .color(.white.opacity(0.045)), lineWidth: 0.5)
    }

    private func drawHeatSealCrimps(in context: inout GraphicsContext, size: CGSize) {
        let rim: CGFloat = 14
        let leftRect = CGRect(x: 0, y: 0, width: rim, height: size.height)
        let rightRect = CGRect(x: size.width - rim, y: 0, width: rim, height: size.height)
        context.fill(Path(leftRect), with: .color(.white.opacity(0.09)))
        context.fill(Path(rightRect), with: .color(.white.opacity(0.09)))

        var seamBorder = Path()
        seamBorder.move(to: CGPoint(x: rim, y: 0))
        seamBorder.addLine(to: CGPoint(x: rim, y: size.height))
        seamBorder.move(to: CGPoint(x: size.width - rim, y: 0))
        seamBorder.addLine(to: CGPoint(x: size.width - rim, y: size.height))
        context.stroke(seamBorder, with: .color(.white.opacity(0.18)), lineWidth: 0.6)

        var sideRibs = Path()
        var y: CGFloat = 4
        while y < size.height {
            sideRibs.move(to: CGPoint(x: 2, y: y))
            sideRibs.addLine(to: CGPoint(x: rim - 2, y: y))
            sideRibs.move(to: CGPoint(x: size.width - rim + 2, y: y))
            sideRibs.addLine(to: CGPoint(x: size.width - 2, y: y))
            y += 4.5
        }
        context.stroke(sideRibs, with: .color(.black.opacity(0.14)), lineWidth: 0.7)

        let endRect = isTopCap
            ? CGRect(x: 0, y: 0, width: size.width, height: rim)
            : CGRect(x: 0, y: size.height - rim, width: size.width, height: rim)
        context.fill(Path(endRect), with: .color(.white.opacity(0.09)))
        var endRibs = Path()
        var rx: CGFloat = 4
        while rx < size.width {
            endRibs.move(to: CGPoint(x: rx, y: endRect.minY + 2))
            endRibs.addLine(to: CGPoint(x: rx, y: endRect.maxY - 2))
            rx += 4.5
        }
        context.stroke(endRibs, with: .color(.black.opacity(0.14)), lineWidth: 0.7)
    }

    /// Draws a clean luminous matte polyethylene edge curl along the curved
    /// parted film lip `[0 ... tearX]`—clean modern packaging film, no metal teeth.
    private func drawPartedFilmEdge(in context: inout GraphicsContext, size: CGSize) {
        let m = OneTapeZipperSleeveShape.zipperMouth(in: size, isTopCap: isTopCap, progress: tearProgress)
        guard m.tearX > 2 else { return }

        var curve = Path()
        curve.move(to: CGPoint(x: 0, y: m.partedY))
        curve.addCurve(
            to: CGPoint(x: m.tearX, y: m.seamY),
            control1: CGPoint(x: m.tearX * 0.34, y: m.partedY),
            control2: CGPoint(x: m.tearX * 0.74, y: m.seamY)
        )

        // Soft frosted film thickness band hugging the parted lip.
        context.stroke(
            curve,
            with: .color(.white.opacity(0.22)),
            style: StrokeStyle(lineWidth: 6.5, lineCap: .round)
        )
        // Fine glossy light-catch right along the torn film edge.
        context.stroke(
            curve,
            with: .color(.white.opacity(0.68)),
            style: StrokeStyle(lineWidth: 1.3, lineCap: .round)
        )
        // Subtle micro-perforation score line just inside the peeled rim.
        let insetY: CGFloat = isTopCap ? -4.0 : 4.0
        var scoreCurve = Path()
        scoreCurve.move(to: CGPoint(x: 0, y: m.partedY + insetY))
        scoreCurve.addCurve(
            to: CGPoint(x: m.tearX, y: m.seamY + insetY),
            control1: CGPoint(x: m.tearX * 0.34, y: m.partedY + insetY),
            control2: CGPoint(x: m.tearX * 0.74, y: m.seamY + insetY)
        )
        context.stroke(
            scoreCurve,
            with: .color(.white.opacity(0.24)),
            style: StrokeStyle(lineWidth: 0.8, dash: [3.5, 4.0])
        )
    }

    private func drawPeelHighlight(in context: inout GraphicsContext, size: CGSize) {
        let bandHeight: CGFloat = 46
        let bandRect = CGRect(x: 0, y: 0, width: size.width, height: bandHeight)
        let gradient = Gradient(stops: [
            .init(color: .white.opacity(0.45 * min(1, peelProgress * 2.5)), location: 0.0),
            .init(color: .white.opacity(0.14 * min(1, peelProgress * 2.5)), location: 0.35),
            .init(color: .clear, location: 1.0)
        ])
        context.fill(
            Path(bandRect),
            with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: bandHeight))
        )
    }

    private var topCapStamp: some View {
        VStack {
            Spacer()
            HStack {
                Text("FACTORY SEALED · LOT 040")
                    .font(.custom("GeistMono-Regular", fixedSize: 9))
                    .tracking(2.0)
                    .foregroundStyle(.white.opacity(0.46))
                Spacer()
                Text("ANTI-STATIC")
                    .font(.custom("GeistMono-Regular", fixedSize: 9))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.38))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    private var sleeveSilkscreenPrint: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("One Cassette")
                        .font(.custom("InstrumentSerif-Italic", size: 42))
                        .tracking(-0.8)
                        .foregroundStyle(.white.opacity(0.84))
                    Spacer()
                    Text("TYPE IV")
                        .font(.custom("GeistMono-Regular", fixedSize: 10))
                        .tracking(2.0)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.28), lineWidth: 0.7)
                        }
                }

                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(height: 0.7)

                HStack {
                    Text("HI-FI CASSETTE DECK · PROTECTIVE SLEEVE")
                        .font(.custom("GeistMono-Regular", fixedSize: 8.5))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.48))
                    Spacer()
                    Text("SIDE A")
                        .font(.custom("GeistMono-Regular", fixedSize: 8.5))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.48))
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 88)

            Spacer(minLength: 40)

            HStack(alignment: .bottom, spacing: 14) {
                OneTapeFactoryBarcodeView()
                    .frame(width: 118, height: 34)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(red: 0.89, green: 0.50, blue: 0.30))
                            .frame(width: 5, height: 5)
                        Text("QC INSPECTED")
                            .font(.custom("GeistMono-Regular", fixedSize: 8.5))
                            .tracking(1.8)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Text("S/N 040-100 · 120µs")
                        .font(.custom("GeistMono-Regular", fixedSize: 9))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, max(42, bottomSafeInset + 22))
        }
    }
}

private struct OneTapeFactoryBarcodeView: View {
    private static let weights: [CGFloat] = [
        2, 1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 2, 3, 1, 2, 1, 1, 3, 1, 2, 1, 2, 3, 1, 2
    ]

    var body: some View {
        Canvas { context, size in
            let totalUnits = Self.weights.reduce(0, +) + CGFloat(Self.weights.count - 1) * 1.15
            let unit = size.width / max(1, totalUnits)
            var x: CGFloat = 0
            for (index, weight) in Self.weights.enumerated() {
                let w = weight * unit
                let h = index % 5 == 0 ? size.height : size.height * 0.82
                context.fill(Path(CGRect(x: x, y: 0, width: w, height: h)), with: .color(.white.opacity(0.56)))
                x += w + 1.15 * unit
            }
        }
    }
}

/// Clean perforated packaging tear-strip band ahead of the split point plus the
/// vermilion-terracotta `"拆封 >"` pull-tab (no clothing zipper hardware).
struct OneTapeOpeningTearStrip: View {
    let tearProgress: CGFloat
    let detachment: CGFloat
    let slideDirection: CGFloat
    let reducedMotion: Bool
    let onAccessibilityActivate: () -> Void

    @State private var pulse = false

    static func pullTabOriginX(progress: CGFloat, width: CGFloat) -> CGFloat {
        let clamped = min(1, max(0, progress))
        let tearX = clamped * width
        return min(max(12, width - 88), max(12, tearX - 4))
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let progress = min(1, max(0, tearProgress))
            let tearX = progress * width
            let remainingWidth = max(0, width - tearX)
            let tabX = Self.pullTabOriginX(progress: progress, width: width)

            ZStack(alignment: .leading) {
                // Intact parchment-foil perforated seal strip on [tearX ... width].
                if remainingWidth > 1 {
                    ZStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.94, green: 0.92, blue: 0.88).opacity(0.92),
                                        Color(red: 0.86, green: 0.84, blue: 0.79).opacity(0.88)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Canvas { context, size in
                            let midY = size.height / 2

                            // Crisp top & bottom packaging perforation dashes.
                            var perf = Path()
                            perf.move(to: CGPoint(x: 0, y: 1))
                            perf.addLine(to: CGPoint(x: size.width, y: 1))
                            perf.move(to: CGPoint(x: 0, y: size.height - 1))
                            perf.addLine(to: CGPoint(x: size.width, y: size.height - 1))
                            context.stroke(
                                perf,
                                with: .color(.black.opacity(0.24)),
                                style: StrokeStyle(lineWidth: 1.0, dash: [4.5, 4.0])
                            )

                            // Subtle directional chevrons anchored right of initial pull-tab.
                            var chevrons = Path()
                            var x: CGFloat = 108
                            while x < size.width - 18 {
                                chevrons.move(to: CGPoint(x: x - 3, y: midY - 4.2))
                                chevrons.addLine(to: CGPoint(x: x + 2, y: midY))
                                chevrons.addLine(to: CGPoint(x: x - 3, y: midY + 4.2))
                                x += 28
                            }
                            context.stroke(
                                chevrons,
                                with: .color(.black.opacity(0.20)),
                                style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    .frame(width: width, height: 30)
                    .mask(alignment: .trailing) {
                        Rectangle().frame(width: remainingWidth, height: 30)
                    }
                    .allowsHitTesting(false)
                }

                // Curled torn paper-foil ribbon tail following the moving pull-tab.
                if progress > 0.03 {
                    let tailWidth = min(width * 0.28, tearX * 0.55)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.91, green: 0.88, blue: 0.83).opacity(0.95),
                                    Color(red: 0.78, green: 0.30, blue: 0.19)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: tailWidth, height: 28)
                        .rotation3DEffect(
                            .degrees(reducedMotion ? 0 : 18),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .trailing,
                            perspective: 0.5
                        )
                        .shadow(color: .black.opacity(0.28), radius: 8, x: -2, y: 5)
                        .offset(x: max(0, tabX - tailWidth + 6) + detachment * 160)
                        .opacity(1 - Double(detachment))
                        .allowsHitTesting(false)
                }

                // Vermilion-terracotta folded `"拆封 >"` pull-tab (no metal carriage).
                pullTabBody
                    .rotationEffect(
                        .degrees(reducedMotion ? 0 : Double(slideDirection) * 4.0),
                        anchor: .leading
                    )
                    .offset(x: tabX + detachment * 160)
                    .opacity(1 - Double(detachment))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("出厂封条拉环")
                    .accessibilityHint("左右滑动拆开或合拢封膜，轻点直接拆封")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onAccessibilityActivate() }
                    .accessibilityIdentifier("opening.tearTab")
            }
            .frame(width: width, height: 52, alignment: .leading)
        }
        .frame(height: 52)
        .onAppear {
            guard !reducedMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var pullTabBody: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2.5) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(.white.opacity(0.48))
                        .frame(width: 1.5, height: 14)
                }
            }
            Text("拆封")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.96))
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(pulse ? 0.96 : 0.56))
                .offset(x: pulse && !reducedMotion ? 2.5 : 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.34, blue: 0.21),
                    Color(red: 0.69, green: 0.22, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.34), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.42), radius: 8, x: 2, y: 5)
    }
}

/// Subtle vignette behind the settling player deck while unwrapping.
struct OneTapeOpeningBackdrop: View {
    @ObservedObject var opening: OneTapeOpeningStore
    let reducedMotion: Bool

    var body: some View {
        Color.black
            .opacity(0.32 * opening.sleeveOpacity * (1 - Double(opening.tearProgress) * 0.65))
            .ignoresSafeArea(.container)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
