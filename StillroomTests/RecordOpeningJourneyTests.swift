import CoreGraphics
import XCTest
@testable import Stillroom

final class RecordOpeningJourneyTests: XCTestCase {
    func testOpeningMilestonesCannotTriggerPlaybackOrSkipTheOpeningGate() throws {
        var journey = RecordOpeningJourney()
        let token = try XCTUnwrap(journey.select(trackID: "sea"))
        XCTAssertEqual(journey.stage, .openVinyl)
        XCTAssertFalse(journey.enterPlayer(token: token))
        XCTAssertFalse(journey.finishLandscapeTransition(token: token))
        XCTAssertNil(journey.requestPlayback(token: token))

        XCTAssertTrue(journey.finishOpening(token: token))
        XCTAssertFalse(journey.finishOpening(token: token))
        XCTAssertFalse(journey.enterPlayer(token: token))
        XCTAssertTrue(journey.finishLandscapeTransition(token: token))
        XCTAssertTrue(journey.enterPlayer(token: token))
        XCTAssertEqual(journey.stage, .ready)
        XCTAssertEqual(journey.presentationStage(isPlaying: false, playingTrackID: "sea"), .ready)
        XCTAssertEqual(journey.presentationStage(isPlaying: true, playingTrackID: "sea"), .playing)
    }

    func testRapidReselectionRejectsEveryOldTransitionAndPlaybackCallback() throws {
        var journey = RecordOpeningJourney()
        let first = try XCTUnwrap(journey.select(trackID: "sea"))
        XCTAssertTrue(journey.finishOpening(token: first))
        XCTAssertTrue(journey.finishLandscapeTransition(token: first))
        XCTAssertTrue(journey.enterPlayer(token: first))
        let oldPlay = try XCTUnwrap(journey.requestPlayback(token: first))
        let replacement = try XCTUnwrap(journey.select(trackID: "window"))

        XCTAssertFalse(journey.finishOpening(token: first))
        XCTAssertFalse(journey.finishLandscapeTransition(token: first))
        XCTAssertFalse(journey.enterPlayer(token: first))
        XCTAssertNil(journey.consumePlayback(oldPlay))
        XCTAssertNil(journey.requestPlayback(token: first))
        XCTAssertEqual(journey.selectedTrackID, "window")
        XCTAssertTrue(journey.finishOpening(token: replacement))
        XCTAssertTrue(journey.finishLandscapeTransition(token: replacement))
        XCTAssertTrue(journey.enterPlayer(token: replacement))
        XCTAssertEqual(journey.presentationStage(isPlaying: false, playingTrackID: "window"), .ready)
    }

    func testSelectingTheSameTrackAgainStillInvalidatesItsOldGeneration() throws {
        var journey = RecordOpeningJourney()
        let previous = try XCTUnwrap(journey.select(trackID: "sea"))
        let current = try XCTUnwrap(journey.select(trackID: "sea"))
        XCTAssertNotEqual(previous, current)
        XCTAssertFalse(journey.isCurrent(previous))
        XCTAssertFalse(journey.finishOpening(token: previous))
        XCTAssertTrue(journey.isCurrent(current))
    }

    func testBackgroundOrExitCancelsPendingAudioAndAllVisualWork() throws {
        var journey = RecordOpeningJourney()
        let token = try XCTUnwrap(journey.select(trackID: "night"))
        XCTAssertTrue(journey.finishOpening(token: token))
        XCTAssertTrue(journey.finishLandscapeTransition(token: token))
        XCTAssertTrue(journey.enterPlayer(token: token))
        let request = try XCTUnwrap(journey.requestPlayback(token: token))

        journey.cancel()
        XCTAssertEqual(journey.stage, .list)
        XCTAssertNil(journey.selectedTrackID)
        XCTAssertFalse(journey.isCurrent(request))
        XCTAssertNil(journey.consumePlayback(request))
        XCTAssertFalse(journey.enterPlayer(token: token))
        XCTAssertEqual(journey.presentationStage(isPlaying: true, playingTrackID: "night"), .list)
    }

    func testPlayTicketIsConsumedAtMostOnceAndPauseCanInvalidateItWithoutClosingTheRecord() throws {
        var journey = RecordOpeningJourney()
        let token = try XCTUnwrap(journey.select(trackID: "sea"))
        XCTAssertTrue(journey.finishOpening(token: token))
        XCTAssertTrue(journey.finishLandscapeTransition(token: token))
        XCTAssertTrue(journey.enterPlayer(token: token))
        let cancelled = try XCTUnwrap(journey.requestPlayback(token: token))
        XCTAssertNil(journey.requestPlayback(token: token))
        journey.cancelPendingPlayback()
        XCTAssertEqual(journey.stage, .ready)
        XCTAssertNil(journey.consumePlayback(cancelled))

        let fresh = try XCTUnwrap(journey.requestPlayback(token: token))
        XCTAssertNotEqual(cancelled, fresh)
        XCTAssertEqual(journey.consumePlayback(fresh), "sea")
        XCTAssertNil(journey.consumePlayback(fresh))
        let retry = try XCTUnwrap(journey.requestPlayback(token: token))
        XCTAssertEqual(journey.consumePlayback(retry), "sea")
    }

