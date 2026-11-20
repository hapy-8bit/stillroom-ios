import AVFoundation
import Combine
import XCTest
@testable import Stillroom

@MainActor
final class OneTapeOpeningTests: XCTestCase {
    private func preferences() -> (UserDefaults, OneTapeOpeningPreferences) {
        let defaults = UserDefaults(suiteName: "OneTapeOpeningTests." + UUID().uuidString)!
        return (defaults, OneTapeOpeningPreferences(defaults: defaults))
    }

    func testCompletionIsSeparateFromLibraryAppearanceAndLegacyOpening() {
        let (defaults, preferences) = preferences()
        defaults.set(Data([1, 2, 3]), forKey: "oneTape.appearance.v1")
        defaults.set(false, forKey: "recordOpening.completed.v1")
        XCTAssertTrue(preferences.shouldPresent)
        preferences.complete()
        XCTAssertFalse(OneTapeOpeningPreferences(defaults: defaults).shouldPresent)
        XCTAssertEqual(defaults.data(forKey: "oneTape.appearance.v1"), Data([1, 2, 3]))
        XCTAssertFalse(defaults.bool(forKey: "recordOpening.completed.v1"))
    }

    func testFixtureSuppressionDoesNotMarkNormalOpeningCompleted() {
        let (defaults, _) = preferences()
        XCTAssertFalse(OneTapeOpeningPreferences(defaults: defaults, suppressed: true).shouldPresent)
        XCTAssertNil(defaults.object(forKey: OneTapeOpeningPreferences.completionKey))
        XCTAssertTrue(OneTapeOpeningPreferences(defaults: defaults).shouldPresent)
    }

