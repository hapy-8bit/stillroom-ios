import CoreMotion
import Foundation
import Combine

/// Live device gravity is a presentation input in g units, never media time or saved state.
/// One scene owns this source; it runs only while the unselected opening is active.
@MainActor
final class OpeningGravitySource: ObservableObject {
    @Published private(set) var gravityY: Double = 0
    @Published private(set) var problem: String?
    private let manager = CMMotionManager()
    private var running = false
    private var generation = 0
    private var projection = OpeningGravityProjection()

    deinit { manager.stopDeviceMotionUpdates() }

    func setActive(_ active: Bool) {
        guard active else { stop(); return }
        guard !running else { return }
        // Simulator/no sensor is an ordinary stationary presentation, not a playback error.
        guard manager.isDeviceMotionAvailable else { return }
        generation &+= 1
        let token = generation
        running = true
        problem = nil
        // Match the recovered relative-gravity callback: each sensor run captures its own
        // baseline, with 60 Hz input and a deadband rather than a guessed low-pass filter.
        projection.beginRun()
        manager.deviceMotionUpdateInterval = OpeningGravityProjection.updateInterval
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, error in
            let sample = motion?.gravity.y
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.running, self.generation == token else { return }
                if failed {
                    self.stop()
                    self.problem = "倾斜效果暂不可用，仍可轻点封套。"
                } else if let sample, let projected = self.projection.ingest(rawY: sample) {
                    self.gravityY = projected
                }
            }
        }
    }

    func stop() {
        guard running else { return }
        generation &+= 1
        running = false
        manager.stopDeviceMotionUpdates()
        // Preserve the last angle when a selection begins; resetting to zero would jump the
        // physical hinge just as its pose is captured for the flip animation.
    }
}
