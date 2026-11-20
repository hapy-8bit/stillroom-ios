import XCTest
@testable import Stillroom

final class DomainTests: XCTestCase {
    func testStudioCompositionKeepsTheSpindleAndArmAboveTheTransport() {
        for width in [320.0, 375, 402, 440] {
            for height in [224.0, 280, 360, 460, 560] {
                let layout = PlayerStageGeometry(size: CGSize(width: width, height: height))
                XCTAssertEqual(layout.record.width, layout.record.height)
                XCTAssertGreaterThan(layout.record.midX, width * 0.3)
                XCTAssertLessThanOrEqual(layout.record.maxX, width)
                XCTAssertGreaterThanOrEqual(layout.record.minY, 0)
                XCTAssertLessThanOrEqual(layout.record.maxY, height * 0.7)
                XCTAssertLessThanOrEqual(layout.tonearm.maxX, width)
                XCTAssertGreaterThanOrEqual(layout.tonearm.minY, 0)
                XCTAssertLessThan(layout.tonearm.maxY, height)
            }
        }
        let zero = PlayerStageGeometry(size: .zero)
        XCTAssertEqual(zero.record, .zero)
        let invalid = PlayerStageGeometry(size: CGSize(width: Double.nan, height: Double.infinity))
        XCTAssertEqual(invalid.record, .zero)
    }

    func testListeningScrollSeparatesRevealFromFreeHomeBrowsing() {
        XCTAssertEqual(ListeningScrollDestination.resolve(proposed: 900, origin: 0, travel: 600), 600)
        XCTAssertEqual(ListeningScrollDestination.resolve(proposed: 250, origin: 0, travel: 600), 0)
        XCTAssertEqual(ListeningScrollDestination.resolve(proposed: 900, origin: 600, travel: 600), 900)
        XCTAssertEqual(ListeningScrollDestination.resolve(proposed: 520, origin: 900, travel: 600), 600)
        XCTAssertEqual(ListeningScrollDestination.resolve(proposed: 120, origin: 600, travel: 600), 0)
        XCTAssertEqual(ListeningScrollDestination.resolve(proposed: -100, origin: 0, travel: 600), 0)
        XCTAssertEqual(ListeningScrollDestination.resolve(proposed: .nan, origin: 0, travel: 600), 0)
    }

    func testLRCOffsetsFractionsAndStableSorting() {
        let lines = Lyrics.parse("[offset:-250]\n[00:10.5][01:02.050]你好\n[00:01:25]开头\n[00:95]无效\n[ar:Artist]")
        XCTAssertEqual(lines.map(\.time), [1, 10.25, 61.8])
        XCTAssertEqual(lines.map(\.text), ["开头", "你好", "你好"])
        XCTAssertNil(Lyrics.activeIndex(in: lines, at: 0))
        XCTAssertEqual(Lyrics.activeIndex(in: lines, at: 11), 1)
        XCTAssertTrue(Lyrics.parse("纯文本歌词").isEmpty)
    }

    func testQueueEndRepeatAndManualNavigation() {
        var queue = PlaybackQueue()
        queue.replace(with: ["a", "b", "c"], startingAt: "a")
        XCTAssertNil(queue.adjacent(to: "c", delta: 1, automatic: true))
        XCTAssertEqual(queue.adjacent(to: "c", delta: 1, automatic: false), "a")
        XCTAssertEqual(queue.adjacent(to: "a", delta: -1, automatic: false), "c")
        queue.repeatMode = .all
        XCTAssertEqual(queue.adjacent(to: "c", delta: 1, automatic: true), "a")
        queue.repeatMode = .one
        XCTAssertEqual(queue.adjacent(to: "b", delta: 1, automatic: true), "b")
        XCTAssertEqual(queue.adjacent(to: "b", delta: 1, automatic: false), "c")
        XCTAssertNil(queue.adjacent(to: "missing", delta: 1, automatic: false))
    }

