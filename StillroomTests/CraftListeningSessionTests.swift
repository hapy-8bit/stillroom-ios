import XCTest
@testable import Stillroom

@MainActor
final class CraftListeningSessionTests: XCTestCase {
    func testSideNeedleUsesRealOrderedMediaSecondsAndClampsPosition() throws {
        let record = CraftedRecord(title: "曲带", sideA: ["sea", "window"], sideB: ["night"], isDraft: false)
        var session = CraftListeningSession(record: record)
        XCTAssertEqual(try XCTUnwrap(session.fraction(currentID: "window", position: 24, duration: 48, tracks: Track.demos)), 80.0 / 104, accuracy: 0.0001)
        XCTAssertEqual(session.fraction(currentID: "window", position: 99, duration: 48, tracks: Track.demos), 1)
        session.side = .b
        XCTAssertEqual(session.fraction(currentID: "night", position: 20, duration: 40, tracks: Track.demos), 0.5)
    }

    func testUnknownSideDurationDoesNotFabricateAnEvenlySpacedNeedle() {
        let record = CraftedRecord(title: "待解析", sideA: ["sea", "missing"], isDraft: false)
        let session = CraftListeningSession(record: record)
        XCTAssertNil(session.fraction(currentID: "sea", position: 28, duration: 56, tracks: Track.demos))
        XCTAssertNil(session.fraction(currentID: "window", position: 0, duration: 48, tracks: Track.demos))
    }
    func testManualFlipParksAtSideBoundaryAndMarksOnlyDecoderCompletions() {
        let record = CraftedRecord(title: "一张回程", sideA: ["sea", "window"], sideB: ["night"], isDraft: false)
        var session = CraftListeningSession(record: record)
        XCTAssertEqual(session.advance(from: "sea", delta: 1, automatic: true), .track("window", .a))
        XCTAssertEqual(session.reachedEndIDs, ["sea"])
        XCTAssertEqual(session.advance(from: "window", delta: 1, automatic: true), .flip)
        XCTAssertEqual(session.phase, .awaitingFlip)
        XCTAssertEqual(session.side, .a)
        XCTAssertFalse(session.allReachedEnd)
        XCTAssertEqual(session.flip(), "night")
        XCTAssertEqual(session.side, .b)
        XCTAssertEqual(session.advance(from: "night", delta: 1, automatic: true), .finished)
        XCTAssertTrue(session.allReachedEnd)
        XCTAssertEqual(session.phase, .finished)
    }

    func testContinuousModeCrossesToBWithoutAnArtificialPause() {
        let record = CraftedRecord(title: "连续听", sideA: ["sea"], sideB: ["night"], manualFlip: false, isDraft: false)
        var session = CraftListeningSession(record: record)
        XCTAssertEqual(session.advance(from: "sea", delta: 1, automatic: true), .track("night", .b))
        XCTAssertEqual(session.phase, .listening)
        XCTAssertEqual(session.sideIDs, ["night"])
        XCTAssertEqual(session.advance(from: "night", delta: 1, automatic: true), .finished)
        XCTAssertTrue(session.allReachedEnd)
    }

    func testManualSkipsCanReachEndWithoutCreatingACompletedListen() {
        let record = CraftedRecord(title: "跳曲", sideA: ["sea"], sideB: ["night"], manualFlip: false, isDraft: false)
        var session = CraftListeningSession(record: record)
        XCTAssertEqual(session.advance(from: "sea", delta: 1, automatic: false), .track("night", .b))
        XCTAssertEqual(session.advance(from: "night", delta: 1, automatic: false), .finished)
        XCTAssertEqual(session.phase, .finished)
        XCTAssertTrue(session.reachedEndIDs.isEmpty)
        XCTAssertFalse(session.allReachedEnd)
    }

