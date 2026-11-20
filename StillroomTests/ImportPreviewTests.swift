import XCTest
@testable import Stillroom

@MainActor
final class ImportPreviewTests: XCTestCase {
    @MainActor private final class Harness {
        let root: URL
        let directory: URL
        let repository: LibraryRepository
        var coordinator: MusicImportCoordinator!
        var tracks: [Track] = []
        var lyricTargets: [String] = []
        var coverTargets: [(String, Bool)] = []
        var audioCommits = 0
        var failAudio = Set<String>()
        var failLyrics = false
        var afterAudio: (() -> Void)?

        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            directory = root.appendingPathComponent("Library")
            repository = LibraryRepository(directory: directory)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            coordinator = MusicImportCoordinator(repository: repository, directory: directory, tracks: { [weak self] in
                self?.tracks ?? []
            }, commitAudio: { [weak self] track, folder in
                guard let self else { throw LibraryError.missingAudio }
                self.audioCommits += 1
                if self.failAudio.contains(track.id) { throw CocoaError(.fileWriteUnknown) }
                let result = try await self.repository.appendPreviewAudio(track, from: folder)
                self.tracks = result.tracks
                self.afterAudio?()
                return result.track.id
            }, commitLyrics: { [weak self] id, _, _ in
                guard let self, self.tracks.contains(where: { $0.id == id }) else { throw LibraryError.missingAudio }
                if self.failLyrics { throw CocoaError(.fileWriteUnknown) }
                self.lyricTargets.append(id)
            }, commitCover: { [weak self] id, _, album in
                guard let self, self.tracks.contains(where: { $0.id == id }) else { throw LibraryError.missingAudio }
                self.coverTargets.append((id, album))
            })
        }

        func audio(_ name: String, resource: String = "sea.wav") throws -> URL {
            let source = try XCTUnwrap(Bundle.main.url(forResource: resource, withExtension: nil))
            let copy = root.appendingPathComponent(name)
            try FileManager.default.copyItem(at: source, to: copy)
            return copy
        }

        func text(_ name: String, _ text: String) throws -> URL {
            let path = root.appendingPathComponent(name)
            try Data(text.utf8).write(to: path)
            return path
        }

