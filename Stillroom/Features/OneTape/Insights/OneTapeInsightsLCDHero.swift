import SwiftUI

/// Recessed reflective monochrome LCD hero panel for the Insights page.
/// Mirrors the physical player's `OneTapeLCDMaterial` optics and dot-matrix numerals,
/// pairing total listening time with real Compact Cassette travel physics (4.7625 cm/s).
struct OneTapeInsightsLCDHero: View {
    let snapshot: ListeningInsightsSnapshot
    let lcdMaterial: OneTapeLCDMaterial
    let isPlaying: Bool
    let isActive: Bool
    let revealTrigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var animatedSeconds: Double = 0
    @State private var blinkOn = true

    private var ink: Color {
        Color(red: lcdMaterial.ink.red, green: lcdMaterial.ink.green, blue: lcdMaterial.ink.blue)
    }

    private var surface: Color {
        Color(red: lcdMaterial.background.red, green: lcdMaterial.background.green, blue: lcdMaterial.background.blue)
    }

    private var shouldSpinReels: Bool {
        isPlaying && isActive && !reduceMotion && scenePhase == .active
    }

    private var shouldBlinkEmpty: Bool {
        !snapshot.hasListeningData && isActive && !reduceMotion && scenePhase == .active
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                surface
                lcdInterior
                lcdGlassBevel
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.black.opacity(0.45), lineWidth: 1.0)
            }
            .padding(8)
        }
        .background(
            LinearGradient(
                colors: [Color(white: 0.105), Color(white: 0.068)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 19, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.11), .white.opacity(0.03), .black.opacity(0.40)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: .black.opacity(0.42), radius: 14, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("insights.lcdHero")
        .onAppear { syncCounter(resetFromZero: true) }
        .onChange(of: snapshot.range) { _, _ in syncCounter(resetFromZero: false) }
        .onChange(of: snapshot.totalSeconds) { _, _ in syncCounter(resetFromZero: false) }
        .onChange(of: revealTrigger) { _, _ in syncCounter(resetFromZero: true) }
        .task(id: shouldBlinkEmpty) {
            blinkOn = true
            guard shouldBlinkEmpty else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(650))
                    guard !Task.isCancelled else { return }
                    blinkOn.toggle()
                } catch { return }
            }
        }
    }

    private var lcdInterior: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("LOG · \(snapshot.range.lcdCode)")
                    .font(.custom("GeistMono-Regular", size: 11.5))
                    .tracking(1.1)
                    .foregroundStyle(ink.opacity(0.72))

                Spacer()

                HStack(spacing: 7) {
                    OneTapeInsightsMiniReelTransport(ink: ink, spinning: shouldSpinReels)
                        .frame(width: 34, height: 14)
                    Text(isPlaying ? "LIVE" : (snapshot.hasListeningData ? "TAPE" : "IDLE"))
                        .font(.custom("GeistMono-Regular", size: 10.5))
                        .tracking(0.8)
                        .foregroundStyle(ink.opacity(isPlaying ? 0.92 : 0.56))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                OneTapeInsightsAnimatedCounter(
                    seconds: animatedSeconds,
                    hasData: snapshot.hasListeningData,
                    ink: ink.opacity(snapshot.hasListeningData || blinkOn ? 0.94 : 0.22)
                )
                .frame(height: 30, alignment: .leading)

                Text(snapshot.hasListeningData ? "累计真实聆听时长" : "装入磁带并播放后开始计录")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(ink.opacity(0.62))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(c60Readout(for: animatedSeconds))
                        .font(.custom("GeistMono-Regular", size: 12))
                        .foregroundStyle(ink.opacity(0.88))
                        .contentTransition(.numericText())
                    Spacer()
                    Text(metersReadout(for: animatedSeconds))
                        .font(.custom("GeistMono-Regular", size: 12))
                        .foregroundStyle(ink.opacity(0.72))
                        .contentTransition(.numericText())
                }

                OneTapeInsightsTapeRuler(
                    fraction: tapeCycleFraction(for: animatedSeconds),
                    ink: ink
                )
                .frame(height: 15)

                HStack {
                    Text("0")
                    Spacer()
                    Text("15")
                    Spacer()
                    Text("30")
                    Spacer()
                    Text("45")
                    Spacer()
                    Text("60m")
                }
                .font(.custom("GeistMono-Regular", size: 9))
                .foregroundStyle(ink.opacity(0.48))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var lcdGlassBevel: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.08), location: 0.0),
                    .init(color: .clear, location: 0.10),
                    .init(color: .clear, location: 0.92),
                    .init(color: .white.opacity(0.06), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.055), location: 0.0),
                    .init(color: .clear, location: 0.06),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .allowsHitTesting(false)
    }

    private func syncCounter(resetFromZero: Bool) {
        let target = snapshot.totalSeconds
        if reduceMotion {
            animatedSeconds = target
            return
        }
        if resetFromZero {
            animatedSeconds = 0
        }
        withAnimation(.timingCurve(0.18, 0.85, 0.25, 1.0, duration: 0.48)) {
            animatedSeconds = target
        }
    }

    private func c60Readout(for seconds: Double) -> String {
        guard snapshot.hasListeningData else { return "C60 × 0.0 盘" }
        let count = seconds / ListeningLedger.c60DurationSeconds
        return String(format: "C60 × %.1f 盘", count)
    }

    private func metersReadout(for seconds: Double) -> String {
        guard snapshot.hasListeningData else { return "0.0 m 走带" }
        let meters = seconds * ListeningLedger.tapeSpeedMetersPerSecond
        if meters >= 1000 {
            return String(format: "%.2f km 走带", meters / 1000.0)
        }
        return String(format: "%.1f m 走带", meters)
    }

    private func tapeCycleFraction(for seconds: Double) -> Double {
        guard seconds > 0 else { return 0 }
        let rem = seconds.truncatingRemainder(dividingBy: ListeningLedger.c60DurationSeconds)
        if rem == 0 { return 1 }
        return max(0.025, rem / ListeningLedger.c60DurationSeconds)
    }

    private var accessibilitySummary: String {
        guard snapshot.hasListeningData else {
            return "\(snapshot.range.title) 暂无真实聆听记录"
        }
        let mins = Int(snapshot.totalSeconds / 60)
        return "\(snapshot.range.title) 累计聆听 \(mins) 分钟，折合 \(String(format: "%.1f", snapshot.c60TapeCount)) 盘 C60 磁带"
    }
}

