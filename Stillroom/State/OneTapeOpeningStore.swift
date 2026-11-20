import SwiftUI

@MainActor
final class OneTapeOpeningStore: ObservableObject {
    @Published private(set) var journey = OneTapeOpeningJourney()
    @Published private(set) var isVisible: Bool
    @Published private(set) var caseOpening: CGFloat = 0
    @Published private(set) var extraction: CGFloat = 0
    @Published private(set) var caseOpacity: Double = 1
    @Published private(set) var clockwiseTurn: CGFloat = 0
    @Published private(set) var insertion: CGFloat = 0
    @Published private(set) var inspectionYaw: Double = 0
    @Published private(set) var homeReveal: Double
    @Published private(set) var heroOpacity: Double = 0
    @Published var notice: String?

    private let preferences: OneTapeOpeningPreferences
    private let feedback: any OneTapeOpeningFeedbackProviding
    private let durationScale: Double
    private var task: Task<Void, Never>?

    init(preferences: OneTapeOpeningPreferences = .applicationPreferences(),
         feedback: (any OneTapeOpeningFeedbackProviding)? = nil, durationScale: Double = 1) {
        self.preferences = preferences
        self.feedback = feedback ?? OneTapeOpeningFeedbackService()
        self.durationScale = max(0, durationScale)
        isVisible = preferences.shouldPresent
        homeReveal = preferences.shouldPresent ? 0 : 1
    }

    func playerPose(reducedMotion: Bool) -> OneTapeOpeningPlayerPose? {
        guard isVisible else { return nil }
        return OneTapeOpeningPlayerPose(extraction: extraction, turn: clockwiseTurn,
            approach: insertion, yaw: inspectionYaw, opacity: heroOpacity,
            bodyReveal: homeReveal, reducedMotion: reducedMotion)
    }

    func inspect(yaw: Double, reducedMotion: Bool) {
        guard journey.stage == .inspecting, yaw.isFinite, !reducedMotion else { return }
        inspectionYaw = min(34, max(-34, yaw))
    }

    func releaseInspection(reducedMotion: Bool) {
        withAnimation(reducedMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88)) {
            inspectionYaw = 0
        }
    }

    func openCase(reducedMotion: Bool) {
        guard isVisible, journey.stage == .waiting else { return }
        journey.openCase()
        let scale = durationScale
        if reducedMotion {
            withAnimation(.easeOut(duration: 0.18 * scale)) {
                caseOpacity = 0
                heroOpacity = 1
            }
        } else {
            withAnimation(.easeInOut(duration: 0.60 * scale)) { caseOpening = 1 }
        }
        task = Task { [weak self] in
            do {
                if reducedMotion {
                    try await Task.sleep(for: .seconds(0.2 * scale))
                } else {
                    try await Task.sleep(for: .seconds(0.30 * scale))
                    try Task.checkCancellation()
                    withAnimation(.easeOut(duration: 0.20 * scale)) { self?.heroOpacity = 1 }
                    try await Task.sleep(for: .seconds(0.22 * scale))
                    try Task.checkCancellation()
                    withAnimation(.spring(duration: 0.88 * scale, bounce: 0)) { self?.extraction = 1 }
                    try await Task.sleep(for: .seconds(0.26 * scale))
                    try Task.checkCancellation()
                    withAnimation(.easeOut(duration: 0.50 * scale)) { self?.caseOpacity = 0 }
                    try await Task.sleep(for: .seconds(0.62 * scale))
                }
                try Task.checkCancellation()
                self?.journey.advance()
                self?.task = nil
            } catch is CancellationError {
            } catch {
                self?.notice = "开盒动画未能完成，已为你打开播放器。"
                self?.finish()
            }
        }
    }

    @discardableResult
    func insert(reducedMotion: Bool) -> Bool {
        guard isVisible, journey.stage == .inspecting else { return false }
        journey.insert()
        releaseInspection(reducedMotion: reducedMotion)
        do { try feedback.prepare() }
        catch { notice = "开屏音效暂时不可用，仍可正常进入播放器。" }
        let scale = durationScale
        if reducedMotion {
            withAnimation(.easeOut(duration: 0.14 * scale)) { heroOpacity = 0 }
        } else {
            withAnimation(.easeInOut(duration: OneTapeOpeningTiming.turn * scale)) { clockwiseTurn = 1 }
        }
        task = Task { [weak self] in
            do {
                if reducedMotion {
                    try await Task.sleep(for: .seconds(0.14 * scale))
                    try Task.checkCancellation()
                    self?.clockwiseTurn = 1
                    self?.insertion = 1
                    withAnimation(.easeOut(duration: 0.18 * scale)) {
                        self?.homeReveal = 1
                        self?.heroOpacity = 1
                    }
                    self?.feedback.latch()
                    try await Task.sleep(for: .seconds(0.20 * scale))
                } else {
                    try await Task.sleep(for: .seconds(OneTapeOpeningTiming.approachDelay * scale))
                    try Task.checkCancellation()
                    self?.journey.advance()
                    // Keep this same player cassette visible. The body appears
                    // around it while its scale/center settle to the identity pose.
                    withAnimation(.spring(duration: OneTapeOpeningTiming.dock * scale, bounce: 0)) {
                        self?.insertion = 1
                    }
                    withAnimation(.easeInOut(duration: OneTapeOpeningTiming.dock * scale)) {
                        self?.homeReveal = 1
                    }
                    try await Task.sleep(for: .seconds(OneTapeOpeningTiming.dock * scale))
                    try Task.checkCancellation()
                    self?.feedback.latch()
                    self?.journey.advance()
                    try await Task.sleep(for: .seconds(OneTapeOpeningTiming.reveal * scale))
                }
                try Task.checkCancellation()
                self?.finish()
            } catch is CancellationError {
                // Background/skip/replay owns the next pose; no stale completion.
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
        homeReveal = 1
        isVisible = false
    }

    func replay() {
        cancel()
        notice = nil
        resetPose()
        isVisible = true
    }

    func suspend() {
        cancel()
        if isVisible { resetPose() }
    }

    private func cancel() {
        task?.cancel()
        task = nil
        feedback.stop()
    }

    private func resetPose() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            journey.reset()
            caseOpening = 0
            extraction = 0
            caseOpacity = 1
            clockwiseTurn = 0
            insertion = 0
            inspectionYaw = 0
            homeReveal = 0
            heroOpacity = 0
        }
    }

    deinit { task?.cancel() }
}