    func testPreviousAtBReturnsToLastAAndBeginningDoesNotWrapToUnheardLastSong() {
        let record = CraftedRecord(title: "顺序", sideA: ["sea", "window"], sideB: ["night"], isDraft: false)
        var session = CraftListeningSession(record: record, side: .b)
        XCTAssertEqual(session.advance(from: "night", delta: -1, automatic: false), .track("window", .a))
        XCTAssertEqual(session.advance(from: "sea", delta: -1, automatic: false), .track("sea", .a))
        XCTAssertTrue(session.reachedEndIDs.isEmpty)
    }

    func testStaleCompletionsCannotReopenWaitingOrFinishedEdition() {
        let record = CraftedRecord(title: "迟到的回调", sideA: ["sea", "window"], sideB: ["night"], isDraft: false)
        var waiting = CraftListeningSession(record: record, phase: .awaitingFlip, reachedEndIDs: ["sea", "window"])
        let parked = waiting
        _ = waiting.advance(from: "sea", delta: 1, automatic: true)
        XCTAssertEqual(waiting, parked)
        var finished = CraftListeningSession(record: record, side: .b, phase: .finished, reachedEndIDs: ["night"])
        let completed = finished
        _ = finished.advance(from: "night", delta: -1, automatic: true)
        XCTAssertEqual(finished, completed)
        var invalidFlip = CraftListeningSession(record: record, side: .b, phase: .awaitingFlip)
        XCTAssertNil(invalidFlip.flip())
    }

    func testRestorationRejectsMissingTracksInvalidRecordAndImpossibleFlipPosition() {
        let record = CraftedRecord(title: "恢复", sideA: ["sea", "window"], sideB: ["night"], isDraft: false)
        let available: Set<String> = ["sea", "window", "night"]
        var session = CraftListeningSession(record: record)
        XCTAssertTrue(session.isRestorable(available: available, currentID: "sea"))
        XCTAssertFalse(session.isRestorable(available: ["sea", "window"], currentID: "sea"))
        session.phase = .awaitingFlip
        XCTAssertTrue(session.isRestorable(available: available, currentID: "window"))
        XCTAssertFalse(session.isRestorable(available: available, currentID: "sea"))
        session.record.title = " "
        XCTAssertFalse(session.isRestorable(available: available, currentID: "window"))
        session.record = record; session.reachedEndIDs = ["foreign-track"]
        XCTAssertFalse(session.isRestorable(available: available, currentID: "window"))
        let oversized = CraftedRecord(title: "曲数限制", sideA: (0..<41).map { "track-\($0)" }, isDraft: false)
        XCTAssertFalse(CraftListeningSession(record: oversized).isRestorable(available: Set(oversized.sideA), currentID: "track-0"))
    }

    func testFrozenEditionDoesNotChangeWhenItsEditableRecordIsChanged() {
        var record = CraftedRecord(title: "初版", sideA: ["sea"], sideB: ["night"], isDraft: false)
        let session = CraftListeningSession(record: record)
        record.title = "新版"; record.sideA = ["window"]; record.sideB = []
        XCTAssertEqual(session.record.title, "初版")
        XCTAssertEqual(session.sideIDs, ["sea"])
        XCTAssertEqual(session.record.sideB, ["night"])
    }