    func testPlayerMilestoneRejectsOutOfOrderAndDuplicateCallbacks() throws {
        var journey = RecordOpeningJourney()
        let token = try XCTUnwrap(journey.select(trackID: "sea"))
        XCTAssertFalse(journey.finishLandscapeTransition(token: token))
        XCTAssertFalse(journey.enterPlayer(token: token))
        XCTAssertTrue(journey.finishOpening(token: token))
        XCTAssertFalse(journey.enterPlayer(token: token))
        XCTAssertTrue(journey.finishLandscapeTransition(token: token))
        XCTAssertTrue(journey.enterPlayer(token: token))
        XCTAssertTrue(journey.openingFinished)
        XCTAssertTrue(journey.landscapeFinished)
        XCTAssertFalse(journey.finishLandscapeTransition(token: token))
        XCTAssertFalse(journey.enterPlayer(token: token))
    }

    func testInvalidSelectionDoesNotDestroyTheCurrentJourney() throws {
        var journey = RecordOpeningJourney()
        let token = try XCTUnwrap(journey.select(trackID: "sea"))
        XCTAssertNil(journey.select(trackID: " \n"))
        XCTAssertTrue(journey.isCurrent(token))
        XCTAssertEqual(journey.selectedTrackID, "sea")
    }

    func testAnOlderPlayingTrackCannotMakeTheNewPreviewAppearToPlay() throws {
        var journey = RecordOpeningJourney()
        let token = try XCTUnwrap(journey.select(trackID: "window"))
        XCTAssertTrue(journey.finishOpening(token: token))
        XCTAssertTrue(journey.finishLandscapeTransition(token: token))
        XCTAssertTrue(journey.enterPlayer(token: token))
        XCTAssertEqual(journey.presentationStage(isPlaying: true, playingTrackID: "sea"), .ready)
        XCTAssertEqual(journey.presentationStage(isPlaying: true, playingTrackID: nil), .ready)
        XCTAssertEqual(journey.presentationStage(isPlaying: true, playingTrackID: "window"), .playing)
    }

    func testArtworkCoordinatesUseMeasuredViewportOriginAndRetainOffscreenCrop() {
        let viewport = CGRect(x: 30, y: 90, width: 390, height: 700)
        let source = CGRect(x: -10, y: 120, width: 220, height: 220)
        let destination = CGRect(x: -80, y: 60, width: 460, height: 460)
        let local = RecordOpeningGeometry.localFrame(source, in: viewport)
        XCTAssertEqual(local, CGRect(x: -40, y: 30, width: 220, height: 220))
        XCTAssertEqual(RecordOpeningGeometry.interpolatedFrame(from: local, to: destination, progress: 0), local)
        XCTAssertEqual(RecordOpeningGeometry.interpolatedFrame(from: local, to: destination, progress: 1), destination)
        let halfway = RecordOpeningGeometry.interpolatedFrame(from: local, to: destination, progress: 0.5)
        XCTAssertEqual(halfway, CGRect(x: -60, y: 45, width: 340, height: 340))
    }

    func testGeometryRejectsInvalidSizesAndDoesNotTreatMediaSecondsAsVisualProgress() {
        XCTAssertEqual(RecordOpeningGeometry.clampedProgress(.nan), 0)
        XCTAssertEqual(RecordOpeningGeometry.clampedProgress(-1), 0)
        XCTAssertEqual(RecordOpeningGeometry.clampedProgress(2), 1)
        XCTAssertEqual(RecordOpeningGeometry.progress(elapsed: 0.25, duration: 0.5), 0.5)
        XCTAssertEqual(RecordOpeningGeometry.progress(elapsed: .infinity, duration: 1), 0)
        XCTAssertEqual(RecordOpeningGeometry.progress(elapsed: 1, duration: 0), 0)
        XCTAssertNil(RecordOpeningGeometry.referencePhoneScale(container: .zero))
        XCTAssertNil(RecordOpeningGeometry.referencePhoneScale(container: CGSize(width: CGFloat.nan, height: 800)))
        let invalid = CGRect(x: CGFloat.nan, y: CGFloat.infinity, width: -20, height: CGFloat.nan)
        XCTAssertEqual(RecordOpeningGeometry.localFrame(invalid, in: .zero), .zero)
    }

    func testRecoveredPhoneScaleUsesTheWindowAspectBoundary() throws {
        XCTAssertEqual(try XCTUnwrap(RecordOpeningGeometry.referencePhoneScale(container: CGSize(width: 375, height: 750))), 1)
        XCTAssertEqual(try XCTUnwrap(RecordOpeningGeometry.referencePhoneScale(container: CGSize(width: 390, height: 844))), 390 / 375.0, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(RecordOpeningGeometry.referencePhoneScale(container: CGSize(width: 844, height: 390))), 390 / 750.0, accuracy: 0.000001)
    }
}
