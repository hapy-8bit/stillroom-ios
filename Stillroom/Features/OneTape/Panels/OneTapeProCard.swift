import SwiftUI

/// Gallery-grade editorial pass card for One Cassette Pro. Styled after
/// 1980s Japanese Type IV metal-tape J-cards & Dieter Rams industrial hardware:
/// brushed obsidian slate, warm tungsten rim-light, precision architectural
/// spool blueprint bleeding off the right edge, `InstrumentSerif-Italic` title,
/// and a tactile warm-ivory primary pill instead of a generic neon CTA box.
struct OneTapeProCard: View {
    let isPro: Bool
    let proPrice: String?
    let proStatus: String
    let purchaseIssue: String?
    let purchasesBusy: Bool
    let isRestoringPurchases: Bool
    let onStudio: () -> Void
    let onRestorePurchases: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let warmGold = Color(red: 0.87, green: 0.67, blue: 0.45)
    private let ivory = Color(red: 0.95, green: 0.92, blue: 0.87)
    private let copper = Color(red: 0.82, green: 0.45, blue: 0.25)

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Machined obsidian base with warm tungsten gallery spotlight.
            cardBackdrop

            // Architectural cassette-spool line art bleeding subtly off right edge.
            ArchitecturalSpoolBlueprint(
                accent: warmGold,
                isPro: isPro,
                reducedMotion: reduceMotion
            )
            .allowsHitTesting(false)

            // Left oxidized-bronze obi-strip hairline accent.
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [warmGold.opacity(0.85), copper.opacity(0.45), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 2.2)
                .padding(.vertical, 18)
                .padding(.leading, 1)
                Spacer()
            }
            .allowsHitTesting(false)

            // Foreground editorial content & gallery action footer.
            VStack(alignment: .leading, spacing: 0) {
                // Micro-spec header row
                HStack(alignment: .center, spacing: 8) {
                    Text("STUDIO EDITION · TYPE IV")
                        .font(.custom("GeistMono-Regular", fixedSize: 9.5))
                        .tracking(2.2)
                        .foregroundStyle(warmGold.opacity(0.76))

                    Spacer(minLength: 6)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(isPro ? Color(red: 0.56, green: 0.86, blue: 0.60) : warmGold)
                            .frame(width: 5, height: 5)
                            .shadow(
                                color: (isPro ? Color(red: 0.56, green: 0.86, blue: 0.60) : warmGold).opacity(0.75),
                                radius: 3
                            )
                        Text(isPro ? "PRO · 已解锁" : OneTapePaymentPlan.billingLabel)
                            .font(.custom("GeistMono-Regular", fixedSize: 9.5))
                            .tracking(1.0)
                            .foregroundStyle(.white.opacity(0.66))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.055), in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.09), lineWidth: 0.5)
                    }
                    .accessibilityIdentifier("settings.proStatus")
                }

                // Editorial serif hero title
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("One Cassette")
                        .font(.custom("InstrumentSerif-Italic", size: 32))
                        .tracking(-0.5)
                        .foregroundStyle(ivory)
                    Text("Pro")
                        .font(.custom("InstrumentSerif-Italic", size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ivory, warmGold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .padding(.top, 10)

                Text(isPro ? "全部典藏磁带、材质与定制权益已开启" : "全系磁带壳体、机身材质、动态屏幕与印花")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(1)
                    .padding(.top, 3)

                // Hairline rule separating artwork face from tactile footer
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .white.opacity(0.04), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 0.6)
                    .padding(.top, 16)
                    .padding(.bottom, 13)

                // Footer action bar: matte warm-ivory pill + quiet mono restore link
                HStack(spacing: 12) {
                    Button(action: onStudio) {
                        HStack(spacing: 6) {
                            Text(primaryButtonTitle)
                                .font(.system(size: 13.5, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color(red: 0.08, green: 0.075, blue: 0.07))
                        .padding(.horizontal, 18)
                        .frame(minHeight: 38)
                        .background(
                            LinearGradient(
                                colors: [ivory, Color(red: 0.89, green: 0.85, blue: 0.78)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: Capsule()
                        )
                        .shadow(color: .black.opacity(0.32), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.studio")

                    Spacer(minLength: 4)

                    Button(action: onRestorePurchases) {
                        HStack(spacing: 5) {
                            if isRestoringPurchases {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(warmGold)
                            }
                            Text(isRestoringPurchases ? "恢复中" : "恢复购买")
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.56))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 38)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(purchasesBusy)
                    .accessibilityIdentifier("settings.restorePurchases")
                }

                if let purchaseIssue {
                    Text(purchaseIssue)
                        .font(.system(size: 11.5))
                        .foregroundStyle(warmGold.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                } else if !isPro, proStatus == "正在检查购买状态" {
                    Text("正在同步 App Store 购买状态…")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.34))
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: warmGold.opacity(0.34), location: 0.0),
                            .init(color: .white.opacity(0.10), location: 0.45),
                            .init(color: .white.opacity(0.05), location: 1.0)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    ),
                    lineWidth: 0.75
                )
        }
        .shadow(color: .black.opacity(0.38), radius: 16, y: 8)
    }

    private var primaryButtonTitle: String {
        if isPro { return "浏览全部外观" }
        if let proPrice, !proPrice.isEmpty { return "升级 Pro · \(proPrice)" }
        return "探索 Pro 权益"
    }

    private var cardBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.105, blue: 0.10),
                    Color(red: 0.075, green: 0.072, blue: 0.070)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Whisper-soft tungsten gallery light pool from upper right.
            RadialGradient(
                colors: [
                    warmGold.opacity(0.16),
                    copper.opacity(0.05),
                    .clear
                ],
                center: UnitPoint(x: 0.90, y: 0.12),
                startRadius: 6,
                endRadius: 200
            )

            // Ultra-delicate brushed aluminum horizontal micro-grain.
            Canvas { context, size in
                var grain = Path()
                var y: CGFloat = 2
                while y < size.height {
                    grain.move(to: CGPoint(x: 0, y: y))
                    grain.addLine(to: CGPoint(x: size.width, y: y))
                    y += 3.5
                }
                context.stroke(grain, with: .color(.white.opacity(0.022)), lineWidth: 0.5)
            }
        }
    }
}

