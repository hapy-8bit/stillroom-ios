import SwiftUI

/// Owns cancellable visual work and delayed play intent, never an audio instance or media clock.
@MainActor
final class RecordOpeningController: ObservableObject {
    @Published private(set) var journey = RecordOpeningJourney()
    @Published private(set) var openProgress: Double = 0
    @Published private(set) var exitProgress: Double = 0
    @Published private(set) var reveal: Double = 0
    @Published private(set) var playerProgress: Double = 0
    @Published private(set) var cueing = false

    private var openingTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?

    deinit {
        openingTask?.cancel()
        playbackTask?.cancel()
    }

    func select(trackID: String, reducedMotion: Bool) {
        reset()
        guard let token = journey.select(trackID: trackID) else { return }
        if reducedMotion {
            settle(token)
            return
        }
        openingTask = Task { [weak self] in
            // The original publishes the overlay selection after its neighbors have begun
            // moving out. This is a cancellable state delay, not an animation completion.
            do { try await Task.sleep(for: .seconds(RecordOpeningTiming.selectionPublishDelay)) }
            catch { return }
            guard let self, !Task.isCancelled, self.journey.isCurrent(token) else { return }
            withAnimation(.spring(response: RecordOpeningTiming.openingSpringResponse,
                                  dampingFraction: RecordOpeningTiming.openingSpringDamping)) {
                self.openProgress = 1
            }
            do { try await Task.sleep(for: .seconds(RecordOpeningTiming.openingFinishDelay)) }
            catch { return }
            guard !Task.isCancelled, self.journey.finishOpening(token: token) else { return }
            // The record is already inside the front-facing sleeve. Make it opaque before
            // sliding the sleeve away, so extraction reveals an occluded object, not a fade.
            var revealTransaction = Transaction()
            revealTransaction.disablesAnimations = true
            withTransaction(revealTransaction) { self.reveal = 1 }
            withAnimation(.easeInOut(duration: RecordOpeningTiming.extractionDuration)) {
                self.exitProgress = 1
            }
            do { try await Task.sleep(for: .seconds(RecordOpeningTiming.landscapeFinishDelay)) }
            catch { return }
            guard !Task.isCancelled, self.journey.finishLandscapeTransition(token: token) else { return }
            // Both delays are measured from the finished-opening branch in the original.
            let remainder = RecordOpeningTiming.playerModeDelay - RecordOpeningTiming.landscapeFinishDelay
            do { try await Task.sleep(for: .seconds(remainder)) }
            catch { return }
            guard !Task.isCancelled, self.journey.enterPlayer(token: token) else { return }
            withAnimation(.spring(response: RecordOpeningTiming.playerSpringResponse,
                                  dampingFraction: RecordOpeningTiming.playerSpringDamping)) {
                self.playerProgress = 1
            }
            self.openingTask = nil
        }
    }

    func requestPlayback(commit: @escaping (String) -> Void) {
        guard let token = journey.currentToken,
              let request = journey.requestPlayback(token: token) else { return }
        cueing = true
        playbackTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(RecordOpeningTiming.playbackIntentDelay)) }
            catch { return }
            guard let self, !Task.isCancelled,
                  let trackID = self.journey.consumePlayback(request) else { return }
            self.cueing = false
            self.playbackTask = nil
            // Commit only after consuming this generation's ticket. An animation completion
            // cannot revive a cancelled selection, and PlayerStore remains the playback authority.
            commit(trackID)
        }
    }

    func cancelPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        journey.cancelPendingPlayback()
        cueing = false
    }

    func reset() {
        openingTask?.cancel()
        openingTask = nil
        cancelPlayback()
        journey.cancel()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            openProgress = 0
            exitProgress = 0
            reveal = 0
            playerProgress = 0
        }
    }

    func suspend() {
        openingTask?.cancel()
        openingTask = nil
        cancelPlayback()
        // Returning from background must offer a usable parked record, not a frozen halfway
        // sleeve. Settling the visual milestones never issues a play intent.
        if let token = journey.currentToken { settle(token) }
    }

    private func settle(_ token: RecordOpeningJourney.Token) {
        _ = journey.finishOpening(token: token)
        _ = journey.finishLandscapeTransition(token: token)
        _ = journey.enterPlayer(token: token)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            openProgress = 1
            exitProgress = 1
            reveal = 1
            playerProgress = 1
        }
    }
}