    func testClosedBoxCannotInsertBeforeTheFirstGesture() {
        let (_, preferences) = preferences()
        let feedback = OpeningFeedback()
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback)
        XCTAssertFalse(store.insert(reducedMotion: false))
        XCTAssertEqual(store.journey.stage, .waiting)
        XCTAssertEqual(store.caseOpening, 0)
        XCTAssertEqual(store.caseOpacity, 1)
        XCTAssertEqual(store.heroOpacity, 0)
        XCTAssertEqual(feedback.preparations, 0)
    }

    func testOpeningStopsForInspectionWithoutSoundOrCompletingFirstUse() async throws {
        let (defaults, preferences) = preferences()
        let feedback = OpeningFeedback()
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.02)
        store.openCase(reducedMotion: false)
        store.openCase(reducedMotion: false)
        try await waitUntil { store.journey.stage == .inspecting }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(store.journey.stage, .inspecting)
        XCTAssertTrue(store.isVisible)
        XCTAssertEqual(store.heroOpacity, 1)
        XCTAssertEqual(store.caseOpacity, 0)
        XCTAssertEqual(store.insertion, 0)
        XCTAssertEqual(feedback.latches, 0)
        XCTAssertFalse(defaults.bool(forKey: OneTapeOpeningPreferences.completionKey))
    }

    func testTwoGesturesTurnAndKeepThePlayerCassetteVisibleAtArrival() async throws {
        let (defaults, preferences) = preferences()
        let feedback = OpeningFeedback()
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.04)
        var stages: [OneTapeOpeningStage] = []
        let observation = store.$journey.sink { stages.append($0.stage) }
        feedback.onLatch = { [weak store] in
            XCTAssertEqual(store?.journey.stage, .inserting)
            XCTAssertEqual(store?.clockwiseTurn, 1)
            XCTAssertEqual(store?.homeReveal, 1)
        }
        store.openCase(reducedMotion: false)
        try await waitUntil { store.journey.stage == .inspecting }
        XCTAssertTrue(store.insert(reducedMotion: false))
        XCTAssertFalse(store.insert(reducedMotion: false))
        XCTAssertEqual(store.journey.stage, .rotating)
        XCTAssertEqual(store.clockwiseTurn, 1)
        XCTAssertEqual(store.insertion, 0)
        XCTAssertEqual(feedback.latches, 0)
        XCTAssertFalse(defaults.bool(forKey: OneTapeOpeningPreferences.completionKey))
        try await waitUntil { !store.isVisible }
        XCTAssertEqual(stages, [.waiting, .unboxing, .inspecting, .rotating, .inserting, .revealing, .finished])
        XCTAssertEqual(store.insertion, 1)
        XCTAssertEqual(store.heroOpacity, 1)
        XCTAssertEqual(store.homeReveal, 1)
        XCTAssertEqual(feedback.preparations, 1)
        XCTAssertEqual(feedback.latches, 1)
        XCTAssertTrue(defaults.bool(forKey: OneTapeOpeningPreferences.completionKey))
        observation.cancel()
    }

    func testSkipDuringRotationCancelsPendingSoundAndCannotCompleteAReplay() async throws {
        let (_, preferences) = preferences()
        let feedback = OpeningFeedback()
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.08)
        store.openCase(reducedMotion: false)
        try await waitUntil { store.journey.stage == .inspecting }
        store.insert(reducedMotion: false)
        store.finish()
        store.replay()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(store.isVisible)
        XCTAssertEqual(store.journey.stage, .waiting)
        XCTAssertEqual(store.caseOpacity, 1)
        XCTAssertEqual(store.homeReveal, 0)
        XCTAssertEqual(feedback.latches, 0)
    }

    func testBackgroundDuringUnboxingCancelsAndCanRetryBothGestures() async throws {
        let (defaults, preferences) = preferences()
        let feedback = OpeningFeedback()
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.02)
        store.openCase(reducedMotion: false)
        store.suspend()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.journey.stage, .waiting)
        XCTAssertEqual(store.heroOpacity, 0)
        XCTAssertEqual(store.caseOpening, 0)
        XCTAssertFalse(defaults.bool(forKey: OneTapeOpeningPreferences.completionKey))
        store.openCase(reducedMotion: false)
        try await waitUntil { store.journey.stage == .inspecting }
        store.insert(reducedMotion: false)
        try await waitUntil { !store.isVisible }
        XCTAssertEqual(feedback.latches, 1)
        XCTAssertEqual(store.insertion, 1)
    }

    func testBackgroundDuringApproachCancelsCompletionAndPendingSound() async throws {
        let (defaults, preferences) = preferences()
        let feedback = OpeningFeedback()
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.1)
        store.openCase(reducedMotion: false)
        try await waitUntil { store.journey.stage == .inspecting }
        store.insert(reducedMotion: false)
        try await waitUntil { store.journey.stage == .inserting }
        XCTAssertEqual(feedback.latches, 0)
        store.suspend()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(store.insertion, 0)
        XCTAssertEqual(store.homeReveal, 0)
        XCTAssertEqual(store.journey.stage, .waiting)
        XCTAssertEqual(feedback.latches, 0)
        XCTAssertFalse(defaults.bool(forKey: OneTapeOpeningPreferences.completionKey))
    }

    func testReducedMotionStillWaitsForTwoActionsWithoutTurningOrSliding() async throws {
        let (_, preferences) = preferences()
        let feedback = OpeningFeedback()
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.05)
        store.openCase(reducedMotion: true)
        try await waitUntil { store.journey.stage == .inspecting }
        XCTAssertTrue(store.isVisible)
        XCTAssertEqual(store.caseOpening, 0)
        XCTAssertEqual(store.extraction, 0)
        store.insert(reducedMotion: true)
        XCTAssertEqual(store.clockwiseTurn, 0)
        XCTAssertEqual(store.insertion, 0)
        XCTAssertEqual(store.homeReveal, 0)
        XCTAssertEqual(feedback.latches, 0)
        try await waitUntil { !store.isVisible }
        XCTAssertEqual(store.homeReveal, 1)
        XCTAssertEqual(feedback.latches, 1)
    }

    func testUnavailableSoundStillOpensPlayerAndReportsAnExplicitNotice() async throws {
        let (_, preferences) = preferences()
        let feedback = OpeningFeedback()
        feedback.fail = true
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.01)
        store.openCase(reducedMotion: true)
        try await waitUntil { store.journey.stage == .inspecting }
        store.insert(reducedMotion: true)
        try await waitUntil { !store.isVisible }
        XCTAssertNotNil(store.notice)
    }

    func testDirectionsAndThresholdsKeepShortViewingDragsOutOfTheDeck() {
        func action(_ stage: OneTapeOpeningStage, _ x: CGFloat, _ y: CGFloat,
                    _ predictedX: CGFloat? = nil) -> OneTapeOpeningGesture.Action {
            OneTapeOpeningGesture.action(stage: stage, translation: CGSize(width: x, height: y),
                predicted: CGSize(width: predictedX ?? x, height: y), width: 393)
        }
        XCTAssertEqual(action(.waiting, 4, -90), .openCase)
        XCTAssertEqual(action(.waiting, 0, 150), .none)
        XCTAssertEqual(action(.waiting, -180, 2), .none)
        XCTAssertEqual(action(.inspecting, 140, 0), .none)
        XCTAssertEqual(action(.inspecting, -45, 0, -500), .none)
        XCTAssertEqual(action(.inspecting, -90, 0, -110), .none)
        XCTAssertEqual(action(.inspecting, -170, 8), .insert)
        XCTAssertEqual(action(.inspecting, -85, 5, -320), .insert)
        XCTAssertEqual(action(.inspecting, -160, -200), .none)
        XCTAssertEqual(action(.unboxing, -200, 0), .none)
        XCTAssertEqual(action(.rotating, -200, 0), .none)
        XCTAssertEqual(OneTapeOpeningGesture.yaw(translationX: 60, width: 393), 13.740458, accuracy: 0.001)
        XCTAssertEqual(OneTapeOpeningGesture.yaw(translationX: -1000, width: 393), -34)
        XCTAssertEqual(OneTapeOpeningGesture.yaw(translationX: .nan, width: 393), 0)
    }

    func testDockGeometryMatchesPlayerCanvasAcrossWindowSizes() {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852),
                     CGSize(width: 430, height: 932), CGSize(width: 852, height: 393)] {
            let layout = OneTapeOpeningLayout(size: size)
            let origin = CGPoint(x: (size.width - 393 * layout.playerScale) / 2,
                                 y: (size.height - 852 * layout.playerScale) / 2)
            XCTAssertEqual(layout.center(progress: 1).x,
                origin.x + (8.33 + 376.33 / 2) * layout.playerScale, accuracy: 0.001)
            XCTAssertEqual(layout.center(progress: 1).y,
                origin.y + (57.33 + 576 / 2) * layout.playerScale, accuracy: 0.001)
            XCTAssertLessThanOrEqual(598 * layout.looseScale, size.width)
        }
    }

    func testBundledClickCanPrepareWithoutReconfiguringTheMusicSession() throws {
        let session = AVAudioSession.sharedInstance()
        let category = session.category, mode = session.mode, options = session.categoryOptions
        let service = OneTapeOpeningFeedbackService()
        try service.prepare()
        service.stop()
        XCTAssertEqual(session.category, category)
        XCTAssertEqual(session.mode, mode)
        XCTAssertEqual(session.categoryOptions, options)
    }

    private func waitUntil(_ predicate: @escaping () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !predicate(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertTrue(predicate())
    }
}

@MainActor
private final class OpeningFeedback: OneTapeOpeningFeedbackProviding {
    var preparations = 0
    var latches = 0
    var fail = false
    var stops = 0
    var onLatch: (() -> Void)?
    func prepare() throws {
        preparations += 1
        if fail { throw OneTapeTransportSoundError.missingResource }
    }
    func latch() { latches += 1; onLatch?() }
    func stop() { stops += 1 }
}
