import SwiftUI

/// Navigation/row symbols use an aspect-fitted logical viewport. Keeping the
/// outline inside it avoids a thicker stroke silently enlarging the glyph.
struct OneTapeCassetteIcon: View {
    var reelAngle: Double = 0
    var reelsOpen = true

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, geometry.size.height * 44 / 32)
            let height = width * 32 / 44
            ZStack {
                RoundedRectangle(cornerRadius: width * 0.1)
                    .strokeBorder(lineWidth: width * 0.06)
                HStack(spacing: width * 0.1) {
                    ForEach(0..<2) { _ in
                        ZStack {
                            Circle().strokeBorder(lineWidth: width * 0.05)
                            ForEach(0..<3) { index in
                                Capsule().frame(width: width * 0.035, height: height * 0.065)
                                    .offset(y: -width * 0.08)
                                    .rotationEffect(.degrees(Double(index) * 120))
                            }
                            .opacity(reelsOpen ? 1 : 0)
                        }
                        .rotationEffect(.degrees(reelAngle))
                        .scaleEffect(x: 1, y: reelsOpen ? 1 : 0.13)
                        .frame(width: width * 0.26, height: width * 0.26)
                    }
                }.offset(y: -height * 0.1)
                Path { path in
                    path.move(to: CGPoint(x: width * 0.2, y: height * 0.91))
                    path.addLine(to: CGPoint(x: width * 0.29, y: height * 0.71))
                    path.addLine(to: CGPoint(x: width * 0.71, y: height * 0.71))
                    path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.91))
                }.stroke(style: StrokeStyle(lineWidth: width * 0.05, lineCap: .round, lineJoin: .round))
            }
            .frame(width: width, height: height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }.accessibilityHidden(true)
    }
}

/// The row reads engine state; this paused visual clock never owns media time.
/// Its animation schedule stops for paused music, hidden pages and background.
struct OneTapeSongPlaybackIcon: View {
    let isPlaying: Bool
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24,
            paused: !isPlaying || !isActive || reduceMotion || scenePhase != .active)) { timeline in
            let angle = reduceMotion ? 0 : (timeline.date.timeIntervalSinceReferenceDate * 120)
                .truncatingRemainder(dividingBy: 360)
            OneTapeCassetteIcon(reelAngle: angle, reelsOpen: isPlaying)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isPlaying)
        .accessibilityHidden(true)
    }
}

struct OneTapeLibraryIcon: View {
    var lift: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, geometry.size.height * 34 / 28)
            let scale = width / 34
            ZStack(alignment: .topLeading) {
                ForEach(0..<3) { index in
                    spine(scale: scale)
                        .frame(width: 4.4 * scale, height: 21.8 * scale)
                        .offset(x: (2 + CGFloat(index) * 6.4) * scale,
                                y: (1.8 - lift * (index == 1 ? 4.5 : 2.5)) * scale)
                }
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: 21.7 * scale, y: 2.3 * scale))
                        path.addLine(to: CGPoint(x: 26 * scale, y: 1.2 * scale))
                        path.addLine(to: CGPoint(x: 31.7 * scale, y: 22.8 * scale))
                        path.addLine(to: CGPoint(x: 27.4 * scale, y: 23.9 * scale))
                        path.closeSubpath()
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.8 * scale, lineCap: .round, lineJoin: .round))
                    Path { path in
                        path.move(to: CGPoint(x: 24.9 * scale, y: 5.7 * scale))
                        path.addLine(to: CGPoint(x: 25.6 * scale, y: 8.3 * scale))
                        path.move(to: CGPoint(x: 28.5 * scale, y: 19.4 * scale))
                        path.addLine(to: CGPoint(x: 29 * scale, y: 21.2 * scale))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.2 * scale, lineCap: .round))
                }
                .frame(width: width, height: 28 * scale)
                .rotationEffect(.degrees(-lift * 7), anchor: UnitPoint(x: 0.83, y: 0.85))
                Path { path in
                    path.move(to: CGPoint(x: scale, y: 26.5 * scale))
                    path.addLine(to: CGPoint(x: 33 * scale, y: 26.5 * scale))
                }
                .stroke(style: StrokeStyle(lineWidth: 1.8 * scale, lineCap: .round))
            }
            .frame(width: width, height: 28 * scale)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }.accessibilityHidden(true)
    }

    private func spine(scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 0.7 * scale)
            .stroke(lineWidth: 1.8 * scale)
            .overlay {
                Path { path in
                    path.move(to: CGPoint(x: 2.2 * scale, y: 3.4 * scale))
                    path.addLine(to: CGPoint(x: 2.2 * scale, y: 6.2 * scale))
                    path.move(to: CGPoint(x: 2.2 * scale, y: 16 * scale))
                    path.addLine(to: CGPoint(x: 2.2 * scale, y: 18.3 * scale))
                }
                .stroke(style: StrokeStyle(lineWidth: 1.2 * scale, lineCap: .round))
            }
    }
}

/// A tap animates the cassette hubs or individual case spines, including taps
/// on the selected page. This visual phase never owns playback or a timer.
struct OneTapeNavigationGlyph: View {
    enum Kind { case player, library, insights }
    let kind: Kind
    let activation: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            glyph(phase: 0)
        } else {
            switch kind {
            case .player, .library:
                glyph(phase: 0)
                    .phaseAnimator([0.0, 1.0, 0.0], trigger: activation) { _, phase in
                        glyph(phase: phase)
                            .scaleEffect(1 + phase * 0.14)
                            .offset(y: -phase * 3)
                    } animation: { phase in
                        phase == 1 ? .spring(duration: 0.22, bounce: 0.12)
                            : .spring(duration: 0.38, bounce: 0.3)
                    }
            case .insights:
                glyph(phase: 0).symbolEffect(.bounce.byLayer, value: activation)
            }
        }
    }

    @ViewBuilder private func glyph(phase: Double) -> some View {
        switch kind {
        case .player:
            OneTapeCassetteIcon(reelAngle: phase * 60)
        case .library:
            OneTapeLibraryIcon(lift: phase * 1.4)
        case .insights:
            Image(systemName: "chart.bar.fill")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.monochrome)
                .accessibilityHidden(true)
        }
    }
}
