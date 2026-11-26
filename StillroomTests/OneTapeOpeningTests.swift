import AVFoundation
import Combine
import SwiftUI
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

    func testPartialTearPreservesNotchAndDoesNotCompleteOpening() {
        let (defaults, preferences) = preferences()
        let feedback = OpeningFeedback()
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.02)

        store.updateTear(translationX: 90, trackWidth: 300, reducedMotion: false)
        XCTAssertEqual(store.journey.stage, .tearing)
        XCTAssertEqual(store.tearProgress, 0.30, accuracy: 0.001)
        XCTAssertGreaterThan(feedback.ticks, 0)

        store.endTear(predictedTranslationX: 95, trackWidth: 300, reducedMotion: false)
        XCTAssertEqual(store.journey.stage, .sealed)
        XCTAssertEqual(store.tearProgress, 0.30, accuracy: 0.001)
        XCTAssertTrue(store.isVisible)
        XCTAssertEqual(feedback.snaps, 0)
        XCTAssertFalse(defaults.bool(forKey: OneTapeOpeningPreferences.completionKey))
    }

    func testFullRightDragCommitsStripSnapPeelAndCompletion() async throws {
        let (defaults, preferences) = preferences()
        let feedback = OpeningFeedback()
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.04)
        var stages: [OneTapeOpeningStage] = []
        let observation = store.$journey.sink { stages.append($0.stage) }

        store.updateTear(translationX: 120, trackWidth: 300, reducedMotion: false)
        store.updateTear(translationX: 210, trackWidth: 300, reducedMotion: false)
        store.endTear(predictedTranslationX: 240, trackWidth: 300, reducedMotion: false)

        XCTAssertEqual(store.journey.stage, .peeling)
        XCTAssertEqual(feedback.snaps, 1)
        XCTAssertFalse(defaults.bool(forKey: OneTapeOpeningPreferences.completionKey))

        try await waitUntil { !store.isVisible }
        XCTAssertEqual(stages, [.sealed, .tearing, .peeling, .finished])
        XCTAssertEqual(store.tearProgress, 1)
        XCTAssertEqual(store.stripDetachment, 1)
        XCTAssertEqual(store.sleevePeel, 1)
        XCTAssertEqual(store.sleeveOpacity, 0)
        XCTAssertEqual(feedback.preparations, 1)
        XCTAssertEqual(feedback.latches, 1)
        XCTAssertTrue(defaults.bool(forKey: OneTapeOpeningPreferences.completionKey))
        observation.cancel()
    }

    func testSkipAndReplayResetOpeningCleanlyWithoutStaleCompletion() async throws {
        let (_, preferences) = preferences()
        let feedback = OpeningFeedback()
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.08)

        store.commitUnwrap(reducedMotion: false)
        store.finish()
        store.replay()
        try await Task.sleep(for: .milliseconds(160))

        XCTAssertTrue(store.isVisible)
        XCTAssertEqual(store.journey.stage, .sealed)
        XCTAssertEqual(store.tearProgress, 0)
        XCTAssertEqual(store.sleevePeel, 0)
        XCTAssertEqual(store.sleeveOpacity, 1)
        XCTAssertEqual(feedback.latches, 0)
    }

    func testBackgroundDuringPeelCancelsCompletionAndResetsSleeve() async throws {
        let (defaults, preferences) = preferences()
        let feedback = OpeningFeedback()
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.1)

        store.commitUnwrap(reducedMotion: false)
        XCTAssertEqual(store.journey.stage, .peeling)
        store.suspend()
        try await Task.sleep(for: .milliseconds(180))

        XCTAssertEqual(store.journey.stage, .sealed)
        XCTAssertEqual(store.tearProgress, 0)
        XCTAssertEqual(store.sleevePeel, 0)
        XCTAssertEqual(feedback.latches, 0)
        XCTAssertFalse(defaults.bool(forKey: OneTapeOpeningPreferences.completionKey))
    }

    func testReducedMotionUnwrapCompletesWithoutSlideMotion() async throws {
        let (_, preferences) = preferences()
        let feedback = OpeningFeedback()
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.04)

        XCTAssertEqual(store.playerPose(reducedMotion: true)?.deckScale, 1)
        XCTAssertTrue(store.commitUnwrap(reducedMotion: true))
        XCTAssertEqual(feedback.snaps, 1)
        try await waitUntil { !store.isVisible }
        XCTAssertEqual(store.sleeveOpacity, 0)
        XCTAssertEqual(feedback.latches, 1)
    }

    func testUnavailableSoundStillCompletesAndReportsExplicitNotice() async throws {
        let (_, preferences) = preferences()
        let feedback = OpeningFeedback()
        feedback.fail = true
        let store = OneTapeOpeningStore(preferences: preferences, feedback: feedback, durationScale: 0.02)

        store.commitUnwrap(reducedMotion: true)
        try await waitUntil { !store.isVisible }
        XCTAssertNotNil(store.notice)
    }

    func testTearRulesBidirectionalZipperCommitThresholdsAndDetents() {
        XCTAssertEqual(OneTapeOpeningTearRules.progress(baseProgress: 0.5, translationX: -60, trackWidth: 300), 0.3, accuracy: 0.001)
        XCTAssertEqual(OneTapeOpeningTearRules.progress(baseProgress: 0.3, translationX: 150, trackWidth: 300), 0.8, accuracy: 0.001)
        XCTAssertEqual(OneTapeOpeningTearRules.progress(baseProgress: .nan, translationX: 50, trackWidth: 0), 0)

        XCTAssertTrue(OneTapeOpeningTearRules.shouldCommit(progress: 0.72, predictedTranslationX: 100, trackWidth: 300))
        XCTAssertTrue(OneTapeOpeningTearRules.shouldCommit(progress: 0.30, predictedTranslationX: 150, trackWidth: 300))
        XCTAssertFalse(OneTapeOpeningTearRules.shouldCommit(progress: 0.30, predictedTranslationX: 80, trackWidth: 300))
        XCTAssertFalse(OneTapeOpeningTearRules.shouldCommit(progress: 0.10, predictedTranslationX: 250, trackWidth: 300))

        XCTAssertEqual(OneTapeOpeningTearRules.detentIndex(for: 0), 0)
        XCTAssertEqual(OneTapeOpeningTearRules.detentIndex(for: 1), OneTapeOpeningTearRules.perforationSteps)
    }

    func testBundledSoundsPrepareWithoutReconfiguringMusicSession() throws {
        let session = AVAudioSession.sharedInstance()
        let category = session.category, mode = session.mode, options = session.categoryOptions
        let service = OneTapeOpeningFeedbackService()
        try service.prepare()
        service.stop()
        XCTAssertEqual(session.category, category)
        XCTAssertEqual(session.mode, mode)
        XCTAssertEqual(session.categoryOptions, options)
    }

    func testNewOpeningSceneRendersCleanlyInSealedAndMidTearStates() {
        let (_, prefs) = preferences()
        let store = OneTapeOpeningStore(preferences: prefs, feedback: OpeningFeedback())
        let sealedView = ZStack {
            Color(red: 0.14, green: 0.14, blue: 0.15)
            OneTapeOpeningScene(
                opening: store,
                safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
                reducedMotion: false,
                onCommitUnwrap: {},
                onSkip: {}
            )
        }
        .frame(width: 402, height: 874)

        let sealedRenderer = ImageRenderer(content: sealedView)
        sealedRenderer.scale = 2
        if let image = sealedRenderer.uiImage {
            let attachment = XCTAttachment(image: image)
            attachment.name = "opening-new-01-sealed"
            attachment.lifetime = .keepAlways
            add(attachment)
        } else {
            XCTFail("Failed to render sealed opening")
        }

        store.updateTear(translationX: 140, trackWidth: 280, reducedMotion: false)
        let midRenderer = ImageRenderer(content: sealedView)
        midRenderer.scale = 2
        if let image = midRenderer.uiImage {
            let attachment = XCTAttachment(image: image)
            attachment.name = "opening-new-02-mid-tear"
            attachment.lifetime = .keepAlways
            add(attachment)
        } else {
            XCTFail("Failed to render mid-tear opening")
        }
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
    var ticks = 0
    var snaps = 0
    var latches = 0
    var fail = false
    var stops = 0

    func prepare() throws {
        preparations += 1
        if fail { throw OneTapeTransportSoundError.missingResource }
    }
    func tickPerforation() { ticks += 1 }
    func snapStrip() { snaps += 1 }
    func latch() { latches += 1 }
    func stop() { stops += 1 }
}
