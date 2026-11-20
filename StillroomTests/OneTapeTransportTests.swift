import XCTest
import UIKit
@testable import Stillroom

@MainActor
final class OneTapeTransportTests: XCTestCase {
    func testPreviousThresholdIsStrictAndInvalidTimeDoesNotRestart() {
        XCTAssertEqual(OneTapeTransportRules.previousAction(position: 3), .previous)
        XCTAssertEqual(OneTapeTransportRules.previousAction(position: 3.001), .restart)
        XCTAssertEqual(OneTapeTransportRules.previousAction(position: 0), .previous)
        XCTAssertEqual(OneTapeTransportRules.previousAction(position: .nan), .previous)
    }

    func testWindingRateUsesSecondsAndNeverLeavesCurrentRecording() {
        XCTAssertEqual(OneTapeTransportRules.windingPosition(start: 10, elapsed: 0.5, direction: 1, duration: 30), 13)
        XCTAssertEqual(OneTapeTransportRules.windingPosition(start: 10, elapsed: 0.5, direction: -1, duration: 30), 7)
        XCTAssertEqual(OneTapeTransportRules.windingPosition(start: 10, elapsed: 100, direction: 1, duration: 30), 30)
        XCTAssertEqual(OneTapeTransportRules.windingPosition(start: 10, elapsed: 100, direction: -1, duration: 30), 0)
        XCTAssertEqual(OneTapeTransportRules.windingPosition(start: 10, elapsed: .nan, direction: 1, duration: 30), 0)
        XCTAssertEqual(OneTapeTransportRules.windingPosition(start: 10, elapsed: 1, direction: 1, duration: 0), 0)
    }

    func testReleaseRestoresOriginalPlayingIntentExactlyOnce() throws {
        let engine = WindEngine()
        engine.playing = true
        let controller = engine.controller()
        try controller.begin(direction: 1)
        XCTAssertFalse(engine.playing)
        controller.advance(elapsed: 0.5)
        XCTAssertEqual(engine.seeks, [13])
        // The controller only requests seeks; it does not invent engine time.
        XCTAssertEqual(engine.position, 10)
        controller.end()
        controller.end()
        XCTAssertTrue(engine.playing)
        XCTAssertEqual(engine.resumeCount, 1)
    }

    func testPausedOriginAndExplicitCancellationNeverStartPlayback() throws {
        let engine = WindEngine()
        let controller = engine.controller()
        try controller.begin(direction: -1)
        controller.advance(elapsed: 0.5)
        controller.end()
        XCTAssertEqual(engine.seeks, [7])
        XCTAssertEqual(engine.resumeCount, 0)
        engine.playing = true
        try controller.begin(direction: 1)
        controller.cancel()
        controller.end()
        controller.advance(elapsed: 20)
        XCTAssertFalse(engine.playing)
        XCTAssertEqual(engine.resumeCount, 0)
        XCTAssertEqual(engine.seeks, [7])
    }

    func testSwitchingDirectionRetainsPreWindIntentAndBoundsAreNotRepeated() throws {
        let engine = WindEngine()
        engine.playing = true
        let controller = engine.controller()
        try controller.begin(direction: 1)
        try controller.begin(direction: -1)
        controller.advance(elapsed: 5)
        controller.advance(elapsed: 6)
        XCTAssertEqual(engine.seeks, [0])
        controller.end()
        XCTAssertTrue(engine.playing)
        XCTAssertEqual(engine.resumeCount, 1)
    }

    func testTrackReplacementInvalidatesPendingWindAndRelease() throws {
        let engine = WindEngine()
        engine.playing = true
        let controller = engine.controller()
        try controller.begin(direction: 1)
        engine.trackID = "replacement"
        controller.advance(elapsed: 1)
        controller.end()
        XCTAssertFalse(controller.isWinding)
        XCTAssertTrue(engine.seeks.isEmpty)
        XCTAssertEqual(engine.resumeCount, 0)
    }

    func testFailedPreparationHasNoActiveTaskOrResumeIntent() throws {
        let engine = WindEngine()
        engine.playing = true
        engine.shouldFail = true
        let controller = engine.controller()
        XCTAssertThrowsError(try controller.begin(direction: 1))
        controller.advance(elapsed: 1)
        controller.end()
        XCTAssertFalse(controller.isWinding)
        XCTAssertTrue(engine.seeks.isEmpty)
        XCTAssertEqual(engine.resumeCount, 0)
    }

    func testCanceledTimerCannotSeekNewRecording() async throws {
        let engine = WindEngine()
        let controller = engine.controller()
        try controller.begin(direction: 1)
        controller.cancel()
        engine.trackID = "replacement"
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(engine.seeks.isEmpty)
        XCTAssertFalse(controller.isWinding)
    }

