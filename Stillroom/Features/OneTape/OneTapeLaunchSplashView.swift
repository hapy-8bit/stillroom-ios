import SwiftUI

/// Automatic ~1.9s cold-launch splash showcasing a minimalist Braun-inspired
/// warm-cream & graphite horizontal mini cassette deck. Distinct from the
/// original vertical black Walkman: features a top vermilion Play key, glowing
/// amber power LED, living analog VU meter needle, speaker louver slots, and
/// twin motor-accelerated cassette hubs before seamlessly dissolving into the
/// live main player.
struct OneTapeLaunchSplashView: View {
    @ObservedObject var opening: OneTapeOpeningStore
    let reducedMotion: Bool

    var body: some View {
        ZStack {
            // Deep matte studio dark canvas matching the hardware aesthetic.
            Color(red: 0.055, green: 0.055, blue: 0.06)
                .ignoresSafeArea()

            // Subtle warm studio key-light halo behind the centered mini deck.
            RadialGradient(
                colors: [
                    Color(red: 0.94, green: 0.89, blue: 0.80)
                        .opacity(opening.splashPlayPressed ? 0.095 : 0.055),
                    Color.clear
                ],
                center: .center,
                startRadius: 16,
                endRadius: 210
            )
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.45), value: opening.splashPlayPressed)

            VStack(spacing: 22) {
                braunMiniDeck
                    .scaleEffect(deckScale)
                    .offset(y: opening.splashRecoilY)

                Text("ONE CASSETTE")
                    .font(.custom("GeistMono-Regular", fixedSize: 10))
                    .tracking(4.2)
                    .foregroundStyle(.white.opacity(opening.splashAppeared ? 0.34 : 0))
            }
            .offset(y: -14)
        }
        .opacity(opening.splashDissolving ? 0 : 1)
        .allowsHitTesting(!opening.splashDissolving)
        .onAppear {
            opening.startSplashIfNeeded(reducedMotion: reducedMotion)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("One Cassette 启动动画")
        .accessibilityIdentifier("opening.splash")
    }

    private var deckScale: CGFloat {
        if reducedMotion { return 1 }
        if opening.splashDissolving { return 1.05 }
        return opening.splashAppeared ? 1.0 : 0.93
    }

    // MARK: - Braun Minimalist Horizontal Mini Cassette Deck

    private var braunMiniDeck: some View {
        VStack(spacing: 0) {
            // Top mechanical transport rail (vermilion Play key + matte graphite keys).
            HStack(alignment: .bottom, spacing: 6) {
                Spacer(minLength: 0)

                // Hero vermilion Play key — physically depresses into its recess.
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.89, green: 0.36, blue: 0.22),
                                    Color(red: 0.76, green: 0.25, blue: 0.14)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 44, height: 14)
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .strokeBorder(.white.opacity(0.28), lineWidth: 0.6)
                        }
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .offset(y: -1)
                        }
                        .offset(y: opening.splashPlayPressed ? 6.5 : 0)
                }
                .frame(height: 14, alignment: .bottom)
                .clipped()

                // Matte graphite sibling keys: Stop, Rewind, Fast-Forward.
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.28), Color(white: 0.17)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 22, height: 10)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                        }
                }
            }
            .padding(.trailing, 20)
            .frame(width: 228, height: 14, alignment: .bottom)
            .offset(y: 2)

            // Main warm-cream molded Braun chassis.
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.93, green: 0.91, blue: 0.87), location: 0.0),
                                .init(color: Color(red: 0.88, green: 0.86, blue: 0.82), location: 0.65),
                                .init(color: Color(red: 0.82, green: 0.80, blue: 0.75), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.75), .black.opacity(0.18)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.9
                            )
                    }
                    .shadow(color: .black.opacity(0.62), radius: 28, x: 0, y: 16)
                    .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 3)

                // Recessed inner instrument layout.
                VStack(spacing: 10) {
                    // Top header bar: brand badge + glowing amber power LED.
                    HStack(alignment: .center) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(
                                    opening.splashPlayPressed
                                        ? Color(red: 0.96, green: 0.56, blue: 0.22)
                                        : Color(white: 0.36)
                                )
                                .frame(width: 5, height: 5)
                                .shadow(
                                    color: opening.splashPlayPressed
                                        ? Color(red: 0.96, green: 0.56, blue: 0.22).opacity(0.85)
                                        : .clear,
                                    radius: 4
                                )
                            Text("DECK · 040")
                                .font(.custom("GeistMono-Regular", fixedSize: 7.5))
                                .tracking(1.6)
                                .foregroundStyle(Color.black.opacity(0.54))
                        }
                        Spacer()
                        Text("HI-FI")
                            .font(.custom("GeistMono-Regular", fixedSize: 7))
                            .tracking(1.4)
                            .foregroundStyle(Color.black.opacity(0.36))
                    }

                    // Instrument deck: Left VU meter + louver grille | Right Cassette Bay.
                    HStack(alignment: .top, spacing: 11) {
                        VStack(spacing: 9) {
                            BraunAnalogVUMeter(
                                level: opening.splashMeterLevel,
                                backlit: opening.splashPlayPressed
                            )
                            .frame(width: 56, height: 40)

                            // Dieter Rams speaker/ventilation micro-grille slots.
                            VStack(spacing: 4) {
                                ForEach(0..<4, id: \.self) { _ in
                                    Capsule()
                                        .fill(Color.black.opacity(0.22))
                                        .frame(width: 48, height: 2.2)
                                        .overlay(alignment: .bottom) {
                                            Capsule()
                                                .fill(.white.opacity(0.35))
                                                .frame(height: 0.6)
                                        }
                                }
                            }
                            .padding(.top, 2)
                        }

                        // Recessed matte-graphite cassette bay with live spinning hubs.
                        BraunMiniCassetteBay(
                            spinStart: opening.splashSpinStart,
                            isPowered: opening.splashPlayPressed,
                            reducedMotion: reducedMotion
                        )
                        .frame(width: 133, height: 82)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(width: 228, height: 128)
        }
        .opacity(opening.splashAppeared ? 1 : 0)
    }
}

