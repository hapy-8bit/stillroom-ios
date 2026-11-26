import CoreGraphics
import CoreMotion
import Foundation

/// Visual-only device tilt source for foil, mirror and optical surfaces.
/// Media playback time never reads or depends on this monitor.
@MainActor
final class OneTapeTiltMonitor: ObservableObject {
    /// Static hero pose used when Reduce Motion is enabled or motion is paused.
    static let restingTilt = CGSize(width: 0.28, height: -0.22)

    @Published private(set) var tilt: CGSize = OneTapeTiltMonitor.restingTilt

    private let motionManager = CMMotionManager()
    private var simulatorTask: Task<Void, Never>?
    private var isRunning = false
    private var smoothed = OneTapeTiltMonitor.restingTilt

    func setActive(_ active: Bool, reducedMotion: Bool) {
        let shouldRun = active && !reducedMotion
        guard shouldRun != isRunning else {
            if reducedMotion {
                tilt = Self.restingTilt
            }
            return
        }
        if shouldRun {
            start()
        } else {
            stop(resetToRest: reducedMotion)
        }
    }

    func stop(resetToRest: Bool = false) {
        isRunning = false
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        simulatorTask?.cancel()
        simulatorTask = nil
        if resetToRest {
            smoothed = Self.restingTilt
            tilt = Self.restingTilt
        }
    }

    private func start() {
        isRunning = true
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self, let motion else { return }
                let gx = max(-1.0, min(1.0, motion.gravity.x * 1.45))
                let gy = max(-1.0, min(1.0, (motion.gravity.y + 0.52) * 1.45))
                Task { @MainActor [weak self] in
                    self?.applySample(CGSize(width: gx, height: gy))
                }
            }
        } else {
            // Simulators lack a physical gyroscope. Use a gentle visual-phase
            // figure-eight drift so iridescent foil and mirror surfaces visibly
            // catch studio light during preview; cancel cleanly when inactive.
            let startDate = Date()
            simulatorTask?.cancel()
            simulatorTask = Task { [weak self] in
                while !Task.isCancelled {
                    let elapsed = Date().timeIntervalSince(startDate)
                    let x = sin(elapsed * 0.72) * 0.62 + sin(elapsed * 1.44) * 0.12
                    let y = cos(elapsed * 0.56) * 0.48 - 0.10
                    self?.applySample(CGSize(width: x, height: y))
                    try? await Task.sleep(for: .milliseconds(33))
                }
            }
        }
    }

    private func applySample(_ target: CGSize) {
        guard isRunning else { return }
        let alpha: CGFloat = 0.16
        let next = CGSize(
            width: smoothed.width + (target.width - smoothed.width) * alpha,
            height: smoothed.height + (target.height - smoothed.height) * alpha
        )
        smoothed = next
        if abs(next.width - tilt.width) > 0.002 || abs(next.height - tilt.height) > 0.002 {
            tilt = next
        }
    }

    deinit {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        simulatorTask?.cancel()
    }
}
