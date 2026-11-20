import SwiftUI
import Combine

/// The frame receives media metadata at its normal update rate. Only the meter
/// artwork subscribes to PCM, so other designs never observe analyzer traffic.
struct OneTapeApprovedDisplay: View {
    let style: OneTapeAppearance.ScreenStyle
    let readout: OneTapePlaybackReadout
    let visualization: AudioVisualizationSignal?

    var body: some View {
        OneTapeApprovedScreenFrame(style: style, readout: readout) {
            if style == .meters {
                if let visualization {
                    OneTapeApprovedMeterDisplay(readout: readout, signal: visualization)
                } else {
                    OneTapeLiveScreenArtwork(style: .meters, phase: 0, readout: readout,
                                             response: .silent, signalAvailable: false)
                }
            } else {
                OneTapeApprovedAmbientDisplay(style: style, readout: readout)
            }
        }
    }
}

private struct OneTapeApprovedAmbientDisplay: View {
    let style: OneTapeAppearance.ScreenStyle
    let readout: OneTapePlaybackReadout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var clock = OneTapeScreenMotionClock()

    private var runs: Bool {
        readout.screenState.allowsMotion && !reduceMotion && scenePhase == .active
    }

    private var selectionKey: String {
        readout.trackID.isEmpty ? readout.title + "\u{0}" + readout.artist + "\(readout.trackIndex)"
            : readout.trackID
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !runs)) { timeline in
            let phase = reduceMotion ? 0 : clock.phase(at: timeline.date.timeIntervalSinceReferenceDate)
            OneTapeLiveScreenArtwork(style: style, phase: phase, readout: readout,
                                     response: .silent, signalAvailable: true)
                .environment(\.oneTapePhotoFrameMode, .playback(running: runs))
        }
        .onAppear { clock.setRunning(runs, at: Date.timeIntervalSinceReferenceDate) }
        .onChange(of: runs, initial: true) { _, running in
            clock.setRunning(running, at: Date.timeIntervalSinceReferenceDate)
        }
        .onChange(of: selectionKey) { _, _ in
            // New text starts as an intact glyph. The decorative photo phase
            // otherwise continues across track changes and never seeks media.
            if style == .name {
                clock.reset(at: Date.timeIntervalSinceReferenceDate, running: runs)
            }
        }
        .onDisappear { clock.setRunning(false, at: Date.timeIntervalSinceReferenceDate) }
    }
}

private struct OneTapeApprovedMeterDisplay: View {
    let readout: OneTapePlaybackReadout
    let signal: AudioVisualizationSignal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var dynamics = OneTapeScreenDynamics()
    @State private var response = OneTapeScreenResponse.silent
    @State private var signalAvailable = true
    @State private var lastReceivedAt = Date()

    private var acceptsMeasuredFrames: Bool {
        readout.screenState.allowsMotion && !reduceMotion && scenePhase == .active
    }
    private var selectionKey: String {
        readout.trackID.isEmpty ? readout.title + "\u{0}" + readout.artist + "\(readout.trackIndex)"
            : readout.trackID
    }

    var body: some View {
        OneTapeLiveScreenArtwork(style: .meters, phase: 0, readout: readout,
            response: acceptsMeasuredFrames ? response : .silent, signalAvailable: signalAvailable)
        .onReceive(signal.$frame.throttle(for: .milliseconds(50), scheduler: RunLoop.main,
                                          latest: true)) { frame in
            let now = Date()
            let elapsed = now.timeIntervalSince(lastReceivedAt)
            lastReceivedAt = now
            signalAvailable = frame.status != .unsupported
            response = dynamics.consume(rms: frame.rms, peak: frame.peak,
                bands: frame.bands, waveform: frame.waveform,
                active: acceptsMeasuredFrames && frame.status == .active, elapsed: elapsed)
        }
        .onChange(of: acceptsMeasuredFrames) { _, active in
            if !active { clearMeasuredFrames() }
        }
        .onChange(of: selectionKey) { _, _ in clearMeasuredFrames() }
        .onDisappear { clearMeasuredFrames() }
    }

    private func clearMeasuredFrames() {
        dynamics = OneTapeScreenDynamics()
        response = .silent
        signalAvailable = true
        lastReceivedAt = Date()
    }
}
