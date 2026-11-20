import XCTest
@testable import Stillroom

final class RecordOpeningControllerTests: XCTestCase {
    @MainActor func testSelectionAndVisualSettlingCannotStartAudio() async throws {
        let controller = RecordOpeningController()
        controller.select(trackID: "sea", reducedMotion: true)
        XCTAssertEqual(controller.journey.stage, .ready)
        XCTAssertEqual(controller.playerProgress, 1)
        controller.suspend()
        XCTAssertEqual(controller.journey.stage, .ready)
        XCTAssertFalse(controller.cueing)
    }

    @MainActor func testLeavingDuringNeedleDelayCannotCommitOldPlayback() async throws {
        let controller = RecordOpeningController()
        var commits: [String] = []
        controller.select(trackID: "sea", reducedMotion: true)
        controller.requestPlayback { commits.append($0) }
        controller.reset()
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertTrue(commits.isEmpty)
        XCTAssertEqual(controller.journey.stage, .list)
    }

    @MainActor func testResetBeforeNormalSelectionPublicationCannotReviveSleeve() async throws {
        let controller = RecordOpeningController()
        controller.select(trackID: "sea", reducedMotion: false)
        let cancelled = try XCTUnwrap(controller.journey.currentToken)
        XCTAssertEqual(controller.journey.stage, .openVinyl)
        XCTAssertEqual(controller.openProgress, 0)

        // The same MainActor turn resets before the deferred publication can run. Observe
        // well beyond its delay; this checks cancellation without an exact timing assertion.
        controller.reset()
        try await Task.sleep(for: .seconds(RecordOpeningTiming.selectionPublishDelay + 0.5))

        XCTAssertFalse(controller.journey.isCurrent(cancelled))
        XCTAssertNil(controller.journey.selectedTrackID)
        XCTAssertEqual(controller.journey.stage, .list)
        XCTAssertFalse(controller.journey.openingFinished)
        XCTAssertFalse(controller.journey.landscapeFinished)
        XCTAssertEqual(controller.openProgress, 0)
        XCTAssertEqual(controller.exitProgress, 0)
        XCTAssertEqual(controller.reveal, 0)
        XCTAssertEqual(controller.playerProgress, 0)
        XCTAssertFalse(controller.cueing)
    }

    @MainActor func testBackgroundAndReselectionInvalidateDelayedPlay() async throws {
        let controller = RecordOpeningController()
        var commits: [String] = []
        controller.select(trackID: "sea", reducedMotion: true)
        controller.requestPlayback { commits.append($0) }
        controller.suspend()
        controller.select(trackID: "night", reducedMotion: true)
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertTrue(commits.isEmpty)
        XCTAssertEqual(controller.journey.selectedTrackID, "night")
        XCTAssertEqual(controller.journey.stage, .ready)
    }

    @MainActor func testExplicitNeedleActionCommitsOnceAndPauseCanCancelRetry() async throws {
        let controller = RecordOpeningController()
        var commits: [String] = []
        controller.select(trackID: "sea", reducedMotion: true)
        controller.requestPlayback { commits.append($0) }
        controller.requestPlayback { commits.append("duplicate:" + $0) }
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(commits, ["sea"])
        controller.requestPlayback { commits.append($0) }
        controller.cancelPlayback()
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(commits, ["sea"])
    }
}
