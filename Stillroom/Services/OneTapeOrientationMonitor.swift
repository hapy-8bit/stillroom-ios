import UIKit
import Combine

/// The reference keeps its portrait machine canvas while its internal display
/// and mechanical controls accept portrait and left landscape only.
@MainActor
final class OneTapeOrientationMonitor: ObservableObject {
    @Published private(set) var quarterTurns = 0
    private var observation: NSObjectProtocol?

    func start() {
        guard observation == nil else { return }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        update()
        observation = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }

    func stop() {
        guard let observation else { return }
        NotificationCenter.default.removeObserver(observation)
        self.observation = nil
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    private func update() {
        quarterTurns = Self.supportedTurn(for: UIDevice.current.orientation, retaining: quarterTurns)
    }

    static func supportedTurn(for orientation: UIDeviceOrientation, retaining previous: Int) -> Int {
        switch orientation {
        case .landscapeLeft: return 1
        case .portrait, .portraitUpsideDown, .landscapeRight: return 0
        default:
            // Face-up/down/unknown preserve a deliberate supported orientation;
            // a stale unsupported turn must never reintroduce right landscape.
            return previous == 1 ? 1 : 0
        }
    }

    deinit {
        if let observation { NotificationCenter.default.removeObserver(observation) }
    }
}
