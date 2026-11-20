import XCTest
@testable import Stillroom

@MainActor
final class OneTapeTrackWindupIntegrationTests: XCTestCase {
    func testPlayingStepKeepsRealEngineSilentThroughFastWindAndBrake() async throws {
        let fixture = try TrackWindFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        fixture.player.choose(Track.demos[0], in: Track.demos)
        let began = await waitUntil { fixture.player.isPlaying }
        XCTAssertTrue(began)
        let start = ContinuousClock.now
        fixture.store.stepTrackForTape(1)
        XCTAssertEqual(fixture.player.current.id, "window")
        XCTAssertFalse(fixture.player.isPlaying)
        XCTAssertFalse(fixture.player.snapshot.isPreparing)
        XCTAssertEqual(fixture.player.tapeTrackMotionRate, 14)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertFalse(fixture.player.isPlaying)
        XCTAssertLessThan(fixture.player.position, 0.05)
        let braked = await waitUntil { fixture.player.tapeTrackMotionRate == 0 }
        XCTAssertTrue(braked)
        XCTAssertFalse(fixture.player.isPlaying)
        let resumed = await waitUntil { fixture.player.isPlaying && fixture.player.position > 0.05 }
        XCTAssertTrue(resumed)
        XCTAssertGreaterThanOrEqual(start.duration(to: .now), .milliseconds(780))
        XCTAssertNil(fixture.player.tapeTrackMotionRate)
        XCTAssertEqual(fixture.player.current.id, "window")
    }

    func testPendingPlayKeyCancelsWithoutStartingSelectedSong() async throws {
        let fixture = try TrackWindFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        fixture.player.choose(Track.demos[0], in: Track.demos)
        let began = await waitUntil { fixture.player.isPlaying }
        XCTAssertTrue(began)
        fixture.store.stepTrackForTape(1)
        XCTAssertTrue(fixture.player.isTapeTrackChanging)
        fixture.store.togglePlaybackForTape()
        XCTAssertFalse(fixture.player.isTapeTrackChanging)
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(fixture.player.current.id, "window")
        XCTAssertFalse(fixture.player.isPlaying)
        XCTAssertFalse(fixture.player.snapshot.isPreparing)
        XCTAssertFalse(fixture.player.recentlyPlayedTrackIDs.contains("window"))
    }

    func testRapidTrackKeysRetainOriginalIntentOnlyForFinalSelection() async throws {
        let fixture = try TrackWindFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        fixture.player.choose(Track.demos[0], in: Track.demos)
        let began = await waitUntil { fixture.player.isPlaying }
        XCTAssertTrue(began)
        fixture.store.stepTrackForTape(1)
        fixture.store.stepTrackForTape(1)
        fixture.store.stepTrackForTape(-1)
        XCTAssertEqual(fixture.player.current.id, "window")
        XCTAssertEqual(fixture.player.tapeTrackMotionRate, -14)
        let resumed = await waitUntil { fixture.player.isPlaying }
        XCTAssertTrue(resumed)
        XCTAssertEqual(fixture.player.current.id, "window")
        XCTAssertFalse(fixture.player.recentlyPlayedTrackIDs.contains("night"))
        XCTAssertNil(fixture.player.tapeTrackMotionRate)
    }

    func testPausedNavigationRemainsImmediateAndDoesNotCreateWindup() async throws {
        let fixture = try TrackWindFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        fixture.player.choose(Track.demos[0], in: Track.demos, autoplay: false)
        fixture.store.stepTrackForTape(1)
        XCTAssertEqual(fixture.player.current.id, "window")
        XCTAssertFalse(fixture.player.isPlaying)
        XCTAssertNil(fixture.player.tapeTrackMotionRate)
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertFalse(fixture.player.isPlaying)
    }

    func testExternalSelectionAndInactiveSceneCannotBeResumedByOldTask() async throws {
        let fixture = try TrackWindFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        fixture.player.choose(Track.demos[0], in: Track.demos)
        let began = await waitUntil { fixture.player.isPlaying }
        XCTAssertTrue(began)
        fixture.store.stepTrackForTape(1)
        fixture.player.choose(Track.demos[2], in: Track.demos, autoplay: false)
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(fixture.player.current.id, "night")
        XCTAssertFalse(fixture.player.isPlaying)
        XCTAssertNil(fixture.player.tapeTrackMotionRate)
        fixture.player.play()
        let restarted = await waitUntil { fixture.player.isPlaying }
        XCTAssertTrue(restarted)
        fixture.store.stepTrackForTape(1)
        fixture.store.setTransportFeedbackActive(false)
        try await Task.sleep(for: .milliseconds(900))
        fixture.store.setTransportFeedbackActive(true)
        XCTAssertFalse(fixture.player.isPlaying)
        XCTAssertFalse(fixture.player.snapshot.isPreparing)
        XCTAssertNil(fixture.player.tapeTrackMotionRate)
    }

    func testHoldingCancelsShortWindupAndCannotLateResume() async throws {
        let fixture = try TrackWindFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        fixture.player.choose(Track.demos[0], in: Track.demos)
        let began = await waitUntil { fixture.player.isPlaying }
        XCTAssertTrue(began)
        fixture.store.stepTrackForTape(1)
        fixture.store.beginWindingForTape(direction: 1)
        XCTAssertNil(fixture.player.tapeTrackMotionRate)
        fixture.player.endWinding(resume: false)
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertFalse(fixture.player.isPlaying)
        XCTAssertNil(fixture.player.tapeTrackMotionRate)
    }

    func testPlayingPreviousRestartRewindsSilentlyBeforeSameTrackResumes() async throws {
        let fixture = try TrackWindFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        fixture.player.choose(Track.demos[0], in: Track.demos)
        let began = await waitUntil { fixture.player.isPlaying }
        XCTAssertTrue(began)
        fixture.player.seek(8)
        let sought = await waitUntil { fixture.player.position > 7 }
        XCTAssertTrue(sought)
        fixture.store.stepTrackForTape(-1)
        XCTAssertEqual(fixture.player.current.id, "sea")
        XCTAssertEqual(fixture.player.tapeTrackMotionRate, -14)
        XCTAssertFalse(fixture.player.isPlaying)
        let resumed = await waitUntil { fixture.player.isPlaying && fixture.player.position < 2 }
        XCTAssertTrue(resumed)
        XCTAssertNil(fixture.player.tapeTrackMotionRate)
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<160 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return condition()
    }
}

@MainActor
private final class TrackWindFixture {
    let directory: URL
    let suite = "OneTape.track-wind." + UUID().uuidString
    let defaults: UserDefaults
    let player: PlayerStore
    let store: OneTapeMusicStore

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        player = PlayerStore(directory: directory, defaults: defaults, sampleTracks: Track.demos)
        let sound = OneTapeTransportSoundService(makePlayer: { _ in TrackWindSilentVoice() })
        store = OneTapeMusicStore(player: player, transportSound: sound)
        store.setTransportFeedbackActive(true)
    }

    func close() {
        store.setTransportFeedbackActive(false)
        player.pause()
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suite)
    }
}

@MainActor
private final class TrackWindSilentVoice: OneTapeTransportCuePlaying {
    var onFinish: (() -> Void)?
    var onFailure: (() -> Void)?
    func play() -> Bool { true }
    func stop() {}
}
