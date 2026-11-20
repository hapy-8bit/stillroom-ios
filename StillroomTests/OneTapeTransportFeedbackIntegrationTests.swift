import XCTest
@testable import Stillroom

@MainActor
final class OneTapeTransportFeedbackIntegrationTests: XCTestCase {
    func testExplicitToggleAcknowledgesActualPlaybackOnceAndPauseUsesRelease() async throws {
        let fixture = try FeedbackFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        XCTAssertTrue(fixture.probe.cues.isEmpty)

        fixture.store.togglePlaybackForTape()
        await expect("Real decoder starts before the play acknowledgement") {
            fixture.player.isPlaying && fixture.probe.cues == [.playLatch]
        }
        await expect("Subsequent media snapshots do not replay the latch") {
            fixture.player.position >= 0.25
        }
        XCTAssertEqual(fixture.probe.cues, [.playLatch])
        XCTAssertEqual(fixture.probe.voices.first?.starts, 1)

        fixture.store.togglePlaybackForTape()
        await expect("Explicit pause has its own acknowledged release") {
            !fixture.player.isPlaying && fixture.probe.cues == [.playLatch, .pauseRelease]
        }
        XCTAssertFalse(fixture.player.snapshot.isPreparing)
        XCTAssertEqual(fixture.probe.voices.first?.stops, 1,
                       "The new release voice replaces, rather than overlaps, the latch.")

        fixture.store.togglePlaybackForTape()
        await expect("Another explicit start creates its own latch") {
            fixture.player.isPlaying
                && fixture.probe.cues == [.playLatch, .pauseRelease, .playLatch]
        }
        let lastVoice = try XCTUnwrap(fixture.probe.voices.last)
        fixture.player.pause()
        await expect("An external pause stops the outstanding acknowledgement") {
            !fixture.player.isPlaying && lastVoice.stops == 1
        }
        XCTAssertEqual(fixture.probe.cues, [.playLatch, .pauseRelease, .playLatch],
                       "A route-loss or system pause cannot fabricate a user release sound.")
    }

    func testExternalPlaybackAndColdRestoreRemainSilent() async throws {
        let fixture = try FeedbackFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        fixture.player.play()
        await expect("External play reaches the actual engine") {
            fixture.player.isPlaying && fixture.player.position >= 0.25
        }
        fixture.player.pause()
        fixture.player.checkpoint()
        XCTAssertFalse(fixture.player.isPlaying)
        XCTAssertTrue(fixture.probe.cues.isEmpty,
                      "An engine snapshot without a foreground transport request is not an effect command.")

        let restoredPlayer = PlayerStore(directory: fixture.directory,
            defaults: fixture.defaults, sampleTracks: Track.demos)
        let restoredProbe = FeedbackProbe()
        let restoredStore = OneTapeMusicStore(player: restoredPlayer,
                                              transportSound: restoredProbe.makeService())
        restoredStore.setTransportFeedbackActive(true)
        defer {
            restoredStore.cancelTransportFeedback()
            restoredPlayer.pause()
        }
        // Restore only local player state. MusicStore.restore() could consult a
        // saved server; no network or real credential store participates here.
        await restoredPlayer.restore()
        XCTAssertEqual(restoredPlayer.currentTrack?.id, fixture.player.currentTrack?.id)
        XCTAssertFalse(restoredPlayer.isPlaying)
        XCTAssertFalse(restoredPlayer.snapshot.isPreparing)
        XCTAssertTrue(restoredProbe.cues.isEmpty)
    }

    func testEmptyLibraryAndMissingAudioNeverAcknowledgeAStart() async throws {
        let empty = try FeedbackFixture(emptyLibrary: true)
        defer { empty.close() }
        await empty.player.restore()
        empty.store.togglePlaybackForTape()
        XCTAssertNil(empty.player.currentTrack)
        XCTAssertFalse(empty.player.isPlaying)
        XCTAssertTrue(empty.probe.cues.isEmpty)

        let missingTrack = Track(id: "missing-feedback-audio", title: "Missing QA audio",
            artist: "QA", album: "QA", audioFile: UUID().uuidString + ".wav",
            palette: .local, duration: 10, lyrics: "", isDemo: false, isLyricDemo: false)
        let missing = try FeedbackFixture(sampleTracks: [missingTrack])
        defer { missing.close() }
        await missing.player.restore()
        missing.store.togglePlaybackForTape()
        await expect("Missing audio reports a real playback failure") {
            missing.player.message != nil
        }
        XCTAssertFalse(missing.player.isPlaying)
        XCTAssertFalse(missing.player.snapshot.isPreparing)
        XCTAssertTrue(missing.probe.cues.isEmpty)
    }