// MARK: - Analog VU Level Meter

private struct BraunAnalogVUMeter: View {
    let level: CGFloat
    let backlit: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: backlit
                            ? [Color(red: 0.99, green: 0.95, blue: 0.84), Color(red: 0.95, green: 0.89, blue: 0.74)]
                            : [Color(red: 0.86, green: 0.84, blue: 0.79), Color(red: 0.80, green: 0.78, blue: 0.73)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .animation(.easeOut(duration: 0.25), value: backlit)

            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.5, y: size.height * 1.05)
                let radius = size.height * 0.78

                // Graphite dB scale arc (-46° .. +14°).
                var normalArc = Path()
                normalArc.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(-136),
                    endAngle: .degrees(-76),
                    clockwise: false
                )
                context.stroke(normalArc, with: .color(.black.opacity(0.45)), lineWidth: 1.0)

                // Vermilion +0..+3 dB peak zone arc (+14° .. +44°).
                var peakArc = Path()
                peakArc.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(-74),
                    endAngle: .degrees(-46),
                    clockwise: false
                )
                context.stroke(peakArc, with: .color(Color(red: 0.84, green: 0.27, blue: 0.17)), lineWidth: 1.8)

                // Fine tick marks along the scale.
                var ticks = Path()
                for deg in stride(from: -134.0, through: -48.0, by: 14.3) {
                    let rad = deg * .pi / 180
                    let r0 = radius - 2.6
                    let r1 = radius + 2.2
                    ticks.move(to: CGPoint(x: center.x + cos(rad) * r0, y: center.y + sin(rad) * r0))
                    ticks.addLine(to: CGPoint(x: center.x + cos(rad) * r1, y: center.y + sin(rad) * r1))
                }
                context.stroke(ticks, with: .color(.black.opacity(0.35)), lineWidth: 0.7)
            }

            Text("VU")
                .font(.custom("GeistMono-Regular", fixedSize: 6.5))
                .tracking(1.0)
                .foregroundStyle(.black.opacity(0.45))
                .offset(y: 7)

            // Animated needle pivoting cleanly from bottom center.
            let needleAngle = -42.0 + Double(min(1, max(0, level))) * 74.0
            Rectangle()
                .fill(Color(red: 0.80, green: 0.23, blue: 0.14))
                .frame(width: 1.2, height: 29)
                .offset(y: -14.5)
                .rotationEffect(.degrees(needleAngle), anchor: .bottom)
                .offset(y: 17)

            // Matte pivot cap at bottom edge.
            Circle()
                .fill(Color(white: 0.18))
                .frame(width: 7, height: 7)
                .offset(y: 19)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.black.opacity(0.36), lineWidth: 0.9)
        }
    }
}