    func testShuffleKeepsCurrentAndRestoresOriginalOrder() {
        var queue = PlaybackQueue()
        queue.replace(with: ["a", "b", "c", "a"], startingAt: "b")
        queue.toggleShuffle(current: "b")
        XCTAssertEqual(queue.ids.first, "b")
        XCTAssertEqual(Set(queue.ids), Set(["a", "b", "c"]))
        queue.toggleShuffle(current: "b")
        XCTAssertEqual(queue.ids, ["a", "b", "c"])
    }

    func testPaperTransitionIsBoundedOverlapsControlsAndSupportsReducedMotion() {
        for step in 0...100 {
            let pose = ListeningPose(progress: Double(step) / 100)
            for value in [pose.dissolve, pose.artworkOpacity, pose.controller, pose.hintOpacity] {
                XCTAssertTrue((0...1).contains(value))
            }
        }
        XCTAssertEqual(ListeningPose(progress: .nan).dissolve, 0)
        XCTAssertEqual(ListeningPose(progress: 0).artworkOpacity, 1)
        XCTAssertEqual(ListeningPose(progress: 1).artworkOpacity, 0)
        let overlap = ListeningPose(progress: 0.6)
        XCTAssertTrue(overlap.controller > 0 && overlap.artworkOpacity > 0)
        XCTAssertEqual(ListeningPose(progress: 1, reducedMotion: true).controller, 1)
        XCTAssertEqual(ListeningPose(progress: 1, reducedMotion: true).dissolve, 0)
    }

    func testPaperFragmentsTileOriginalAndReverseWithoutAccumulatedState() {
        let fragments = PaperFragmentLayout.fragments
        XCTAssertEqual(fragments.count, 24)
        XCTAssertEqual(fragments.reduce(0) { $0 + $1.rect.width * $1.rect.height }, 1, accuracy: 0.000001)
        for i in fragments.indices {
            for j in fragments.indices where i != j {
                let intersection = fragments[i].rect.intersection(fragments[j].rect)
                XCTAssertTrue(intersection.isNull || intersection.width * intersection.height < 0.000001)
            }
            let first = PaperFragmentLayout.pose(for: fragments[i], progress: 0)
            XCTAssertEqual(first.x, 0)
            XCTAssertEqual(first.y, 0)
            XCTAssertEqual(first.fold, 1)
            XCTAssertEqual(first.opacity, 1)
            XCTAssertTrue(PaperFragmentLayout.burnBoundary(for: fragments[i], progress: 0).allSatisfy { $0 == 0 })
            XCTAssertTrue(PaperFragmentLayout.burnBoundary(for: fragments[i], progress: 1).allSatisfy { $0 > 1 })
            let forward = (0...100).map { PaperFragmentLayout.pose(for: fragments[i], progress: Double($0) / 100) }
            for step in (0...100).reversed() {
                let reverse = PaperFragmentLayout.pose(for: fragments[i], progress: Double(step) / 100)
                XCTAssertEqual(reverse, forward[step])
                XCTAssertTrue(reverse.x.isFinite && reverse.y.isFinite && reverse.rotation.isFinite)
                XCTAssertTrue((0...1).contains(reverse.opacity))
                XCTAssertTrue((0.065...1).contains(reverse.fold))
                let edge = PaperFragmentLayout.burnBoundary(for: fragments[i], progress: Double(step) / 100)
                XCTAssertTrue(edge.allSatisfy { $0.isFinite && (0...1.08).contains($0) })
            }
            XCTAssertEqual(forward.last?.opacity, 0)
        }
        XCTAssertNotEqual(PaperFragmentLayout.pose(for: fragments[0], progress: 0.5),
                          PaperFragmentLayout.pose(for: fragments[1], progress: 0.5))
    }

    func testTimeAndPathBoundaries() {
        XCTAssertEqual(MediaTime.label(-3), "0:00")
        XCTAssertEqual(MediaTime.label(125), "2:05")
        XCTAssertEqual(MediaTime.label(.nan), "0:00")
        XCTAssertEqual(MediaTime.clamped(.infinity, duration: 60), 0)
        XCTAssertEqual(MediaTime.clamped(90, duration: 60), 60)
        for path in ["../song.mp3", "/song.mp3", "..", "x\\y", ""] {
            XCTAssertFalse(LibraryRepository.isSafeBasename(path))
        }
        XCTAssertTrue(LibraryRepository.isSafeBasename("song.m4a"))
    }

