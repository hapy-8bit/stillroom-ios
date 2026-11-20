import UIKit

@MainActor
final class OneTapeScreenAwakeService {
    private var previousValue: Bool?

    func update(enabled: Bool, active: Bool) {
        guard active else {
            restore()
            return
        }
        if previousValue == nil {
            previousValue = UIApplication.shared.isIdleTimerDisabled
        }
        UIApplication.shared.isIdleTimerDisabled = enabled
    }

    private func restore() {
        guard let previousValue else { return }
        // Restore the policy owned by the preceding screen when this scene
        // leaves the foreground; no process-wide preference survives this host.
        UIApplication.shared.isIdleTimerDisabled = previousValue
        self.previousValue = nil
    }
}
