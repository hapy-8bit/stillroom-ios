import SwiftUI

/// One touch has one outcome: a short press, or winding until release. The
/// gesture owns only press recognition; media time belongs to PlayerStore.
struct OneTapeTransportKey: View {
    let supportsHold: Bool
    let hitDiameter: CGFloat
    let action: () -> Void
    var onHoldBegan: () -> Void = {}
    var onHoldEnded: (Bool) -> Void = { _ in }
    var appearance = OneTapeAppearance()
    var artworkColor: OneTapeTransportMaterial.RGB? = nil
    var transportAction: OneTapeTransportAction = .play
    var isPlayKey = false
    var illuminated = false
    var quarterTurns = 0

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var pressed = false
    @State private var pressID: UUID?
    @State private var startedAt: Date?
    @State private var didHold = false
    @State private var cancelledTouch = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        Color.clear
            .frame(width: hitDiameter, height: hitDiameter)
            .contentShape(Circle())
            .overlay {
                OneTapeTransportKeyVisual(appearance: appearance, action: transportAction,
                    illuminated: illuminated, quarterTurns: quarterTurns, artworkColor: artworkColor)
            }
            .overlay {
                Circle()
                    .fill(.black.opacity(pressed ? 0.16 : 0.001))
                    .overlay {
                        Circle().strokeBorder(.black.opacity(pressed ? 0.45 : 0), lineWidth: 3)
                    }
                    .clipShape(Circle())
                    // Press shading stays inside the existing cap. The old
                    // blurred stroke darkened its outer padding, appearing larger.
                    .frame(width: OneTapeTransportGeometry.visualDiameter - 8,
                           height: OneTapeTransportGeometry.visualDiameter - 8)
                    .allowsHitTesting(false)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: illuminated)
            .gesture(pressGesture)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
            .onChange(of: pressed) { _, pressed in
                // System gesture cancellation does not call onEnded.
                if !pressed {
                    finish(cancelled: true)
                    cancelledTouch = false
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { finish(cancelled: true) }
            }
            .onDisappear { finish(cancelled: true) }
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($pressed) { _, value, _ in value = true }
            .onChanged { value in
                guard scenePhase == .active, !cancelledTouch else { return }
                if hypot(value.translation.width, value.translation.height) > hitDiameter / 2 {
                    cancelledTouch = true
                    finish(cancelled: true)
                    return
                }
                guard pressID == nil else { return }
                let id = UUID()
                pressID = id
                startedAt = Date()
                didHold = false
                guard supportsHold else { return }
                holdTask = Task { @MainActor in
                    do {
                        try await Task.sleep(for: .milliseconds(420))
                        guard !Task.isCancelled, pressID == id else { return }
                        didHold = true
                        onHoldBegan()
                    } catch { return }
                }
            }
            .onEnded { value in
                let outside = hypot(value.translation.width, value.translation.height) > hitDiameter / 2
                finish(cancelled: outside || cancelledTouch)
                cancelledTouch = false
            }
    }

    private func finish(cancelled: Bool) {
        holdTask?.cancel()
        holdTask = nil
        guard pressID != nil else { return }
        let elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        let held = didHold || (supportsHold && elapsed >= 0.42)
        if held {
            if !didHold, !cancelled { onHoldBegan() }
            onHoldEnded(!cancelled)
        } else if !cancelled {
            action()
        }
        pressID = nil
        startedAt = nil
        didHold = false
    }
}
