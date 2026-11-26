import SwiftUI

@MainActor
final class OneTapeOpeningStore: ObservableObject {
    // MARK: - First-time Zipper Unwrap State
    @Published private(set) var journey = OneTapeOpeningJourney()
    @Published private(set) var isVisible: Bool
    /// Horizontal bidirectional zipper completion across the sleeve (`0...1`).
    @Published private(set) var tearProgress: CGFloat = 0
    /// Fly-off detachment of the zipper pull-tab after reaching `1.0` (`0...1`).
    @Published private(set) var stripDetachment: CGFloat = 0
    /// Final peel-off motion of the top cap (up) and main frosted pouch (down) (`0...1`).
    @Published private(set) var sleevePeel: CGFloat = 0
    /// Overall frosted sleeve opacity (`1` sealed -> `0` unveiled).
    @Published private(set) var sleeveOpacity: Double = 1
    /// Normalized touch point (`0...1`) that glides a soft matte film sheen.
    @Published private(set) var sheenAnchor = UnitPoint(x: 0.34, y: 0.28)
    /// Horizontal drag direction hint (`-1` left, `0` idle, `+1` right) for pull-tab tilt.
    @Published private(set) var slideDirection: CGFloat = 0

    // MARK: - Option B Mini Cassette Deck Launch Splash State
    @Published var splashEnabled: Bool {
        didSet { preferences.splashEnabled = splashEnabled }
    }
    @Published private(set) var isSplashVisible: Bool
    @Published private(set) var splashAppeared = false
    @Published private(set) var splashPlayPressed = false
    @Published private(set) var splashRecoilY: CGFloat = 0
    @Published private(set) var splashMeterLevel: CGFloat = 0
    @Published private(set) var splashSpinStart: Date?
    @Published private(set) var splashDissolving = false

    @Published var notice: String?

    var isAnyOverlayVisible: Bool { isVisible || isSplashVisible }

    private let preferences: OneTapeOpeningPreferences
    private let feedback: any OneTapeOpeningFeedbackProviding
    private let durationScale: Double
    private var dragBaseProgress: CGFloat = 0
    private var lastDetent = 0
    private var feedbackPrepared = false
    private var task: Task<Void, Never>?
    private var splashTask: Task<Void, Never>?
    private var splashStarted = false

    init(
        preferences: OneTapeOpeningPreferences = .applicationPreferences(),
        feedback: (any OneTapeOpeningFeedbackProviding)? = nil,
        durationScale: Double = 1
    ) {
        self.preferences = preferences
        self.feedback = feedback ?? OneTapeOpeningFeedbackService()
        self.durationScale = max(0, durationScale)
        splashEnabled = preferences.splashEnabled
        isVisible = preferences.shouldPresent
        sleevePeel = preferences.shouldPresent ? 0 : 1
        sleeveOpacity = preferences.shouldPresent ? 1 : 0
        isSplashVisible = preferences.shouldPresentSplash
    }

    // MARK: - Player Pose

    func playerPose(reducedMotion: Bool) -> OneTapeOpeningPlayerPose? {
        guard isVisible else { return nil }
        return OneTapeOpeningPlayerPose(
            peelProgress: max(sleevePeel, tearProgress * 0.45),
            bodyReveal: 1,
            reducedMotion: reducedMotion
        )
    }

    // MARK: - Launch Splash (Option B: Braun Warm-White Mini Cassette Deck)

    func startSplashIfNeeded(reducedMotion: Bool) {
        guard isSplashVisible, !splashStarted else { return }
        runSplash(reducedMotion: reducedMotion)
    }

    func replaySplash(reducedMotion: Bool) {
        cancelSplash()
        isSplashVisible = true
        runSplash(reducedMotion: reducedMotion)
    }

    func dismissSplash() {
        cancelSplash()
        isSplashVisible = false
        resetSplashVisuals()
    }

