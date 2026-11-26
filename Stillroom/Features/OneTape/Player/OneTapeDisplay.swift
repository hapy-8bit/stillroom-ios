import SwiftUI

/// Unified reflective monochrome LCD display router.
/// Every screen shares the same body-coordinated pale reflective LCD substrate
/// (`OneTapeLCDMaterial`), recessed glass shading, and smooth 90° orientation turn.
/// Only `.lcd` renders full track metadata; visual & character modes occupy the
/// full panel cleanly without overlapping typography.
struct OneTapeDisplay: View {
    let style: OneTapeAppearance.ScreenStyle
    var readout: OneTapePlaybackReadout = .empty
    var visualization: AudioVisualizationSignal? = nil
    var quarterTurns: Int = 0
    var lcdMaterial: OneTapeLCDMaterial = .original
    var isPreview: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var resolvedStyle: OneTapeAppearance.ScreenStyle { style.resolvedStyle }
    private var shouldAnimate: Bool { !reduceMotion && scenePhase == .active }

    var body: some View {
        ZStack {
            surfaceColor
            screenContent
            if resolvedStyle == .lcd || resolvedStyle == .fox {
                OneTapeLCDGlassOverlay()
            }
        }
        .modifier(OneTapeScreenTurn(
            angle: Double(quarterTurns) * 90,
            tallFraction: abs(quarterTurns % 2) == 1 ? 1 : 0))
        .frame(width: 264.39, height: 165.63)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 2.5))
        .accessibilityHidden(true)
        .animation(reduceMotion || scenePhase != .active ? nil
            : .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.32), value: quarterTurns)
    }

    @ViewBuilder
    private var screenContent: some View {
        if resolvedStyle == .lcd {
            OneTapeEmptyLCD(readout: readout, quarterTurns: quarterTurns, material: lcdMaterial)
        } else if resolvedStyle == .fox {
            OneTapeFoxScreen(readout: readout, material: lcdMaterial)
        } else if let program = OneTapeScreenShaderProgram(style: resolvedStyle) {
            OneTapeMetalScreenView(
                program: program,
                lcdMaterial: lcdMaterial,
                readout: readout,
                visualization: visualization,
                isPreview: isPreview,
                shouldAnimate: shouldAnimate
            )
        } else {
            OneTapeEmptyLCD(readout: readout, quarterTurns: quarterTurns, material: lcdMaterial)
        }
    }

    private var surfaceColor: Color {
        Color(red: lcdMaterial.background.red,
              green: lcdMaterial.background.green,
              blue: lcdMaterial.background.blue)
    }
}

/// Subtle physical recessed LCD glass shading shared across SwiftUI-drawn screens
/// (`Readout` & `Fox`) to match the Metal shaders' `finalizeLCD` border optics.
private struct OneTapeLCDGlassOverlay: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.065), location: 0.0),
                    .init(color: .clear, location: 0.08),
                    .init(color: .clear, location: 0.94),
                    .init(color: .white.opacity(0.045), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.05), location: 0.0),
                    .init(color: .clear, location: 0.05),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

/// Full-bleed monochrome reflective LCD character screen for the headphones fox.
/// Grooves while playing, nods idly when paused, and dozes off after 10 seconds paused.
private struct OneTapeFoxScreen: View {
    let readout: OneTapePlaybackReadout
    let material: OneTapeLCDMaterial

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var resumedAt = Date()
    @State private var elapsedBeforeResume = 0.0

    private var animates: Bool { !reduceMotion && scenePhase == .active }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !animates)) { timeline in
            let phase = reduceMotion ? 0 : elapsedBeforeResume
                + (animates ? max(0, timeline.date.timeIntervalSince(resumedAt)) : 0)
            OneTapeFoxDisplay(readout: readout, phase: phase, reducedMotion: reduceMotion)
                .scaleEffect(1.14)
        }
        .clipped()
        .background(
            Color(red: material.background.red,
                  green: material.background.green,
                  blue: material.background.blue)
        )
        .onChange(of: animates) { oldValue, newValue in
            if oldValue { elapsedBeforeResume += max(0, Date().timeIntervalSince(resumedAt)) }
            if newValue { resumedAt = Date() }
        }
        .onChange(of: readout.isPlaying) { _, _ in
            // Fresh idle countdown on pause so dozing starts cleanly after 10 seconds.
            elapsedBeforeResume = 0
            resumedAt = Date()
        }
    }
}

/// Self-contained vector fox frames mapped onto the reflective LCD glass.
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