    func testInactiveSceneCancelsBeforeLateGestureRelease() async throws {
        let engine = WindEngine()
        engine.playing = true
        let controller = engine.controller()
        try controller.begin(direction: 1)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        defer { NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil) }
        for _ in 0..<10 {
            if !controller.isWinding { break }
            await Task.yield()
        }
        controller.end()
        XCTAssertFalse(controller.isWinding)
        XCTAssertFalse(engine.playing)
        XCTAssertEqual(engine.resumeCount, 0)
    }

    func testWindingSeeksRealEngineResumesIntentAndCannotReachReplacement() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "OneTape.wind.engine." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let player = PlayerStore(directory: directory, defaults: defaults, sampleTracks: Track.demos)
        defer {
            player.pause()
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        await player.restore()
        player.choose(Track.demos[0], in: Track.demos)
        let began = await waitUntil { player.isPlaying }
        XCTAssertTrue(began)
        player.seek(10)
        let sought = await waitUntil { abs(player.position - 10) < 0.4 }
        XCTAssertTrue(sought)
        player.beginWinding(direction: 1)
        let wound = await waitUntil { player.position >= 11 }
        XCTAssertTrue(wound)
        XCTAssertFalse(player.isPlaying)
        player.endWinding()
        let resumed = await waitUntil { player.isPlaying }
        XCTAssertTrue(resumed)
        player.pause()
        let pausedAt = player.position
        player.beginWinding(direction: -1)
        let rewound = await waitUntil { player.position < pausedAt - 0.5 }
        XCTAssertTrue(rewound)
        player.endWinding()
        XCTAssertFalse(player.isPlaying)
        player.beginWinding(direction: 1)
        player.choose(Track.demos[1], in: Track.demos, autoplay: false)
        try await Task.sleep(for: .milliseconds(250))
        player.endWinding()
        XCTAssertEqual(player.currentTrack?.id, "window")
        XCTAssertEqual(player.position, 0)
        XCTAssertFalse(player.isPlaying)
    }

    func testTapePreviousWrapsAtStartWithoutChangingLegacySkip() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "OneTape.previous." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        let player = PlayerStore(directory: directory, defaults: defaults, sampleTracks: Track.demos)
        await player.restore()
        player.choose(Track.demos[0], in: Track.demos, autoplay: false)
        player.previousForTape()
        XCTAssertEqual(player.currentTrack?.id, "night")
        player.choose(Track.demos[0], in: Track.demos, autoplay: false)
        player.seek(8)
        let reached = await waitUntil { abs(player.position - 8) < 0.2 }
        XCTAssertTrue(reached)
        player.previousForTape()
        XCTAssertEqual(player.currentTrack?.id, "sea")
        let restarted = await waitUntil { player.position < 0.2 }
        XCTAssertTrue(restarted)
        player.seek(8)
        let soughtAgain = await waitUntil { abs(player.position - 8) < 0.2 }
        XCTAssertTrue(soughtAgain)
        player.skip(-1)
        XCTAssertEqual(player.currentTrack?.id, "night", "Legacy skip retains direct previous-track behavior")
        player.pause()
    }

    func testRapidQueueNavigationDuringPreparationKeepsPlayIntentOnlyForFinalSong() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "OneTape.rapid-queue." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let player = PlayerStore(directory: directory, defaults: defaults, sampleTracks: Track.demos)
        defer {
            player.pause()
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        await player.restore()
        player.choose(Track.demos[0], in: Track.demos)
        // No MainActor suspension between commands: the audio activation is
        // pending, so isPlaying alone cannot represent the user's play intent.
        XCTAssertTrue(player.snapshot.isPreparing)
        player.skip(1)
        XCTAssertEqual(player.current.id, "window")
        XCTAssertTrue(player.snapshot.isPreparing)
        player.skip(1)
        player.skip(-1)
        XCTAssertEqual(player.current.id, "window")
        let began = await waitUntil { player.isPlaying }
        XCTAssertTrue(began)
        XCTAssertEqual(player.recentlyPlayedTrackIDs, ["window"],
                       "Superseded preparation must not fabricate listening history")
        player.pause()
        player.skip(1)
        XCTAssertEqual(player.current.id, "night")
        XCTAssertFalse(player.snapshot.isPreparing)
        XCTAssertFalse(player.isPlaying, "Manual navigation from paused remains paused")
    }

    func testNaturalQueueEndColdRestoreRemainsPausedAndPlayRestartsFirstSong() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "OneTape.queue-end." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let player = PlayerStore(directory: directory, defaults: defaults, sampleTracks: Track.demos)
        var reopened: PlayerStore?
        defer {
            player.pause(); reopened?.pause()
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        await player.restore()
        player.choose(Track.demos[2], in: Track.demos)
        let began = await waitUntil { player.isPlaying }
        XCTAssertTrue(began)
        player.seek(max(0, player.duration - 0.15))
        let ended = await waitUntil { player.queueFinished }
        XCTAssertTrue(ended, "Wait for the real decoder completion, not a simulated skip")
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.current.id, "night")
        player.checkpoint()
        let restored = PlayerStore(directory: directory, defaults: defaults, sampleTracks: Track.demos)
        reopened = restored
        await restored.restore()
        XCTAssertTrue(restored.queueFinished)
        XCTAssertFalse(restored.isPlaying)
        restored.play()
        let restarted = await waitUntil { restored.isPlaying }
        XCTAssertTrue(restarted)
        XCTAssertEqual(restored.current.id, "sea")
        XCTAssertFalse(restored.queueFinished)
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }
}

@MainActor
private final class WindEngine {
    var trackID = "one"
    var position = 10.0
    var playing = false
    var shouldFail = false
    var seeks: [TimeInterval] = []
    var resumeCount = 0

    func controller() -> OneTapeWindingController {
        OneTapeWindingController(read: { [weak self] in
            guard let self else { return nil }
            return .init(trackID: self.trackID, position: self.position, duration: 30, wasPlaying: self.playing)
        }, prepare: { [weak self] in
            guard let self else { return }
            if self.shouldFail { throw LibraryError.missingAudio }
            self.playing = false
        }, seek: { [weak self] in self?.seeks.append($0) },
        resumePlayback: { [weak self] in self?.playing = true; self?.resumeCount += 1 })
    }
}