    private func runSplash(reducedMotion: Bool) {
        cancelSplash()
        splashStarted = true
        resetSplashVisuals()
        let scale = durationScale

        if reducedMotion {
            splashAppeared = true
            splashPlayPressed = true
            splashMeterLevel = 0.55
            splashTask = Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(OneTapeSplashTiming.reducedHold * scale))
                    try Task.checkCancellation()
                    withAnimation(.easeOut(duration: OneTapeSplashTiming.reducedFade * scale)) {
                        self?.splashDissolving = true
                    }
                    try await Task.sleep(for: .seconds(OneTapeSplashTiming.reducedFade * scale))
                    try Task.checkCancellation()
                    self?.dismissSplash()
                } catch {}
            }
            return
        }

        prepareFeedbackIfNeeded()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            splashAppeared = true
        }

        splashTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(OneTapeSplashTiming.pressDelay * scale))
                try Task.checkCancellation()
                guard let self else { return }

                // Depress vermilion Play key with mechanical recoil + latch sound.
                withAnimation(.spring(response: 0.16, dampingFraction: 0.72)) {
                    self.splashPlayPressed = true
                    self.splashRecoilY = 2.0
                }
                self.feedback.latch()
                self.splashSpinStart = Date()

                withAnimation(.spring(response: 0.24, dampingFraction: 0.60)) {
                    self.splashMeterLevel = 0.72
                }
                try await Task.sleep(for: .seconds(0.11 * scale))
                try Task.checkCancellation()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    self.splashRecoilY = 0
                }

                // Organic analog VU level bounce while dual reels spin up.
                try await Task.sleep(for: .seconds(0.24 * scale))
                try Task.checkCancellation()
                withAnimation(.easeInOut(duration: 0.24 * scale)) {
                    self.splashMeterLevel = 0.88
                }
                try await Task.sleep(for: .seconds(0.26 * scale))
                try Task.checkCancellation()
                withAnimation(.easeInOut(duration: 0.26 * scale)) {
                    self.splashMeterLevel = 0.56
                }
                try await Task.sleep(for: .seconds(0.26 * scale))
                try Task.checkCancellation()
                withAnimation(.easeInOut(duration: 0.28 * scale)) {
                    self.splashMeterLevel = 0.76
                }

                let remaining = max(0.05, OneTapeSplashTiming.spinDuration - 0.87)
                try await Task.sleep(for: .seconds(remaining * scale))
                try Task.checkCancellation()

                withAnimation(.easeInOut(duration: OneTapeSplashTiming.dissolveDuration * scale)) {
                    self.splashDissolving = true
                }
                try await Task.sleep(for: .seconds(OneTapeSplashTiming.dissolveDuration * scale))
                try Task.checkCancellation()
                self.dismissSplash()
            } catch is CancellationError {
            } catch {
                self?.dismissSplash()
            }
        }
    }

    private func cancelSplash() {
        splashTask?.cancel()
        splashTask = nil
        splashStarted = false
    }

    private func resetSplashVisuals() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            splashAppeared = false
            splashPlayPressed = false
            splashRecoilY = 0
            splashMeterLevel = 0
            splashSpinStart = nil
            splashDissolving = false
        }
    }

    // MARK: - Bidirectional Zipper Unwrap Interaction

    func updateSheen(normalizedX: CGFloat, normalizedY: CGFloat, reducedMotion: Bool) {
        guard isVisible, !reducedMotion,
              normalizedX.isFinite, normalizedY.isFinite else { return }
        sheenAnchor = UnitPoint(
            x: min(0.92, max(0.08, normalizedX)),
            y: min(0.92, max(0.08, normalizedY))
        )
    }

    func updateTear(translationX: CGFloat, trackWidth: CGFloat, reducedMotion: Bool) {
        guard isVisible, journey.stage == .sealed || journey.stage == .tearing else { return }
        if journey.stage == .sealed {
            dragBaseProgress = tearProgress
            journey.beginTearing()
            prepareFeedbackIfNeeded()
        }
        let previous = tearProgress
        let next = OneTapeOpeningTearRules.progress(
            baseProgress: dragBaseProgress,
            translationX: translationX,
            trackWidth: trackWidth
        )
        tearProgress = next
        if abs(next - previous) > 0.001 {
            slideDirection = next > previous ? 1 : -1
        }
        if !reducedMotion {
            sheenAnchor = UnitPoint(x: min(0.92, max(0.10, 0.14 + next * 0.78)), y: 0.28)
        }
        let detent = OneTapeOpeningTearRules.detentIndex(for: next)
        if detent != lastDetent {
            lastDetent = detent
            feedback.tickPerforation()
        }
    }

    func endTear(predictedTranslationX: CGFloat, trackWidth: CGFloat, reducedMotion: Bool) {
        guard isVisible, journey.stage == .tearing else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            slideDirection = 0
        }
        if OneTapeOpeningTearRules.shouldCommit(
            progress: tearProgress,
            predictedTranslationX: predictedTranslationX,
            trackWidth: trackWidth
        ) {
            commitUnwrap(reducedMotion: reducedMotion)
        } else {
            dragBaseProgress = tearProgress
            journey.pauseTearing()
        }
    }

    /// Commits unzipping: smoothly animates the zipper the rest of the way across
    /// (parting top & bottom flaps up/down as it zips), pops the slider off, and
    /// glides the frosted halves completely off the live player.
    @discardableResult
    func commitUnwrap(reducedMotion: Bool) -> Bool {
        guard isVisible, journey.commitPeel() else { return false }
        prepareFeedbackIfNeeded()
        let scale = durationScale

        if reducedMotion {
            tearProgress = 1
            stripDetachment = 1
            feedback.snapStrip()
            withAnimation(.easeOut(duration: OneTapeOpeningTiming.reducedFade * scale)) {
                sleevePeel = 1
                sleeveOpacity = 0
            }
            task = Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(OneTapeOpeningTiming.reducedFade * scale))
                    try Task.checkCancellation()
                    self?.feedback.latch()
                    self?.finish()
                } catch is CancellationError {
                } catch {
                    self?.notice = "开屏过渡未能完成，已为你打开播放器。"
                    self?.finish()
                }
            }
            return true
        }

        let remainingFraction = Double(max(0, 1 - tearProgress))
        let zipDuration = remainingFraction > 0.04
            ? max(OneTapeOpeningTiming.zipFinishMin, OneTapeOpeningTiming.zipFinishMax * remainingFraction)
            : 0.05

        withAnimation(.timingCurve(0.25, 0.85, 0.35, 1.0, duration: zipDuration * scale)) {
            tearProgress = 1
            slideDirection = 1
        }

        task = Task { [weak self] in
            do {
                if remainingFraction > 0.04 {
                    // Play a couple of crisp zipper teeth ticks during auto-zip completion.
                    let ticks = max(1, min(5, Int((remainingFraction * 6).rounded())))
                    let step = zipDuration / Double(ticks + 1)
                    for _ in 0..<ticks {
                        try await Task.sleep(for: .seconds(step * scale))
                        try Task.checkCancellation()
                        self?.feedback.tickPerforation()
                    }
                    try await Task.sleep(for: .seconds(step * scale))
                    try Task.checkCancellation()
                } else {
                    try await Task.sleep(for: .seconds(zipDuration * scale))
                    try Task.checkCancellation()
                }

                withAnimation(.easeOut(duration: OneTapeOpeningTiming.stripFlyOff * scale)) {
                    self?.stripDetachment = 1
                    self?.slideDirection = 0
                }
                self?.feedback.snapStrip()

                try await Task.sleep(for: .seconds(OneTapeOpeningTiming.peelDelay * scale))
                try Task.checkCancellation()
                withAnimation(.timingCurve(0.22, 0.9, 0.28, 1.0, duration: OneTapeOpeningTiming.sleevePeel * scale)) {
                    self?.sleevePeel = 1
                }
                withAnimation(.easeIn(duration: OneTapeOpeningTiming.sleevePeel * 0.85 * scale)) {
                    self?.sleeveOpacity = 0
                }
                try await Task.sleep(for: .seconds(OneTapeOpeningTiming.sleevePeel * scale))
                try Task.checkCancellation()
                self?.feedback.latch()
                try await Task.sleep(for: .seconds(OneTapeOpeningTiming.settle * scale))
                try Task.checkCancellation()
                self?.finish()
            } catch is CancellationError {
            } catch {
                self?.notice = "开屏过渡未能完成，已为你打开播放器。"
                self?.finish()
            }
        }
        return true
    }

    func finish() {
        cancel()
        preferences.complete()
        journey.finish()
        tearProgress = 1
        stripDetachment = 1
        sleevePeel = 1
        sleeveOpacity = 0
        slideDirection = 0
        isVisible = false
    }

    func replay() {
        cancelSplash()
        isSplashVisible = false
        cancel()
        notice = nil
        resetPose()
        isVisible = true
    }

    func suspend() {
        cancel()
        if isSplashVisible {
            dismissSplash()
        }
        if isVisible { resetPose() }
    }

    private func prepareFeedbackIfNeeded() {
        guard !feedbackPrepared else { return }
        feedbackPrepared = true
        do { try feedback.prepare() }
        catch { notice = "开屏音效暂时不可用，仍可正常进入播放器。" }
    }

    private func cancel() {
        task?.cancel()
        task = nil
        feedbackPrepared = false
        feedback.stop()
    }

    private func resetPose() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            journey.reset()
            tearProgress = 0
            stripDetachment = 0
            sleevePeel = 0
            sleeveOpacity = 1
            dragBaseProgress = 0
            lastDetent = 0
            slideDirection = 0
            sheenAnchor = UnitPoint(x: 0.34, y: 0.28)
        }
    }

    deinit {
        task?.cancel()
        splashTask?.cancel()
    }
}