    func testNaturalDecoderEndWaitsForFlipAndColdRestoreStaysPaused() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "Stillroom.craft.playback." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let player = PlayerStore(directory: directory, defaults: defaults, sampleTracks: Track.demos)
        var reopened: PlayerStore?
        defer {
            player.pause(); reopened?.pause()
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        await player.restore()
        let record = CraftedRecord(title: "真音频面尾", sideA: ["sea"], sideB: ["window"], isDraft: false)
        XCTAssertTrue(player.playCrafted(record))
        let beganA = await waitUntil { player.isPlaying }
        XCTAssertTrue(beganA)
        // Reaching the real AVAudioPlayer decoder end is tested, not simulated via skip(automatic:true).
        player.seek(max(0, player.duration - 0.15))
        let endedA = await waitUntil { player.craftedSession?.phase == .awaitingFlip }
        XCTAssertTrue(endedA)
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.current.id, "sea")
        XCTAssertEqual(player.craftedSession?.reachedEndIDs, ["sea"])
        player.checkpoint()
        let restored = PlayerStore(directory: directory, defaults: defaults, sampleTracks: Track.demos)
        reopened = restored
        await restored.restore()
        XCTAssertEqual(restored.craftedSession?.phase, .awaitingFlip)
        XCTAssertFalse(restored.isPlaying)
        XCTAssertEqual(restored.queue.ids, ["sea"])
        restored.flipCraftedSide()
        let beganB = await waitUntil { restored.isPlaying }
        XCTAssertTrue(beganB)
        XCTAssertEqual(restored.current.id, "window")
        restored.seek(max(0, restored.duration - 0.15))
        let endedB = await waitUntil { restored.craftedSession?.phase == .finished }
        XCTAssertTrue(endedB)
        XCTAssertFalse(restored.isPlaying)
        XCTAssertTrue(restored.craftedSession?.allReachedEnd == true)
    }

    func testUnavailableCraftedSongDoesNotReplaceAnExistingQueue() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "Stillroom.craft.validation." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let player = PlayerStore(directory: directory, defaults: defaults, sampleTracks: Track.demos)
        defer {
            player.pause()
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        await player.restore()
        player.choose(Track.demos[1], in: Track.demos, autoplay: false)
        let oldQueue = player.queue.ids, oldTrack = player.current.id
        let missing = CraftedRecord(title: "待修复", sideA: ["sea"], sideB: ["missing"], isDraft: false)
        XCTAssertFalse(player.playCrafted(missing))
        XCTAssertNil(player.craftedSession)
        XCTAssertEqual(player.current.id, oldTrack)
        XCTAssertEqual(player.queue.ids, oldQueue)
        XCTAssertFalse(player.isPlaying)
    }

    func testImmediateNextDuringPreparationKeepsTheRequestedPlaybackIntent() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "Stillroom.craft.rapid-next." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let player = PlayerStore(directory: directory, defaults: defaults, sampleTracks: Track.demos)
        defer {
            player.pause()
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        await player.restore()
        let record = CraftedRecord(title: "快速操作", sideA: ["sea", "window"], isDraft: false)
        XCTAssertTrue(player.playCrafted(record))
        // No await occurs between these intents: the first activation has not yet run on MainActor.
        XCTAssertTrue(player.snapshot.isPreparing)
        player.skip(1)
        XCTAssertEqual(player.current.id, "window")
        let nextBegan = await waitUntil { player.isPlaying }
        XCTAssertTrue(nextBegan)
        XCTAssertEqual(player.craftedSession?.phase, .listening)
        XCTAssertTrue(player.craftedSession?.reachedEndIDs.isEmpty == true)
    }

    func testUnavailableSideInBookmarkHasExplicitSingleSongPausedFallback() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "Stillroom.craft.missing-restore." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let record = CraftedRecord(title: "完整唱片不能假装恢复", sideA: ["sea"], sideB: ["missing"], isDraft: false)
        let bookmark = PlaybackBookmark(trackID: "sea", queueIDs: ["sea"], originalIDs: ["sea"],
            shuffled: false, repeatMode: .off, position: 12.5, queueTitle: record.title, finished: true,
            craftedSession: CraftListeningSession(record: record))
        try PlaybackBookmarkStore(defaults: defaults).save(bookmark)
        let player = PlayerStore(directory: directory, defaults: defaults, sampleTracks: Track.demos)
        defer {
            player.pause()
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        await player.restore()
        XCTAssertNil(player.craftedSession)
        XCTAssertEqual(player.queue.ids, ["sea"])
        XCTAssertEqual(player.queueTitle, "单曲续听")
        XCTAssertEqual(player.position, 12.5)
        XCTAssertFalse(player.queueFinished)
        XCTAssertFalse(player.isPlaying)
        XCTAssertTrue(player.message?.contains("制作资料仍保留") == true)
    }

    private func waitUntil(timeout: TimeInterval = 4, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            do { try await Task.sleep(for: .milliseconds(25)) } catch { return false }
        }
        return condition()
    }
}