/// Precision drafted cassette-spool architectural line art in the right field
/// of the Pro card, rotating meditatively at 6°/s (paused under Reduce Motion).
private struct ArchitecturalSpoolBlueprint: View {
    let accent: Color
    let isPro: Bool
    let reducedMotion: Bool

    var body: some View {
        TimelineView(.animation(paused: reducedMotion)) { timeline in
            let angle = reducedMotion ? 14.0 : timeline.date.timeIntervalSinceReferenceDate * 6.0
            Canvas { context, size in
                let center = CGPoint(x: size.width - 26, y: size.height * 0.44)
                let outerR: CGFloat = 78
                let tapePackR: CGFloat = 56
                let hubR: CGFloat = 23
                let spindleR: CGFloat = 11

                // Concentric precision drafting rings
                let rings: [(CGFloat, Double, [CGFloat])] = [
                    (outerR, 0.10, [3, 4]),
                    (tapePackR, 0.16, []),
                    (40, 0.09, []),
                    (hubR, 0.24, [])
                ]
                for (r, alpha, dash) in rings {
                    let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                    let style = dash.isEmpty
                        ? StrokeStyle(lineWidth: 0.7)
                        : StrokeStyle(lineWidth: 0.6, dash: dash)
                    context.stroke(Path(ellipseIn: rect), with: .color(accent.opacity(alpha)), style: style)
                }

                // Sweeping oxide tape-ribbon tangent curve exiting toward bottom-left
                var ribbon = Path()
                ribbon.move(to: CGPoint(x: center.x - 16, y: center.y + tapePackR - 2))
                ribbon.addQuadCurve(
                    to: CGPoint(x: size.width * 0.36, y: size.height + 6),
                    control: CGPoint(x: center.x - 62, y: size.height * 0.86)
                )
                context.stroke(ribbon, with: .color(accent.opacity(0.18)), lineWidth: 0.8)

                // Slow-turning 6-tooth aluminum reel hub + fine radial spokes
                var spokes = Path()
                for idx in 0..<6 {
                    let rad = (Double(idx) * 60.0 + angle) * .pi / 180.0
                    let c = CGFloat(cos(rad))
                    let s = CGFloat(sin(rad))
                    spokes.move(to: CGPoint(x: center.x + c * spindleR, y: center.y + s * spindleR))
                    spokes.addLine(to: CGPoint(x: center.x + c * (hubR - 1), y: center.y + s * (hubR - 1)))

                    // Delicate calibration tick on outer tape flange
                    if idx % 2 == 0 {
                        spokes.move(to: CGPoint(x: center.x + c * (tapePackR - 5), y: center.y + s * (tapePackR - 5)))
                        spokes.addLine(to: CGPoint(x: center.x + c * (tapePackR + 4), y: center.y + s * (tapePackR + 4)))
                    }
                }
                context.stroke(
                    spokes,
                    with: .color(accent.opacity(isPro ? 0.34 : 0.26)),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )

                // Center spindle circle
                let spindleRect = CGRect(
                    x: center.x - spindleR,
                    y: center.y - spindleR,
                    width: spindleR * 2,
                    height: spindleR * 2
                )
                context.stroke(Path(ellipseIn: spindleRect), with: .color(.white.opacity(0.18)), lineWidth: 0.8)
            }
        }
    }
}
