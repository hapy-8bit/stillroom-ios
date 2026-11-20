import XCTest
import UIKit
@testable import Stillroom

@MainActor
final class OneTapeTrackWindupTests: XCTestCase {
    func testWindThenBrakeThenResumeNeverSeeksMediaTime() async throws {
        let probe = TrackWindProbe()
        let controller = probe.controller()
        try controller.begin(direction: 1)
        XCTAssertEqual(probe.rates, [14])
        XCTAssertEqual(probe.preparations, 1)
        XCTAssertEqual(probe.resumes, 0)
        let braked = await waitUntil { probe.rates.last == 0 }
        XCTAssertTrue(braked)
        XCTAssertEqual(probe.resumes, 0)
        let resumed = await waitUntil { probe.resumes == 1 }
        XCTAssertTrue(resumed)
        XCTAssertEqual(probe.rates, [14, 0, nil])
        XCTAssertFalse(controller.isActive)
    }

    func testCancelDuringBrakeCannotResumeLater() async throws {
        let probe = TrackWindProbe()
        let controller = probe.controller()
        try controller.begin(direction: -1)
        let braked = await waitUntil { probe.rates.last == 0 }
        XCTAssertTrue(braked)
        controller.cancel()
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertEqual(probe.rates, [-14, 0, nil])
        XCTAssertEqual(probe.resumes, 0)
        XCTAssertFalse(controller.isActive)
    }

    func testRapidReplacementCancelsOldGenerationAndResumesOnlyFinalTarget() async throws {
        let probe = TrackWindProbe()
        let controller = probe.controller()
        try controller.begin(direction: 1)
        probe.trackID = "two"
        probe.revision += 1
        try controller.begin(direction: -1)
        let resumed = await waitUntil { probe.resumes == 1 }
        XCTAssertTrue(resumed)
        XCTAssertEqual(probe.rates, [14, nil, -14, 0, nil])
        XCTAssertEqual(probe.resumedTrackIDs, ["two"])
    }

    func testSameTrackNewSelectionRevisionInvalidatesDelayedResume() async throws {
        let probe = TrackWindProbe()
        let controller = probe.controller()
        try controller.begin(direction: 1)
        probe.revision += 1
        let canceled = await waitUntil { !controller.isActive }
        XCTAssertTrue(canceled)
        XCTAssertEqual(probe.resumes, 0)
        XCTAssertEqual(probe.rates, [14, nil])
    }

    func testNewTrackInvalidatesDelayedResume() async throws {
        let probe = TrackWindProbe()
        let controller = probe.controller()
        try controller.begin(direction: 1)
        probe.trackID = "replacement"
        let canceled = await waitUntil { !controller.isActive }
        XCTAssertTrue(canceled)
        XCTAssertEqual(probe.resumes, 0)
        XCTAssertEqual(probe.rates, [14, nil])
    }

    func testPreparationFailurePublishesNoVisualWorkOrResume() throws {
        let probe = TrackWindProbe()
        probe.fails = true
        let controller = probe.controller()
        XCTAssertThrowsError(try controller.begin(direction: 1))
        XCTAssertTrue(probe.rates.isEmpty)
        XCTAssertEqual(probe.resumes, 0)
        XCTAssertFalse(controller.isActive)
    }

    func testInactiveSceneCancelsOldResume() async throws {
        let probe = TrackWindProbe()
        let controller = probe.controller()
        try controller.begin(direction: 1)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        defer { NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil) }
        let canceled = await waitUntil { !controller.isActive }
        XCTAssertTrue(canceled)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(probe.resumes, 0)
        XCTAssertEqual(probe.rates, [14, nil])
    }

    func testInvalidDirectionDoesNotPrepareOrAnimate() throws {
        let probe = TrackWindProbe()
        let controller = probe.controller()
        try controller.begin(direction: 0)
        XCTAssertEqual(probe.preparations, 0)
        XCTAssertTrue(probe.rates.isEmpty)
        XCTAssertFalse(controller.isActive)
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
}

@MainActor
private final class TrackWindProbe {
    var trackID = "one"
    var revision = 1
    var preparations = 0
    var resumes = 0
    var resumedTrackIDs: [String] = []
    var rates: [Double?] = []
    var fails = false

    func controller() -> OneTapeTrackWindupController {
        OneTapeTrackWindupController(timing: .init(wind: .milliseconds(100), brake: .milliseconds(100)),
            read: { [weak self] in
                guard let self else { return nil }
                return .init(trackID: self.trackID, selectionRevision: self.revision)
            }, prepare: { [weak self] in
                guard let self else { return }
                self.preparations += 1
                if self.fails { throw LibraryError.missingAudio }
            }, onRateChange: { [weak self] in self?.rates.append($0) },
            resumePlayback: { [weak self] in
                guard let self else { return }
                self.resumes += 1
                self.resumedTrackIDs.append(self.trackID)
            })
    }
}
