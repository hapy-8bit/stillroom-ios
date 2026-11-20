import SwiftUI
import QuartzCore

#if DEBUG && targetEnvironment(simulator)
/// Lightweight CADisplayLink-driven FPS readout shown only in Simulator Debug builds
/// so reel-rotation frame pacing can be verified directly on screen.
struct OneTapeSimulatorFPSOverlay: View {
    @StateObject private var monitor = DisplayLinkFPSMonitor()

    var body: some View {
        Text("\(monitor.fps) FPS")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(monitor.fps >= 55 ? Color.green : Color.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.68), in: Capsule())
            .overlay {
                Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.6)
            }
            .onAppear { monitor.start() }
            .onDisappear { monitor.stop() }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

@MainActor
private final class DisplayLinkFPSMonitor: ObservableObject {
    @Published var fps = 0

    private var displayLink: CADisplayLink?
    private var proxy: TargetProxy?
    private var frameCount = 0
    private var windowStart: CFTimeInterval = 0

    func start() {
        guard displayLink == nil else { return }
        let target = TargetProxy { [weak self] link in
            self?.step(link)
        }
        let link = CADisplayLink(target: target, selector: #selector(TargetProxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        proxy = target
        displayLink = link
        windowStart = 0
        frameCount = 0
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        proxy = nil
    }

    private func step(_ link: CADisplayLink) {
        if windowStart == 0 {
            windowStart = link.timestamp
            return
        }
        frameCount += 1
        let elapsed = link.timestamp - windowStart
        guard elapsed >= 0.5 else { return }
        fps = Int((Double(frameCount) / elapsed).rounded())
        windowStart = link.timestamp
        frameCount = 0
    }

    private final class TargetProxy: NSObject {
        private let onTick: (CADisplayLink) -> Void

        init(_ onTick: @escaping (CADisplayLink) -> Void) {
            self.onTick = onTick
        }

        @objc func tick(_ link: CADisplayLink) {
            onTick(link)
        }
    }
}
#endif