/// Mechanical roll-counter wrapper animating the pixel dot-matrix readout cleanly.
private struct OneTapeInsightsAnimatedCounter: View, Animatable {
    var seconds: Double
    let hasData: Bool
    let ink: Color

    var animatableData: Double {
        get { seconds }
        set { seconds = newValue }
    }

    var body: some View {
        OneTapeInsightsPixelText(text: formattedLabel, cell: 3.7, color: ink)
    }

    private var formattedLabel: String {
        guard hasData else { return "--:--" }
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, secs)
        }
        return String(format: "0:%02d", secs)
    }
}

/// Square-pixel 5×7 dot-matrix glyphs matching the player's `OneTapeEmptyLCD` digits.
private struct OneTapeInsightsPixelText: View {
    let text: String
    let cell: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, _ in
            var cursorX: CGFloat = 0
            for character in text {
                let glyph = Self.glyph(character)
                for (row, bits) in glyph.rows.enumerated() {
                    for column in 0..<glyph.width where bits & (1 << (glyph.width - 1 - column)) != 0 {
                        let rect = CGRect(
                            x: cursorX + CGFloat(column) * cell,
                            y: CGFloat(row) * cell,
                            width: cell * 0.86,
                            height: cell * 0.86
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
                let advance = character == " " ? 2.4 : CGFloat(glyph.width) + 1.25
                cursorX += advance * cell
            }
        }
        .accessibilityHidden(true)
    }

    private static func glyph(_ character: Character) -> (width: Int, rows: [Int]) {
        switch character {
        case "0": return (5, [14, 17, 17, 17, 17, 17, 14])
        case "1": return (5, [4, 12, 4, 4, 4, 4, 14])
        case "2": return (5, [14, 17, 1, 6, 8, 16, 31])
        case "3": return (5, [14, 17, 1, 6, 1, 17, 14])
        case "4": return (5, [2, 6, 10, 18, 31, 2, 2])
        case "5": return (5, [31, 16, 30, 1, 1, 17, 14])
        case "6": return (5, [6, 8, 16, 30, 17, 17, 14])
        case "7": return (5, [31, 1, 2, 4, 8, 8, 8])
        case "8": return (5, [14, 17, 17, 14, 17, 17, 14])
        case "9": return (5, [14, 17, 17, 15, 1, 2, 12])
        case ":": return (2, [0, 3, 3, 0, 3, 3, 0])
        case "-": return (4, [0, 0, 0, 15, 0, 0, 0])
        case "h": return (4, [8, 8, 14, 9, 9, 9, 9])
        case "m": return (5, [0, 0, 26, 21, 21, 21, 21])
        case "s": return (4, [0, 0, 7, 8, 6, 1, 14])
        default: return (2, [0, 0, 0, 0, 0, 0, 0])
        }
    }
}

/// Miniature LCD twin-reel indicator that spins slowly while the shared player is playing.
private struct OneTapeInsightsMiniReelTransport: View {
    let ink: Color
    let spinning: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !spinning)) { timeline in
            let angle = spinning ? timeline.date.timeIntervalSinceReferenceDate * 1.45 : 0
            Canvas { context, size in
                let r = min(size.height * 0.45, 5.8)
                let left = CGPoint(x: r + 1.2, y: size.height * 0.5)
                let right = CGPoint(x: size.width - r - 1.2, y: size.height * 0.5)

                // Connecting magnetic tape bridge.
                var bridge = Path()
                bridge.move(to: CGPoint(x: left.x, y: left.y + r))
                bridge.addLine(to: CGPoint(x: right.x, y: right.y + r))
                context.stroke(bridge, with: .color(ink.opacity(0.45)), lineWidth: 0.9)

                for (index, center) in [left, right].enumerated() {
                    let phase = angle * (index == 0 ? 1.0 : 1.18)
                    let outer = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                    context.stroke(outer, with: .color(ink.opacity(0.75)), lineWidth: 1.05)

                    for spoke in 0..<3 {
                        let theta = phase + Double(spoke) * (2.0 * .pi / 3.0)
                        var line = Path()
                        line.move(to: center)
                        line.addLine(to: CGPoint(x: center.x + cos(theta) * (r * 0.84),
                                                 y: center.y + sin(theta) * (r * 0.84)))
                        context.stroke(line, with: .color(ink.opacity(0.85)), lineWidth: 1.0)
                    }
                    let hub = Path(ellipseIn: CGRect(x: center.x - 1.3, y: center.y - 1.3, width: 2.6, height: 2.6))
                    context.fill(hub, with: .color(ink))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Segmented monochrome LCD cassette travel bar mirroring the player's progress strip.
private struct OneTapeInsightsTapeRuler: View {
    let fraction: Double
    let ink: Color

    var body: some View {
        Canvas { context, size in
            let segments = 32
            let gap: CGFloat = 2.0
            let cellWidth = max(2, (size.width - CGFloat(segments - 1) * gap) / CGFloat(segments))
            let litCount = Int((max(0, min(1, fraction)) * Double(segments)).rounded(.up))

            for index in 0..<segments {
                let x = CGFloat(index) * (cellWidth + gap)
                let isMajor = index % 8 == 0
                let barHeight = isMajor ? size.height : size.height * 0.72
                let y = size.height - barHeight
                let rect = CGRect(x: x, y: y, width: cellWidth, height: barHeight)
                let lit = fraction > 0 && index < litCount
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 0.9),
                    with: .color(ink.opacity(lit ? 0.86 : 0.14))
                )
            }
        }
        .accessibilityHidden(true)
    }
}
