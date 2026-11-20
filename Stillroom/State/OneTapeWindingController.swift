import Foundation
import UIKit

/// Controls seek intent only. The provided engine remains responsible for
/// completing seeks and publishing actual media time; this owns no audio object.
@MainActor
final class OneTapeWindingController {
    struct Context {
        let trackID: String
        let position: TimeInterval
        let duration: TimeInterval
        let wasPlaying: Bool
    }

    private struct Session {
        let context: Context
        let direction: Int
        let resumePlayback: Bool
    }

    private let read: () -> Context?
    private let prepare: () throws -> Void
    private let seek: (TimeInterval) -> Void
    private let resumePlayback: () -> Void
    private var session: Session?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var lastTarget: TimeInterval?
    private var inactiveObservation: NSObjectProtocol?
    var isWinding: Bool { session != nil }

    init(read: @escaping () -> Context?, prepare: @escaping () throws -> Void,
         seek: @escaping (TimeInterval) -> Void, resumePlayback: @escaping () -> Void) {
        self.read = read
        self.prepare = prepare
        self.seek = seek
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
        guard direction != 0, let context = read(), !context.trackID.isEmpty,
              context.position.isFinite, context.duration.isFinite, context.duration > 0 else { return }
        let direction = direction > 0 ? 1 : -1
        if session?.context.trackID == context.trackID, session?.direction == direction { return }
        let shouldResume = session?.context.trackID == context.trackID ? session!.resumePlayback : context.wasPlaying
        cancel()
        try prepare()
        session = Session(context: context, direction: direction, resumePlayback: shouldResume)
        let request = generation
        let began = ContinuousClock.now
        task = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                guard let self, request == self.generation, !Task.isCancelled else { return }
                let elapsed = began.duration(to: .now).components
                let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                self.advance(elapsed: seconds)
                if !self.isWinding { return }
            }
        }
    }

    /// The timer uses a monotonic origin, rather than accumulating snapshot
    /// deltas: slow HTTP seek completion must not change the requested ±6x rate.
    func advance(elapsed: TimeInterval) {
        guard elapsed.isFinite, elapsed >= 0 else { return }
        guard let session else { return }
        guard read()?.trackID == session.context.trackID else { cancel(); return }
        let target = OneTapeTransportRules.windingPosition(start: session.context.position,
            elapsed: elapsed, direction: session.direction, duration: session.context.duration)
        guard lastTarget.map({ abs($0 - target) >= 0.001 }) ?? true else { return }
        lastTarget = target
        seek(target)
    }

    func end(resume: Bool = true) {
        let previous = session
        cancel()
        if resume, let previous, previous.resumePlayback,
           read()?.trackID == previous.context.trackID { resumePlayback() }
    }

    func cancel() {
        generation += 1
        task?.cancel(); task = nil
        session = nil; lastTarget = nil
    }
}
