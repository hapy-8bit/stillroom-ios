import Foundation
import UIKit

/// A short mechanical lead-in for explicit track keys. This never seeks media:
/// the existing engine stays paused until the visual wind and brake finish.
@MainActor
final class OneTapeTrackWindupController {
    struct Context: Equatable {
        let trackID: String
        let selectionRevision: Int
    }

    struct Timing {
        // Cassette's transport stores 14x and 0.65s. The brief brake is an
        // experience value; it has not been measured from the original app.
        var wind: Duration = .seconds(OneTapeTransportRules.trackChangeWindSeconds)
        var brake: Duration = .seconds(OneTapeTransportRules.trackChangeBrakeSeconds)
        var rate = OneTapeTransportRules.trackChangeRate
    }

    private let read: () -> Context?
    private let prepare: () throws -> Void
    private let onRateChange: (Double?) -> Void
    private let resumePlayback: () -> Void
    private let timing: Timing
    private var context: Context?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var inactiveObservation: NSObjectProtocol?
    var isActive: Bool { context != nil }

    init(timing: Timing = Timing(), read: @escaping () -> Context?,
         prepare: @escaping () throws -> Void,
         onRateChange: @escaping (Double?) -> Void, resumePlayback: @escaping () -> Void) {
        self.timing = timing
        self.read = read
        self.prepare = prepare
        self.onRateChange = onRateChange
        self.resumePlayback = resumePlayback
        inactiveObservation = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.cancel() } }
    }

    deinit {
        task?.cancel()
        if let inactiveObservation { NotificationCenter.default.removeObserver(inactiveObservation) }
    }

    func begin(direction: Int) throws {
        cancel()
        guard direction != 0, let selected = read(), !selected.trackID.isEmpty else { return }
        try prepare()
        guard read() == selected else { return }
        context = selected
        onRateChange(direction > 0 ? timing.rate : -timing.rate)
        let request = generation
        let timing = timing
        task = Task { [weak self] in
            do { try await Task.sleep(for: timing.wind) } catch { return }
            guard let self, self.isCurrent(request), !Task.isCancelled else { return }
            self.onRateChange(0)
            do { try await Task.sleep(for: timing.brake) } catch { return }
            guard self.isCurrent(request), !Task.isCancelled else { return }
            // Clear the delayed intent before calling play(), which cancels
            // other transport work through PlayerStore's regular command path.
            self.context = nil
            self.task = nil
            self.onRateChange(nil)
            self.resumePlayback()
        }
    }

    func cancel() {
        let wasActive = isActive
        generation += 1
        task?.cancel()
        task = nil
        context = nil
        if wasActive { onRateChange(nil) }
    }

    private func isCurrent(_ request: Int) -> Bool {
        guard request == generation else { return false }
        guard let context, read() == context else {
            cancel()
            return false
        }
        return true
    }
}
