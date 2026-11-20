import XCTest
import AVFoundation
@testable import Stillroom

final class OneTapeLibraryFeedbackTests: XCTestCase {
    func testRestorationAndRepeatedCenterDoNotCreateDetents() {
        var policy = OneTapeLibraryBrowseFeedbackPolicy()
        XCTAssertFalse(policy.handle(.crossed("a"), now: 1))
        XCTAssertFalse(policy.handle(.crossed("b"), now: 2))
        XCTAssertFalse(policy.handle(.began(currentID: "b"), now: 3))
        XCTAssertFalse(policy.handle(.crossed("b"), now: 3.1))
        XCTAssertTrue(policy.handle(.crossed("c"), now: 3.2))
        XCTAssertFalse(policy.handle(.crossed("c"), now: 4))
    }

    func testFastFlingIsBoundedAndStoppingPreventsLateFeedback() {
        var policy = OneTapeLibraryBrowseFeedbackPolicy()
        XCTAssertFalse(policy.handle(.began(currentID: "a"), now: 1))
        XCTAssertTrue(policy.handle(.crossed("b"), now: 1.1))
        XCTAssertFalse(policy.handle(.crossed("c"), now: 1.12))
        XCTAssertTrue(policy.handle(.crossed("d"), now: 1.2))
        XCTAssertFalse(policy.handle(.ended, now: 1.3))
        XCTAssertFalse(policy.handle(.crossed("e"), now: 1.4))
        XCTAssertFalse(policy.handle(.began(currentID: "e"), now: 2))
        XCTAssertTrue(policy.handle(.crossed("d"), now: 2.1))
    }

    func testMissingInitialTargetAndInvalidTimeRemainSilent() {
        var policy = OneTapeLibraryBrowseFeedbackPolicy()
        XCTAssertFalse(policy.handle(.began(currentID: nil), now: 1))
        XCTAssertFalse(policy.handle(.crossed("a"), now: 1.1))
        XCTAssertFalse(policy.handle(.crossed("b"), now: .nan))
        XCTAssertTrue(policy.handle(.crossed("c"), now: 1.3))
    }

    @MainActor
    func testEachAcceptedSpineCrossingPairsOneSoundWithOneHapticAndCancelsOnExit() {
        let voice = LibraryCueVoice()
        var cues: [OneTapeTransportCue] = []
        let sound = OneTapeTransportSoundService(makePlayer: { cue in cues.append(cue); return voice })
        let haptic = LibraryHaptic()
        let service = OneTapeLibraryFeedbackService(sound: sound, haptic: haptic)
        service.handle(.crossed("a"), now: 1)
        service.handle(.began(currentID: "a"), now: 2)
        service.handle(.crossed("b"), now: 2.1)
        service.handle(.crossed("b"), now: 2.2)
        service.handle(.crossed("c"), now: 2.3)
        XCTAssertEqual(cues, [.trackStep, .trackStep])
        XCTAssertEqual(haptic.selections, 2)
        XCTAssertEqual(haptic.preparations, 3)
        let stale = voice.onFailure
        service.stop()
        stale?()
        service.handle(.crossed("d"), now: 3)
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(haptic.selections, 2)
        XCTAssertNil(voice.onFailure)
        XCTAssertGreaterThan(voice.stops, 0)
    }

    @MainActor
    func testAudioFailureIsExplicitWithoutDisablingSelectionHapticsOrRepeatingAnAlert() {
        let haptic = LibraryHaptic()
        let sound = OneTapeTransportSoundService(makePlayer: { _ in
            throw OneTapeTransportSoundError.missingResource
        })
        let service = OneTapeLibraryFeedbackService(sound: sound, haptic: haptic)
        var errors: [OneTapeTransportSoundError] = []
        service.onFailure = { errors.append($0) }
        service.handle(.began(currentID: "a"), now: 1)
        service.handle(.crossed("b"), now: 1.1)
        service.handle(.crossed("c"), now: 1.2)
        XCTAssertEqual(errors, [.missingResource])
        XCTAssertEqual(haptic.selections, 2)
    }

    @MainActor
    func testQuietBundledShelfVoiceCompletesWithoutChangingMusicSessionCategory() async throws {
        let session = AVAudioSession.sharedInstance()
        let category = session.category, mode = session.mode
        let voice = try OneTapeTransportSoundService.bundledPlayer(.trackStep, volume: 0.23)
        let finished = expectation(description: "The actual quiet library voice finishes")
        var failed = false
        voice.onFinish = { finished.fulfill() }
        voice.onFailure = { failed = true; finished.fulfill() }
        XCTAssertTrue(voice.play())
        await fulfillment(of: [finished], timeout: 10)
        XCTAssertFalse(failed)
        XCTAssertEqual(session.category, category)
        XCTAssertEqual(session.mode, mode)
        voice.stop()
    }
}

@MainActor
private final class LibraryHaptic: OneTapeLibraryHapticProviding {
    var preparations = 0
    var selections = 0
    func prepare() { preparations += 1 }
    func selectionChanged() { selections += 1 }
}

@MainActor
private final class LibraryCueVoice: OneTapeTransportCuePlaying {
    var onFinish: (() -> Void)?
    var onFailure: (() -> Void)?
    var stops = 0
    func play() -> Bool { true }
    func stop() { stops += 1 }
}