    func testInactiveAndCancelledRequestsCannotEmitADeferredLatch() async throws {
        let fixture = try FeedbackFixture()
        defer { fixture.close() }
        await fixture.player.restore()

        // No actor suspension between request and cancellation: the audio
        // activation task has not acknowledged actual playback yet.
        fixture.store.togglePlaybackForTape()
        fixture.store.setTransportFeedbackActive(false)
        await expect("Going inactive does not cancel the authoritative music command") {
            fixture.player.isPlaying
        }
        XCTAssertTrue(fixture.probe.cues.isEmpty)
        fixture.store.setTransportFeedbackActive(true)
        fixture.store.togglePlaybackForTape()
        await expect("An active explicit pause can still acknowledge its own command") {
            !fixture.player.isPlaying && fixture.probe.cues == [.pauseRelease]
        }

        fixture.store.togglePlaybackForTape()
        fixture.store.cancelTransportFeedback()
        await expect("Cancelling only feedback leaves music preparation intact") {
            fixture.player.isPlaying
        }
        XCTAssertEqual(fixture.probe.cues, [.pauseRelease])
    }

    func testExplicitTrackKeysClickOnceForPausedAndPlayingNavigation() async throws {
        let fixture = try FeedbackFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        fixture.player.choose(Track.demos[0], in: Track.demos, autoplay: false)

        fixture.store.stepTrackForTape(1)
        XCTAssertEqual(fixture.player.currentTrack?.id, "window")
        XCTAssertFalse(fixture.player.isPlaying)
        XCTAssertEqual(fixture.probe.cues, [.trackStep])

        fixture.store.stepTrackForTape(-1)
        XCTAssertEqual(fixture.player.currentTrack?.id, "sea")
        XCTAssertFalse(fixture.player.isPlaying)
        XCTAssertEqual(fixture.probe.cues, [.trackStep, .trackStep])
        XCTAssertEqual(fixture.probe.voices.first?.stops, 1)

        fixture.player.play()
        await expect("External play supplies no additional key sound") {
            fixture.player.isPlaying && fixture.player.position >= 0.25
        }
        fixture.store.stepTrackForTape(1)
        await expect("The explicit next command keeps the real playing intent") {
            fixture.player.currentTrack?.id == "window"
                && fixture.player.isPlaying && fixture.player.position >= 0.25
        }
        XCTAssertEqual(fixture.probe.cues, [.trackStep, .trackStep, .trackStep],
                       "Loading and subsequent engine snapshots cannot repeat the click or create a play latch.")
        XCTAssertTrue(fixture.probe.voices.allSatisfy { $0.starts == 1 })
    }

    func testPreviousRestartClicksEvenWhenTheTrackIdentityDoesNotChange() async throws {
        let fixture = try FeedbackFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        fixture.player.choose(Track.demos[0], in: Track.demos, autoplay: false)
        fixture.player.seek(8)
        await expect("A paused real engine has reached the restart threshold") {
            abs(fixture.player.position - 8) < 0.2
        }

        fixture.store.stepTrackForTape(-1)
        XCTAssertEqual(fixture.player.currentTrack?.id, "sea")
        XCTAssertEqual(fixture.probe.cues, [.trackStep])
        await expect("Previous restarts the same recording without autoplay") {
            fixture.player.position < 0.2 && !fixture.player.isPlaying
        }
        XCTAssertEqual(fixture.probe.cues, [.trackStep])
    }

