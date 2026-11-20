import SwiftUI

/// A cancellable visual clock, separate from the AVPlayer media clock. Pausing,
/// leaving the scene and Reduce Motion stop display work without seeking audio.
struct OneTapeReelMotion<Content: View>: View {
    private struct Input: Equatable {
        let rate: Double
        let progress: Double
        let layout: OneTapeReelKinematics.Layout
    }

    let rate: Double
    let progress: Double
    var layout: OneTapeReelKinematics.Layout = .transport
    @ViewBuilder let content: (OneTapeReelKinematics.Frame) -> Content
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion = OneTapeReelKinematics()

    private var desiredRate: Double { scenePhase == .active && !reduceMotion ? rate : 0 }
    private var input: Input { Input(rate: desiredRate, progress: progress, layout: layout) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: motion.rate == 0)) { _ in
            content(motion.frame(at: ProcessInfo.processInfo.systemUptime))
        }
        .onAppear { update() }
        .onChange(of: input) { _, _ in update() }
        .onDisappear {
            motion.update(rate: 0, progress: progress, at: ProcessInfo.processInfo.systemUptime, layout: layout)
        }
    }

    private func update() {
        motion.update(rate: desiredRate, progress: progress, at: ProcessInfo.processInfo.systemUptime, layout: layout)
    }
}

/// Only rotating parts receive shutter samples. At fast wind, repeated gear
/// teeth otherwise alias against the display and can appear slow or reversed.
struct OneTapeReelExposure: ViewModifier {
    let angle: Angle
    var spread: Double = 0

    func body(content: Content) -> some View {
        Group {
            if spread > 0 {
                ZStack {
                    content.rotationEffect(angle)
                    content.rotationEffect(angle - .degrees(spread)).opacity(0.22)
                    content.rotationEffect(angle + .degrees(spread)).opacity(0.22)
                }
                .compositingGroup()
            } else {
                content.rotationEffect(angle)
            }
        }
        .animation(nil, value: angle.radians)
        .animation(nil, value: spread)
    }
}