    func testLibraryRoundTripAndCorruptionNeverOverwritesOriginal() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LibraryRepository(directory: directory)
        var imported = Track.demos[0]
        imported = Track(id: "local", title: "本地", artist: "艺术家", album: "专辑", audioFile: "local.wav",
                         palette: .local, duration: 10, lyrics: "歌词", isDemo: false, isLyricDemo: false)
        try await repository.save(Track.demos + [imported])
        let restored = try await repository.restore()
        XCTAssertEqual(restored, [imported])
        let index = directory.appendingPathComponent("library.json")
        let original = Data("{broken".utf8)
        try original.write(to: index)
        do { _ = try await repository.restore(); XCTFail("Expected corrupt index error") } catch {}
        do { try await repository.save([]); XCTFail("Must not replace corrupt index") } catch {}
        XCTAssertEqual(try Data(contentsOf: index), original)
    }

    func testPlainLyricsImportAndSizeLimit() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LibraryRepository(directory: directory)
        let text = directory.appendingPathComponent("lyrics.txt")
        try Data("\u{FEFF}你好，音乐".utf8).write(to: text)
        let loaded = try await repository.readLyrics(from: text)
        XCTAssertEqual(loaded, "你好，音乐")
        try Data(repeating: 65, count: 1_048_577).write(to: text)
        do { _ = try await repository.readLyrics(from: text); XCTFail("Must reject oversized lyrics") } catch {}
    }

    func testRealAudioImportSurvivesRepositoryRecreation() async throws {
        let source = try XCTUnwrap(Bundle.main.url(forResource: "sea.wav", withExtension: nil))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LibraryRepository(directory: directory)
        let track = try await repository.stageAudio(from: source)
        XCTAssertFalse(track.isDemo)
        XCTAssertEqual(track.duration, 56, accuracy: 0.2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(track.audioFile).path))
        try await repository.save([track])
        let reopened = LibraryRepository(directory: directory)
        let restored = try await reopened.restore()
        XCTAssertEqual(restored, [track])
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    @MainActor func testAudioEngineTimeSeekPauseAndPendingActivationCancellation() async throws {
        let engine = AudioPlayback()
        var snapshot = PlaybackSnapshot()
        engine.onSnapshot = { snapshot = $0 }
        let source = try XCTUnwrap(Bundle.main.url(forResource: "sea.wav", withExtension: nil))
        try engine.load(source)
        XCTAssertEqual(snapshot.duration, 56, accuracy: 0.2)
        try engine.play()
        engine.pause()
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertFalse(snapshot.isPlaying, "A late activation must not undo a pause")
        let advanced = expectation(description: "The audio engine advances media time")
        var fulfilled = false
        engine.onSnapshot = { value in
            snapshot = value
            if value.isPlaying && value.position > 0.2 && !fulfilled { fulfilled = true; advanced.fulfill() }
        }
        try engine.play()
        await fulfillment(of: [advanced], timeout: 8)
        let sought = expectation(description: "The engine reports its completed media seek")
        var seekFulfilled = false
        engine.onSnapshot = { value in
            snapshot = value
            if abs(value.position - 25) < 0.2 && !seekFulfilled { seekFulfilled = true; sought.fulfill() }
        }
        engine.seek(25)
        // File and HTTP playback now share AVPlayer's asynchronous seek. Assert
        // the engine's completed position, rather than publishing an invented one.
        await fulfillment(of: [sought], timeout: 5)
        XCTAssertEqual(snapshot.position, 25, accuracy: 0.2)
        engine.pause()
        XCTAssertFalse(snapshot.isPlaying)
        engine.stop()
        XCTAssertEqual(snapshot.duration, 0)
    }
}