        deinit { try? FileManager.default.removeItem(at: root) }
    }

    func testPreviewDoesNotCommitAndAliasesReuseOneTrackWhileNewCompanionsAttach() async throws {
        let env = try Harness()
        let first = try env.audio("First.wav")
        let alias = try env.audio("Alias.wav")
        let lyric = try env.text("Alias.lrc", "[00:01]新歌词")
        await env.coordinator.prepare(urls: [first, alias, lyric])
        XCTAssertEqual(env.coordinator.phase, .preview)
        XCTAssertTrue(env.coordinator.canConfirm)
        XCTAssertEqual(env.audioCommits, 0)
        XCTAssertEqual(env.tracks.count, 0)
        XCTAssertEqual(env.coordinator.audioRows.filter(\.requiresCopy).count, 1)
        await env.coordinator.confirm()
        XCTAssertEqual(env.audioCommits, 1)
        XCTAssertEqual(env.tracks.count, 1)
        XCTAssertEqual(env.lyricTargets, [try XCTUnwrap(env.tracks.first?.id)])
        XCTAssertEqual(env.coordinator.results.map(\.state), [.success, .skipped, .success])
        let restored = try await LibraryRepository(directory: env.directory).restore()
        XCTAssertEqual(restored.map(\.id), env.tracks.map(\.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: alias.path))
    }

    func testAppendingSelectedLyricsAssociatesWithAudioAlreadyInPreviewAndPickerCancelPreservesIt() async throws {
        let env = try Harness()
        let audio = try env.audio("Song.wav")
        let lyric = try env.text("Song.txt", "自己的歌词")
        await env.coordinator.prepare(urls: [audio])
        let id = try XCTUnwrap(env.coordinator.audioRows.first?.id)
        await env.coordinator.prepare(urls: [lyric], append: true)
        XCTAssertEqual(env.coordinator.companions.first?.selectedAudioID, id)
        XCTAssertEqual(env.coordinator.companions.first?.state, .target)
        await env.coordinator.prepare(urls: [], append: true)
        XCTAssertEqual(env.coordinator.phase, .preview)
        XCTAssertEqual(env.coordinator.audioRows.first?.id, id)
        XCTAssertEqual(env.coordinator.companions.count, 1)
        XCTAssertEqual(env.audioCommits, 0)
        await env.coordinator.confirm()
        XCTAssertEqual(env.tracks.count, 1)
        XCTAssertEqual(env.lyricTargets.count, 1)
    }

    func testARepeatedOldAudioKeepsTrackIDAndNewLyricsStillSave() async throws {
        let env = try Harness()
        let audio = try env.audio("First.wav")
        await env.coordinator.prepare(urls: [audio])
        await env.coordinator.confirm()
        let oldID = try XCTUnwrap(env.tracks.first?.id)
        let renamed = try env.audio("Renamed.wav")
        let lyric = try env.text("Renamed.lrc", "[00:01]后补歌词")
        await env.coordinator.prepare(urls: [renamed, lyric])
        XCTAssertEqual(env.coordinator.audioRows.first?.targetTrackID, oldID)
        await env.coordinator.confirm()
        XCTAssertEqual(env.audioCommits, 1)
        XCTAssertEqual(env.tracks.map(\.id), [oldID])
        XCTAssertEqual(env.lyricTargets, [oldID])
    }

    func testFailedCompanionIsIndependentAndCannotClearExistingLyrics() async throws {
        let env = try Harness()
        let audio = try env.audio("Song.wav")
        let bad = env.root.appendingPathComponent("Song.lrc")
        try Data([0xFF, 0xFF, 0x00]).write(to: bad)
        await env.coordinator.prepare(urls: [audio, bad])
        XCTAssertEqual(env.coordinator.companions.first?.state, .failed)
        XCTAssertTrue(env.coordinator.canConfirm)
        await env.coordinator.confirm()
        XCTAssertEqual(env.tracks.count, 1)
        XCTAssertTrue(env.lyricTargets.isEmpty)
        XCTAssertEqual(env.coordinator.results.map(\.state), [.success, .failed])
    }

    func testSameNameAmbiguityRequiresExplicitChoiceAndSameKindConflictsRequireSkip() async throws {
        let env = try Harness()
        let audio = try env.audio("Song.wav")
        let lrc = try env.text("Song.lrc", "[00:01]同步")
        let txt = try env.text("Song.txt", "纯文本")
        await env.coordinator.prepare(urls: [audio, lrc, txt])
        XCTAssertFalse(env.coordinator.canConfirm)
        XCTAssertTrue(env.coordinator.companions.allSatisfy { $0.state == .conflict })
        let skip = try XCTUnwrap(env.coordinator.companions.first(where: { $0.name == "Song.txt" }))
        env.coordinator.chooseCompanion(itemID: skip.id, audioID: nil)
        XCTAssertTrue(env.coordinator.canConfirm)
        await env.coordinator.confirm()
        XCTAssertEqual(env.lyricTargets.count, 1)
        XCTAssertEqual(env.coordinator.results.map(\.state), [.success, .success, .skipped])
    }

    func testUnmatchedCompanionPreventsCommitUntilExplicitlySkipped() async throws {
        let env = try Harness()
        let audio = try env.audio("Song.wav")
        let lyric = try env.text("Other.lrc", "[00:01]不猜目标")
        await env.coordinator.prepare(urls: [audio, lyric])
        await env.coordinator.confirm()
        XCTAssertEqual(env.audioCommits, 0)
        XCTAssertEqual(env.coordinator.phase, .preview)
        let row = try XCTUnwrap(env.coordinator.companions.first)
        env.coordinator.chooseCompanion(itemID: row.id, audioID: nil)
        await env.coordinator.confirm()
        XCTAssertEqual(env.tracks.count, 1)
        XCTAssertTrue(env.lyricTargets.isEmpty)
    }

    func testReplacementUsesOpenedIDAndRejectsWrongKind() async throws {
        let env = try Harness()
        let audio = try env.audio("Song.wav")
        await env.coordinator.prepare(urls: [audio])
        await env.coordinator.confirm()
        let oldID = try XCTUnwrap(env.tracks.first?.id)
        let lyric = try env.text("Anything.lrc", "[00:02]固定歌曲")
        await env.coordinator.prepareReplacement(urls: [lyric], trackID: oldID, kind: .lyrics)
        await env.coordinator.confirm()
        XCTAssertEqual(env.lyricTargets, [oldID])
        await env.coordinator.prepareReplacement(urls: [audio], trackID: oldID, kind: .lyrics)
        await env.coordinator.confirm()
        XCTAssertEqual(env.lyricTargets, [oldID], "A wrong-kind ready audio must not overwrite lyrics with empty text")
        XCTAssertEqual(env.coordinator.results.first?.state, .failed)
    }

    func testOneAudioFailureDoesNotRollbackASecondSongAndCancellationKeepsCommittedItems() async throws {
        let env = try Harness()
        let first = try env.audio("First.wav")
        let second = try env.audio("Second.wav", resource: "window.wav")
        await env.coordinator.prepare(urls: [first, second])
        env.failAudio.insert(try XCTUnwrap(env.coordinator.audioRows.first?.id.uuidString))
        await env.coordinator.confirm()
        XCTAssertEqual(env.tracks.count, 1)
        XCTAssertEqual(env.coordinator.results.map(\.state), [.failed, .success])
        env.failAudio = []
        await env.coordinator.prepare(urls: [first, second])
        env.afterAudio = { [weak env] in env?.coordinator.cancel() }
        await env.coordinator.confirm()
        XCTAssertEqual(env.tracks.count, 2)
        XCTAssertTrue(env.coordinator.error.contains("已取消"))
        XCTAssertFalse(env.coordinator.busy)
    }

    func testJournalRecoveryDeletesOnlyExplicitUncommittedOwnedFilesAndPreservesCommittedIDs() async throws {
        let env = try Harness()
        try FileManager.default.createDirectory(at: env.directory, withIntermediateDirectories: true)
        var track = Track.demos[0]
        let id = UUID().uuidString
        track = Track(id: id, title: "Owned", artist: "Test", album: "Test", audioFile: id + ".wav",
                      palette: .local, duration: 1, lyrics: "", isDemo: false, isLyricDemo: false)
        let owned = env.directory.appendingPathComponent(track.audioFile)
        try Data([1, 2, 3]).write(to: owned)
        let unrelated = env.directory.appendingPathComponent("unrelated.wav")
        try Data([4]).write(to: unrelated)
        try ImportPromotionJournal.begin(directory: env.directory, track: track)
        let empty = try await env.repository.restore()
        XCTAssertTrue(empty.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: owned.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        try Data([1, 2, 3]).write(to: owned)
        try ImportPromotionJournal.begin(directory: env.directory, track: track)
        try await env.repository.save([track])
        let restored = try await LibraryRepository(directory: env.directory).restore()
        XCTAssertEqual(restored.first?.id, id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: owned.path))
    }

    func testCorruptIndexNeverTriggersJournalDeletion() async throws {
        let env = try Harness()
        try FileManager.default.createDirectory(at: env.directory, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let track = Track(id: id, title: "Owned", artist: "Test", album: "Test", audioFile: id + ".wav",
                          palette: .local, duration: 1, lyrics: "", isDemo: false, isLyricDemo: false)
        let owned = env.directory.appendingPathComponent(track.audioFile)
        try Data([1]).write(to: owned)
        try ImportPromotionJournal.begin(directory: env.directory, track: track)
        try Data("{broken".utf8).write(to: env.directory.appendingPathComponent("library.json"))
        do { _ = try await env.repository.restore(); XCTFail("Corrupt library must fail closed") }
        catch LibraryError.corruptIndex {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: owned.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: env.directory.appendingPathComponent(".import-commits/" + id + ".json").path))
    }

    func testBatchBudgetRejectsBeforeCopyAndDoesNotConsumeTheUsersOriginal() async throws {
        let env = try Harness()
        let source = try env.audio("Source.wav")
        let staging = ImportStaging(libraryDirectory: env.directory)
        let item = await staging.stage(AudioImportSource(url: source, scope: source), remainingBytes: 1)
        XCTAssertFalse(item.error.isEmpty)
        XCTAssertNil(item.track)
        let stagingDirectory = await staging.directory
        let temporaryFiles = try FileManager.default.contentsOfDirectory(at: stagingDirectory, includingPropertiesForKeys: nil)
        XCTAssertTrue(temporaryFiles.isEmpty, "Capacity rejection happens before copying audio bytes")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        try await staging.cleanup()
    }

    func testAppendOverThirtyKeepsTheOriginalPreviewAndDoesNotCommitIt() async throws {
        let env = try Harness()
        let audio = try env.audio("Song.wav")
        let lyric = try env.text("Song.txt", "配套")
        await env.coordinator.prepare(urls: [audio])
        let originalID = try XCTUnwrap(env.coordinator.audioRows.first?.id)
        await env.coordinator.prepare(urls: Array(repeating: lyric, count: 30), append: true)
        XCTAssertEqual(env.coordinator.phase, .preview)
        XCTAssertEqual(env.coordinator.audioRows.map(\.id), [originalID])
        XCTAssertTrue(env.coordinator.companions.isEmpty)
        XCTAssertTrue(env.coordinator.error.contains("30"))
        XCTAssertEqual(env.audioCommits, 0)
        await env.coordinator.confirm()
        XCTAssertEqual(env.tracks.count, 1)
    }
}