    func testTrackKeysStaySilentForEmptyInactiveAndExternalCommands() async throws {
        let empty = try FeedbackFixture(emptyLibrary: true)
        defer { empty.close() }
        await empty.player.restore()
        empty.store.stepTrackForTape(-1)
        empty.store.stepTrackForTape(1)
        XCTAssertNil(empty.player.currentTrack)
        XCTAssertTrue(empty.probe.cues.isEmpty)

        let fixture = try FeedbackFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        fixture.player.choose(Track.demos[0], in: Track.demos, autoplay: false)
        fixture.store.setTransportFeedbackActive(false)
        fixture.store.stepTrackForTape(1)
        XCTAssertEqual(fixture.player.currentTrack?.id, "window")
        XCTAssertTrue(fixture.probe.cues.isEmpty)
        fixture.store.setTransportFeedbackActive(true)
        fixture.store.stepTrackForTape(0)
        fixture.player.skip(-1)
        XCTAssertEqual(fixture.player.currentTrack?.id, "sea")
        fixture.player.skip(1, automatic: true)
        await expect("An automatic queue transition reaches the real engine") {
            fixture.player.currentTrack?.id == "window" && fixture.player.isPlaying
        }
        XCTAssertTrue(fixture.probe.cues.isEmpty,
                      "Remote/direct queue commands and automatic advance are not foreground key gestures.")
    }

    func testWindingCancelsTrackFeedbackWithoutCreatingAnotherClick() async throws {
        let fixture = try FeedbackFixture()
        defer { fixture.close() }
        await fixture.player.restore()
        fixture.player.choose(Track.demos[0], in: Track.demos, autoplay: false)
        fixture.store.stepTrackForTape(1)
        let voice = try XCTUnwrap(fixture.probe.voices.first)
        XCTAssertEqual(fixture.probe.cues, [.trackStep])

        fixture.store.beginWindingForTape(direction: 1)
        await expect("Holding advances real media time without starting music") {
            fixture.player.position >= 0.3 && !fixture.player.isPlaying
        }
        fixture.player.endWinding(resume: false)
        XCTAssertEqual(voice.stops, 1)
        XCTAssertEqual(fixture.probe.cues, [.trackStep])
        XCTAssertFalse(fixture.player.isPlaying)
    }

    func testMissingAudioRestartDoesNotAcknowledgeATrackKey() async throws {
        let track = Track(id: "missing-step-audio", title: "Missing step QA audio",
            artist: "QA", album: "QA", audioFile: UUID().uuidString + ".wav",
            palette: .local, duration: 10, lyrics: "", isDemo: false, isLyricDemo: false)
        let fixture = try FeedbackFixture(sampleTracks: [track])
        defer { fixture.close() }
        await fixture.player.restore()

        // A one-song next command restarts that song. The real seek fails
        // synchronously on its missing file and must cancel key feedback.
        fixture.store.stepTrackForTape(1)
        XCTAssertNotNil(fixture.player.message)
        XCTAssertFalse(fixture.player.isPlaying)
        XCTAssertTrue(fixture.probe.cues.isEmpty)
    }

    private func expect(_ description: String, timeout: TimeInterval = 8,
                        condition: @escaping @MainActor () -> Bool) async {
        let reached = expectation(description: description)
        let poll = Task { @MainActor in
            while !Task.isCancelled {
                if condition() { reached.fulfill(); return }
                do { try await Task.sleep(for: .milliseconds(25)) }
                catch { return }
            }
        }
        await fulfillment(of: [reached], timeout: timeout)
        poll.cancel()
    }
}

@MainActor
private final class FeedbackFixture {
    let directory: URL
    let defaults: UserDefaults
    let suite: String
    let player: PlayerStore
    let probe: FeedbackProbe
    let store: OneTapeMusicStore

    init(sampleTracks: [Track] = Track.demos, emptyLibrary: Bool = false) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suite = "OneTape.feedback.integration." + UUID().uuidString
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        player = PlayerStore(directory: directory, defaults: defaults,
                             sampleTracks: sampleTracks, emptyLibrary: emptyLibrary)
        probe = FeedbackProbe()
        store = OneTapeMusicStore(player: player, transportSound: probe.makeService())
        store.setTransportFeedbackActive(true)
    }

    func close() {
        store.cancelTransportFeedback()
        player.pause()
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suite)
    }
}

@MainActor
private final class FeedbackProbe {
    var cues: [OneTapeTransportCue] = []
    var voices: [FeedbackVoice] = []

    func makeService() -> OneTapeTransportSoundService {
        OneTapeTransportSoundService(makePlayer: { [self] cue in
            cues.append(cue)
            let voice = FeedbackVoice()
            voices.append(voice)
            return voice
        })
    }
}

@MainActor
private final class FeedbackVoice: OneTapeTransportCuePlaying {
    var onFinish: (() -> Void)?
    var onFailure: (() -> Void)?
    var starts = 0
    var stops = 0

    func play() -> Bool { starts += 1; return true }
    func stop() { stops += 1 }
}
