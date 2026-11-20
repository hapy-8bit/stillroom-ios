import XCTest
@testable import Stillroom

final class MusicImportTests: XCTestCase {
    func testFolderDiscoveryIncludesNestedAudioButSkipsHiddenFilesAndSymlinks() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("Album")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        for name in ["song.mp3", "song.FLAC", ".hidden.wav", "notes.txt"] {
            try Data().write(to: nested.appendingPathComponent(name))
        }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("alias.mp3"),
                                                   withDestinationURL: nested.appendingPathComponent("song.mp3"))
        let repository = LibraryRepository(directory: root.appendingPathComponent("library"))
        let sources = try await repository.discover([root], folders: true)
        XCTAssertEqual(Set(sources.map { $0.url.lastPathComponent }), Set(["song.mp3", "song.FLAC"]))
        XCTAssertTrue(sources.allSatisfy { $0.scope == root })
    }

    func testRenamedIdenticalAudioIsSkippedWithoutLeavingAStagedCopy() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try XCTUnwrap(Bundle.main.url(forResource: "sea.wav", withExtension: nil))
        let renamed = root.appendingPathComponent("renamed.wav")
        try FileManager.default.copyItem(at: source, to: renamed)
        let directory = root.appendingPathComponent("library")
        let repository = LibraryRepository(directory: directory)
        let track = try await repository.stageAudio(from: source)
        try await repository.save([track])
        let before = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        do {
            _ = try await repository.stageAudio(from: renamed, existing: [track])
            XCTFail("Duplicate bytes must be rejected even when the name changes")
        } catch LibraryError.duplicateAudio {}
        XCTAssertEqual(Set(before), Set(try FileManager.default.contentsOfDirectory(atPath: directory.path)))
        XCTAssertEqual(try Data(contentsOf: source), try Data(contentsOf: renamed))
    }

    func testOldIndexWithoutFingerprintRemainsReadableAndGainsDuplicateProtection() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try XCTUnwrap(Bundle.main.url(forResource: "sea.wav", withExtension: nil))
        let repository = LibraryRepository(directory: root)
        var track = try await repository.stageAudio(from: source)
        track.contentHash = nil
        try await repository.save([track])
        let originalIndex = try Data(contentsOf: root.appendingPathComponent("library.json"))
        let restored = try await LibraryRepository(directory: root).restore()
        XCTAssertNotNil(restored.first?.contentHash)
        XCTAssertEqual(restored.first?.id, track.id)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("library.json")), originalIndex,
                       "Reading an old library does not overwrite its index")
        do {
            _ = try await repository.stageAudio(from: source, existing: restored)
            XCTFail("Older imports must also be protected against duplicates")
        } catch LibraryError.duplicateAudio {}
    }

    @MainActor
    func testMixedBatchReportsFailuresAndDuplicatesAndRestoresAddedAudio() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try XCTUnwrap(Bundle.main.url(forResource: "sea.wav", withExtension: nil))
        let invalid = root.appendingPathComponent("broken.mp3")
        try Data("not audio".utf8).write(to: invalid)
        let suite = "StillroomTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = root.appendingPathComponent("library")
        let store = PlayerStore(directory: directory, defaults: defaults, sampleTracks: Track.demos)
        await store.restore()
        await store.importFiles([source, invalid, source], request: .music)
        XCTAssertEqual(store.importReport.added, 1)
        XCTAssertEqual(store.importReport.duplicates, 1)
        XCTAssertEqual(store.importReport.issues.count, 1)
        XCTAssertEqual(store.importReport.issues.first?.filename, "broken.mp3")
        XCTAssertTrue(store.importReport.finished)
        XCTAssertFalse(store.importing)
        XCTAssertNil(store.importProgress)
        XCTAssertEqual(store.tracks.filter { !$0.isDemo }.count, 1)
        let reopened = try await LibraryRepository(directory: directory).restore()
        XCTAssertEqual(reopened.count, 1)
        XCTAssertEqual(reopened.first?.duration ?? 0, 56, accuracy: 0.2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: invalid.path))
    }

    @MainActor
    func testStopRequestKeepsCommittedFilesAndDoesNotProcessTheRest() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try XCTUnwrap(Bundle.main.url(forResource: "sea.wav", withExtension: nil))
        let store = PlayerStore(directory: root, sampleTracks: Track.demos)
        await store.restore()
        let task = Task { await store.importFiles(Array(repeating: source, count: 100), request: .music) }
        while !store.importing { await Task.yield() }
        store.stopImportAfterCurrentFile()
        await task.value
        XCTAssertTrue(store.importReport.stopped)
        XCTAssertLessThan(store.importReport.added + store.importReport.duplicates, 100)
        let reopened = try await LibraryRepository(directory: root).restore()
        XCTAssertEqual(reopened.count, store.importReport.added)
        XCTAssertFalse(store.importing)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
