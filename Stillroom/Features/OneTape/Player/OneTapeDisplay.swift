import SwiftUI

/// Available designs share the same live metadata. Legacy stored choices resolve
/// at this boundary without rewriting the user's saved appearance record.
struct OneTapeDisplay: View {
    let style: OneTapeAppearance.ScreenStyle
    var readout: OneTapePlaybackReadout = .empty
    var visualization: AudioVisualizationSignal? = nil
    var quarterTurns: Int = 0
    var lcdMaterial: OneTapeLCDMaterial = .original
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private var resolvedStyle: OneTapeAppearance.ScreenStyle { style.resolvedStyle }

    var body: some View {
        Group {
            if resolvedStyle == .lcd {
                OneTapeEmptyLCD(readout: readout, quarterTurns: quarterTurns, material: lcdMaterial)
            } else if resolvedStyle == .fox {
                OneTapeScreenFrame(style: .fox, readout: readout) {
                    OneTapeAnimatedScreen(style: .fox, readout: readout, response: .silent)
                }
            } else {
                OneTapeApprovedDisplay(style: resolvedStyle, readout: readout,
                                       visualization: visualization)
            }
        }
        .modifier(OneTapeScreenTurn(
            angle: Double(quarterTurns) * 90,
            tallFraction: abs(quarterTurns % 2) == 1 ? 1 : 0))
        .frame(width: 264.39, height: 165.63)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 2.5))
        .accessibilityHidden(true)
        .animation(reduceMotion || scenePhase != .active ? nil
            : .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.32), value: quarterTurns)
    }

    private var surface: Color {
        resolvedStyle == .lcd
            ? Color(red: lcdMaterial.background.red, green: lcdMaterial.background.green,
                    blue: lcdMaterial.background.blue)
            : Color(white: 0.035)
    }
}

/// One presentation pair drives the logical proposal and the rigid rotation.
/// Intermediate proposals reflow glyph positions, rather than stretching a
/// bitmap or swapping an entire layout after an asynchronous blackout.
struct OneTapeScreenTurn: AnimatableModifier {
    var angle: Double
    var tallFraction: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { .init(angle, tallFraction) }
        set { angle = newValue.first; tallFraction = newValue.second }
    }

    func body(content: Content) -> some View {
        let geometry = OneTapeScreenLayoutGeometry(fraction: tallFraction)
        content
            // Positions already receive presentation geometry each frame;
            // a second implicit child animation would trail that geometry.
            .transaction { $0.animation = nil }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .rotationEffect(.degrees(angle))
    }
}

private struct OneTapeAnimatedScreen: View {
    let style: OneTapeAppearance.ScreenStyle
    let readout: OneTapePlaybackReadout
    let response: OneTapeScreenResponse
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var resumedAt = Date()
    @State private var elapsedBeforeResume = 0.0

    // A paused material holds its visual phase. The fox keeps its quiet idle /
    // sleep states. Neither behavior advances media seconds or invents PCM.
    private var animates: Bool {
        !reduceMotion && scenePhase == .active && (readout.isPlaying || style == .fox)
    }

    private var usesAmbientClock: Bool {
        switch style {
        case .fox, .fluid, .water, .dunes, .iron, .ink, .rain, .trails: true
        default: false
        }
    }

    var body: some View {
        ZStack {
            Color(red: 218 / 255, green: 223 / 255, blue: 224 / 255)
            if usesAmbientClock {
                TimelineView(.animation(minimumInterval: 1 / 20, paused: !animates)) { timeline in
                    // Ambient art has its own clock. Scope, meters and the
                    // waterfall never synthesize sound from this phase.
                    let phase = reduceMotion ? 0 : elapsedBeforeResume
                        + (animates ? max(0, timeline.date.timeIntervalSince(resumedAt)) : 0)
                    if style == .fox {
                        OneTapeFoxDisplay(readout: readout, phase: phase, reducedMotion: reduceMotion)
                    } else {
                        OneTapeScreenCanvas(style: style, response: response, phase: phase)
                    }
                }
            } else if style == .name {
                OneTapeNameSand(readout: readout, response: response)
            } else {
                OneTapeScreenCanvas(style: style, response: response)
            }
        }
        .onChange(of: animates) { oldValue, newValue in
            if oldValue { elapsedBeforeResume += max(0, Date().timeIntervalSince(resumedAt)) }
            if newValue { resumedAt = Date() }
        }
        .onChange(of: style) { _, _ in resetVisualClock() }
        .onChange(of: readout.isPlaying) { _, _ in
            // The character starts a fresh idle interval on pause; materials
            // instead retain their phase so their surfaces do not jump.
            if style == .fox { resetVisualClock() }
        }
    }

    private func resetVisualClock() {
        elapsedBeforeResume = 0
        resumedAt = Date()
    }
}

/// Actual offline Rive path geometry, rewritten as self-contained vector frames.
/// Playback chooses the native state; original beat accents/mixing are not claimed.
private struct OneTapeFoxDisplay: View {
    let readout: OneTapePlaybackReadout
    let phase: Double
    let reducedMotion: Bool

    private var asset: String {
        let state: String
        let frames: Int
        let time: Double
        if readout.isPlaying && !reducedMotion {
            state = "Groove"
            frames = 20
            time = phase
        } else if !reducedMotion && phase >= 10 {
            state = "Sleep"
            frames = 80
            time = phase - 10
        } else {
            state = "Idle"
            frames = 60
            time = reducedMotion ? 0 : phase
        }
        let index = Int(max(0, time) * 20) % frames
        return "OneTapeFox\(state)" + String(format: "%02d", index)
    }

    var body: some View {
        Image(asset)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transaction { $0.animation = nil }
    }
}
