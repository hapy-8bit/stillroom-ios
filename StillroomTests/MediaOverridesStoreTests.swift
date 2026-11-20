import XCTest
@testable import Stillroom

final class MediaOverridesStoreTests: XCTestCase {
    func testTrackAndAlbumCoversHaveIndependentSurfacesAndNeverReplaceAutomaticMedia() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MediaOverridesStore(directory: directory)
        try await store.restore()
        let original = track("first", artwork: "embedded-first.jpg"), second = track("second", artwork: "embedded-second.jpg")
        let staged = directory.appendingPathComponent("staged.jpg")
        let source = jpeg(); try source.write(to: staged)
        try await store.saveCover(targetID: original.id, normalizedURL: staged, album: false)
        let single = try await store.apply([original, second])
        XCTAssertNotEqual(single[0].artworkFile, original.artworkFile)
        XCTAssertNil(single[0].albumArtworkFile)
        XCTAssertEqual(single[1].artworkFile, second.artworkFile)
        try await store.saveCover(targetID: original.albumKey, normalizedURL: staged, album: true)
        let both = try await store.apply(single)
        XCTAssertEqual(both[0].artworkFile, single[0].artworkFile, "Album edits retain song-only exceptions")
        XCTAssertEqual(both[0].albumArtworkFile, both[1].albumArtworkFile)
        XCTAssertEqual(both[1].artworkFile, both[1].albumArtworkFile)
        XCTAssertEqual(MediaOverridesStore.automaticTrack(both[0]), original)
        XCTAssertEqual(MediaOverridesStore.automaticTrack(both[1]), second)
        XCTAssertEqual(try Data(contentsOf: staged), source)
        let reopened = MediaOverridesStore(directory: directory)
        try await reopened.restore()
        let restored = try await reopened.apply([original, second])
        XCTAssertEqual(restored, both)
    }

    func testAbsentEmbeddedArtIsAnExplicitBaselineAndResetUsesCurrentScopeOnly() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MediaOverridesStore(directory: directory); try await store.restore()
        let original = track("no-art", artwork: nil)
        let staged = directory.appendingPathComponent("staged.jpg"); try jpeg().write(to: staged)
        try await store.saveCover(targetID: original.albumKey, normalizedURL: staged, album: true)
        try await store.saveCover(targetID: original.id, normalizedURL: staged, album: false)
        let applied = try await store.apply(original)
        XCTAssertNotNil(applied.artworkFile)
        XCTAssertNotNil(applied.automaticMedia)
        XCTAssertNil(applied.automaticMedia?.artworkFile)
        let repeated = try await store.apply(applied)
        XCTAssertEqual(repeated, applied)
        try await store.removeCover(targetID: original.id, album: false)
        let album = try await store.apply(applied)
        XCTAssertEqual(album.artworkFile, album.albumArtworkFile)
        try await store.removeCover(targetID: original.albumKey, album: true)
        let reset = try await store.apply(album)
        XCTAssertNil(reset.artworkFile)
        XCTAssertNil(reset.albumArtworkFile)
        XCTAssertEqual(MediaOverridesStore.automaticTrack(reset), original)
    }

    func testLyricsUseCapturedTrackIDAndOriginalTextSurvivesStoreRecreation() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MediaOverridesStore(directory: directory); try await store.restore()
        let first = track("first"), currentChangedTo = track("second")
        let original = "[offset:500]\r\n[00:01]Original\r\n[00:01]Translation"
        let canonical = try LyricDocument.parse(original).canonicalText
        try await store.saveLyrics(trackID: first.id, canonical: canonical, original: original)
        let result = try await store.apply([first, currentChangedTo])
        XCTAssertEqual(result[0].lyrics, canonical)
        XCTAssertFalse(result[0].isLyricDemo)
        let untouched = try await store.apply(currentChangedTo)
        XCTAssertEqual(result[1], untouched)
        XCTAssertEqual(result[1].lyrics, currentChangedTo.lyrics)
        let raw = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first { $0.pathExtension == "original" })
        XCTAssertEqual(try String(contentsOf: raw, encoding: .utf8), original)
        let reopened = MediaOverridesStore(directory: directory); try await reopened.restore()
        let restored = try await reopened.apply(first)
        XCTAssertEqual(restored.lyrics, canonical)
        XCTAssertEqual(MediaOverridesStore.automaticTrack(restored), first)
        try await reopened.removeLyrics(trackID: first.id)
        let reset = try await reopened.apply(restored)
        XCTAssertEqual(reset.lyrics, first.lyrics)
    }

    func testFailedAtomicCommitPreservesIndexAssetsAndEffectiveMedia() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let initial = MediaOverridesStore(directory: directory); try await initial.restore()
        try await initial.saveLyrics(trackID: "first", canonical: "[00:01.000]Old", original: "[00:01]Old")
        let index = directory.appendingPathComponent("media-overrides.json")
        let bytes = try Data(contentsOf: index), before = Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
        let failing = MediaOverridesStore(directory: directory, indexWriter: { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
        try await failing.restore()
        do { try await failing.saveLyrics(trackID: "first", canonical: "[00:02.000]New", original: "[00:02]New"); XCTFail("Expected failure") }
        catch { XCTAssertTrue(error.localizedDescription.contains("旧资料已保留")) }
        XCTAssertEqual(try Data(contentsOf: index), bytes)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: directory.path)), before)
        let unchanged = try await failing.apply(track("first"))
        XCTAssertEqual(unchanged.lyrics, "[00:01.000]Old")
        do { try await failing.removeLyrics(trackID: "first"); XCTFail("Expected failed reset") } catch {}
        XCTAssertEqual(try Data(contentsOf: index), bytes)
    }

    func testCorruptOrMissingReferencedAssetsBlockWritesWithoutReplacingTheIndex() async throws {
        for mode in ["broken-json", "missing-asset", "traversal", "duplicate-target"] {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let good = MediaOverridesStore(directory: directory); try await good.restore()
            try await good.saveLyrics(trackID: "first", canonical: "[00:01.000]Old", original: "[00:01]Old")
            let path = directory.appendingPathComponent("media-overrides.json")
            if mode == "broken-json" { try Data("{broken".utf8).write(to: path) }
            else if mode == "missing-asset" {
                let file = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first { $0.pathExtension == "lrc" })
                try FileManager.default.removeItem(at: file)
            } else {
                var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
                var entries = try XCTUnwrap(object["entries"] as? [[String: Any]])
                if mode == "traversal" { entries[0]["asset"] = "../outside.lrc" }
                else { entries.append(entries[0]) }
                object["entries"] = entries
                try JSONSerialization.data(withJSONObject: object).write(to: path)
            }
            let bytes = try Data(contentsOf: path)
            let restored = MediaOverridesStore(directory: directory)
            do { try await restored.restore(); XCTFail("Must reject " + mode) } catch {}
            do { try await restored.saveLyrics(trackID: "first", canonical: "New", original: "New"); XCTFail("Writes must remain blocked") } catch {}
            XCTAssertEqual(try Data(contentsOf: path), bytes)
        }
    }

    func testFailedCoverCommitPreservesSourceAndBothOldCoverScopes() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = track("first")
        let staged = directory.appendingPathComponent("staged.jpg"); try jpeg().write(to: staged)
        let initial = MediaOverridesStore(directory: directory); try await initial.restore()
        try await initial.saveCover(targetID: original.id, normalizedURL: staged, album: false)
        try await initial.saveCover(targetID: original.albumKey, normalizedURL: staged, album: true)
        let old = try await initial.apply(original)
        let before = Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
        let index = directory.appendingPathComponent("media-overrides.json"), bytes = try Data(contentsOf: directory.appendingPathComponent("media-overrides.json"))
        let failing = MediaOverridesStore(directory: directory, indexWriter: { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
        try await failing.restore()
        do { try await failing.saveCover(targetID: original.id, normalizedURL: staged, album: false); XCTFail("Expected failed cover commit") } catch {}
        let after = try await failing.apply(original)
        XCTAssertEqual(after, old)
        XCTAssertEqual(try Data(contentsOf: index), bytes)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: directory.path)), before)
        XCTAssertEqual(try Data(contentsOf: staged), jpeg())
        do { try await initial.saveCover(targetID: original.id, normalizedURL: directory.appendingPathComponent("missing.jpg"), album: false); XCTFail("Expected missing normalized input") }
        catch { XCTAssertTrue(error.localizedDescription.contains("重新选择图片")) }
    }

    func testRepeatedAndConcurrentSavesKeepEveryTargetAndLeaveNoPendingIndexFiles() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MediaOverridesStore(directory: directory); try await store.restore()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<12 { group.addTask { try await store.saveLyrics(trackID: "id-\(index)", canonical: "Text \(index)", original: "Raw \(index)") } }
            try await group.waitForAll()
        }
        let reopened = MediaOverridesStore(directory: directory); try await reopened.restore()
        for index in 0..<12 {
            let restored = try await reopened.apply(track("id-\(index)"))
            XCTAssertEqual(restored.lyrics, "Text \(index)")
        }
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasSuffix(".pending") })
    }

    private func track(_ id: String, artwork: String? = "embedded.jpg") -> Track {
        Track(id: id, title: id, artist: "Artist", album: "Album", audioFile: id + ".wav", artworkFile: artwork,
              palette: .local, duration: 10, lyrics: "[00:00]Embedded", isDemo: false, isLyricDemo: true)
    }
    private func jpeg() -> Data { Data([255, 216, 255, 224, 1, 2, 3, 255, 217]) }
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