// MARK: - Recessed Matte-Graphite Mini Cassette Bay

private struct BraunMiniCassetteBay: View {
    let spinStart: Date?
    let isPowered: Bool
    let reducedMotion: Bool

    var body: some View {
        TimelineView(.animation(paused: spinStart == nil || reducedMotion)) { timeline in
            let degrees = hubRotationDegrees(at: timeline.date)
            ZStack {
                // Dark recessed deck cavity.
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.10), Color(white: 0.14)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Miniature graphite & ivory C60 cassette inside the bay.
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(red: 0.18, green: 0.19, blue: 0.21))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(.white.opacity(0.10), lineWidth: 0.6)
                        }

                    VStack(spacing: 6) {
                        // Top cream cassette label with vermilion accent stripe.
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(Color(red: 0.93, green: 0.90, blue: 0.84))
                            Rectangle()
                                .fill(Color(red: 0.85, green: 0.33, blue: 0.20))
                                .frame(height: 3.5)
                        }
                        .frame(height: 15)
                        .padding(.horizontal, 8)
                        .padding(.top, 7)

                        // Central dark tape window with dual 6-tooth spinning hubs.
                        ZStack {
                            Capsule()
                                .fill(Color(white: 0.08))
                                .frame(width: 84, height: 26)
                                .overlay {
                                    Capsule()
                                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.6)
                                }

                            // Oxide magnetic tape pack silhouette between hubs.
                            HStack(spacing: 24) {
                                MiniCassetteHub(rotation: degrees)
                                MiniCassetteHub(rotation: degrees * 1.06)
                            }
                        }

                        // Bottom trapezoidal guide rail detail.
                        HStack(spacing: 12) {
                            Circle().fill(Color.black.opacity(0.55)).frame(width: 4, height: 4)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.black.opacity(0.42))
                                .frame(width: 24, height: 3.5)
                            Circle().fill(Color.black.opacity(0.55)).frame(width: 4, height: 4)
                        }
                        .padding(.bottom, 5)
                    }
                }
                .padding(7)

                // Subtle smoked-glass diagonal reflection across the bay window.
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(isPowered ? 0.14 : 0.08), location: 0.0),
                        .init(color: .clear, location: 0.42),
                        .init(color: .white.opacity(0.05), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.55), lineWidth: 1.0)
            }
        }
    }

    /// Quadratic motor spin-up for the first `0.36s`, then smooth steady speed.
    private func hubRotationDegrees(at date: Date) -> Double {
        guard let spinStart, !reducedMotion else { return 0 }
        let t = max(0, date.timeIntervalSince(spinStart))
        let ramp: Double = 0.36
        let steadySpeed: Double = 340 // deg/sec
        if t <= ramp {
            return 0.5 * (steadySpeed / ramp) * t * t
        }
        return 0.5 * steadySpeed * ramp + steadySpeed * (t - ramp)
    }
}

private struct MiniCassetteHub: View {
    let rotation: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerR = size.width * 0.48
            let innerR = size.width * 0.25

            // Outer spool ring.
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - outerR, y: center.y - outerR, width: outerR * 2, height: outerR * 2)),
                with: .color(Color(red: 0.88, green: 0.86, blue: 0.82).opacity(0.88)),
                lineWidth: 2.0
            )

            // 6 precision hub drive teeth.
            for index in 0..<6 {
                let angle = (Double(index) * 60.0 + rotation) * .pi / 180.0
                let x0 = center.x + cos(angle) * innerR
                let y0 = center.y + sin(angle) * innerR
                let x1 = center.x + cos(angle) * (outerR - 0.5)
                let y1 = center.y + sin(angle) * (outerR - 0.5)
                var tooth = Path()
                tooth.move(to: CGPoint(x: x0, y: y0))
                tooth.addLine(to: CGPoint(x: x1, y: y1))
                context.stroke(tooth, with: .color(.white.opacity(0.90)), lineWidth: 1.8)
            }

            // Center spindle hole.
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - innerR * 0.72, y: center.y - innerR * 0.72, width: innerR * 1.44, height: innerR * 1.44)),
                with: .color(Color(white: 0.14))
            )
        }
        .frame(width: 21, height: 21)
    }
}
