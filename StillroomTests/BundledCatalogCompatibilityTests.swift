import XCTest
@testable import Stillroom

@MainActor
final class BundledCatalogCompatibilityTests: XCTestCase {
    func testNewSampleIdentitiesDoNotRepurposeLegacyOriginalTracks() async throws {
        let environment = try makeEnvironment()
        let samples = makeSamples()
        let player = PlayerStore(directory: environment.directory, defaults: environment.defaults,
                                 sampleTracks: samples)
        defer { player.pause(); environment.cleanup() }

        XCTAssertEqual(player.current.id, samples[0].id)
        await player.restore()
        XCTAssertTrue(player.libraryReady)
        XCTAssertEqual(Set(player.tracks.map(\.id)), Set((samples + Track.demos).map(\.id)))
        XCTAssertEqual(player.tracks.count, samples.count + Track.demos.count)
        for legacy in Track.demos {
            let resolved = try XCTUnwrap(player.tracks.first { $0.id == legacy.id })
            XCTAssertEqual(resolved.title, legacy.title)
            XCTAssertEqual(resolved.artist, legacy.artist)
            XCTAssertEqual(resolved.album, legacy.album)
            XCTAssertEqual(resolved.audioFile, legacy.audioFile)
            XCTAssertEqual(resolved.lyrics, legacy.lyrics)
            XCTAssertEqual(resolved.duration, legacy.duration)
        }
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.snapshot.isPreparing)
    }

    func testVisibleCatalogHidesCompatibilityTracksWithoutDiscardingTheirFavorites() async throws {
        let environment = try makeEnvironment()
        let samples = makeSamples()
        environment.defaults.set(["sea", "night", samples[0].id], forKey: "favorites")
        let player = PlayerStore(directory: environment.directory, defaults: environment.defaults,
                                 sampleTracks: samples)
        defer { player.pause(); environment.cleanup() }

        await player.restore()
        XCTAssertEqual(Set(player.libraryTracks.map(\.id)), Set(samples.map(\.id)))
        XCTAssertTrue(Set(Track.demos.map(\.id)).isDisjoint(with: player.libraryTracks.map(\.id)))
        XCTAssertEqual(Set(player.albums().map(\.id)), Set(samples.map(\.id)))
        XCTAssertEqual(player.favorites, Set(["sea", "night", samples[0].id]))
        XCTAssertTrue(player.favorites.isSubset(of: Set(player.tracks.map(\.id))))
        XCTAssertEqual(Set(environment.defaults.stringArray(forKey: "favorites") ?? []), player.favorites)
    }

    func testLegacyBookmarkRestoresItsActualTrackQueueAndPositionWithoutAutoplay() async throws {
        let environment = try makeEnvironment()
        let bookmark = PlaybackBookmark(trackID: "sea", queueIDs: ["window", "sea", "night"],
            originalIDs: ["sea", "window", "night"], shuffled: true, repeatMode: .all,
            position: 14.25, queueTitle: "旧试听队列", finished: false)
        try PlaybackBookmarkStore(defaults: environment.defaults).save(bookmark)
        let player = PlayerStore(directory: environment.directory, defaults: environment.defaults,
                                 sampleTracks: makeSamples())
        defer { player.pause(); environment.cleanup() }

        await player.restore()
        XCTAssertTrue(player.libraryReady)
        XCTAssertEqual(player.current.id, "sea")
        XCTAssertEqual(player.current.title, "海边慢信")
        XCTAssertEqual(player.position, 14.25, accuracy: 0.0001)
        XCTAssertEqual(player.queue.ids, bookmark.queueIDs)
        XCTAssertEqual(player.queue.originalIDs, bookmark.originalIDs)
        XCTAssertTrue(player.queue.shuffled)
        XCTAssertEqual(player.queue.repeatMode, .all)
        XCTAssertEqual(player.queueTitle, bookmark.queueTitle)
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.snapshot.isPreparing)
    }

    func testFrozenLegacyCraftedEditionRemainsRestorableWithNewVisibleSamples() async throws {
        let environment = try makeEnvironment()
        var editable = CraftedRecord(title: "原来的唱片", sideA: ["sea", "window"],
                                     sideB: ["night"], isDraft: false)
        let frozen = CraftListeningSession(record: editable, side: .a, phase: .awaitingFlip,
                                          reachedEndIDs: ["sea", "window"])
        let bookmark = PlaybackBookmark(trackID: "window", queueIDs: ["sea", "window"],
            originalIDs: ["sea", "window"], shuffled: false, repeatMode: .off,
            position: 18.5, queueTitle: "原来的唱片 · A 面", finished: true, craftedSession: frozen)
        try PlaybackBookmarkStore(defaults: environment.defaults).save(bookmark)
        editable.title = "后来编辑的版本"
        editable.sideA = [makeSamples()[0].id]
        let player = PlayerStore(directory: environment.directory, defaults: environment.defaults,
                                 sampleTracks: makeSamples())
        defer { player.pause(); environment.cleanup() }

        await player.restore()
        let restored = try XCTUnwrap(player.craftedSession)
        XCTAssertEqual(restored, frozen)
        XCTAssertEqual(restored.record.sideA, ["sea", "window"])
        XCTAssertEqual(restored.record.sideB, ["night"])
        XCTAssertNotEqual(restored.record, editable)
        XCTAssertTrue(restored.isRestorable(available: Set(player.tracks.map(\.id)), currentID: "window"))
        XCTAssertEqual(player.queue.ids, ["sea", "window"])
        XCTAssertEqual(player.position, 18.5, accuracy: 0.0001)
        XCTAssertTrue(player.queueFinished)
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.snapshot.isPreparing)
    }

    func testExplicitOriginalSampleFixtureKeepsItsOldVisibleIdentitiesAndMetadata() async throws {
        let environment = try makeEnvironment()
        let player = PlayerStore(directory: environment.directory, defaults: environment.defaults,
                                 sampleTracks: Track.demos)
        defer { player.pause(); environment.cleanup() }

        await player.restore()
        XCTAssertEqual(player.tracks.map(\.id), ["sea", "window", "night"])
        XCTAssertEqual(player.libraryTracks.map(\.id), ["sea", "window", "night"])
        XCTAssertEqual(player.libraryTracks.map(\.title), ["海边慢信", "窗边余响", "夜色之中"])
        XCTAssertEqual(player.libraryTracks.map(\.album), ["潮汐来信", "午后的房间", "月亮留声"])
        player.choose(Track.demos[1], in: Track.demos, autoplay: false)
        XCTAssertEqual(player.current.id, "window")
        XCTAssertEqual(player.queue.ids, ["sea", "window", "night"])
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.snapshot.isPreparing)
    }

    func testImportedLibraryEntryRemainsVisibleAndRetainsItsPersistentIdentity() async throws {
        let environment = try makeEnvironment()
        var imported = Track(id: "imported-fixture-identity", title: "Imported Fixture", artist: "Local Artist",
            album: "Local Album", audioFile: "imported-fixture.wav", palette: .local, duration: 21,
            lyrics: "", isDemo: false, isLyricDemo: false)
        // A valid stored hash avoids opening nonexistent fixture audio during legacy hash recovery.
        // Missing files remain valid library entries for later recovery; this test never plays them.
        imported.contentHash = String(repeating: "a", count: 64)
        try await LibraryRepository(directory: environment.directory).save([imported])
        let index = environment.directory.appendingPathComponent("library.json")
        let originalIndex = try Data(contentsOf: index)
        let samples = makeSamples()
        let player = PlayerStore(directory: environment.directory, defaults: environment.defaults,
                                 sampleTracks: samples)
        defer { player.pause(); environment.cleanup() }

        await player.restore()
        XCTAssertTrue(player.libraryReady)
        XCTAssertEqual(Set(player.libraryTracks.map(\.id)), Set(samples.map(\.id) + [imported.id]))
        XCTAssertEqual(player.tracks.first { $0.id == imported.id }?.contentHash, imported.contentHash)
        XCTAssertEqual(player.libraryTracks.first { $0.id == imported.id }?.audioFile, imported.audioFile)
        XCTAssertTrue(player.albums().contains { $0.id == imported.id })
        XCTAssertEqual(try Data(contentsOf: index), originalIndex)
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.snapshot.isPreparing)
    }

    private func makeSamples() -> [Track] {
        [sample("cc-fixture-one", album: "Reference Fixture One"),
         sample("cc-fixture-two", album: "Reference Fixture Two")]
    }

    private func sample(_ id: String, album: String) -> Track {
        Track(id: id, title: "Sample Fixture " + id, artist: "Fixture Artist", album: album,
              audioFile: id + ".mp3", palette: .local, duration: 30,
              lyrics: "", isDemo: true, isLyricDemo: false)
    }

    private func makeEnvironment() throws -> TestEnvironment {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "Stillroom.bundled-catalog." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return TestEnvironment(directory: directory, suite: suite, defaults: defaults)
    }

    private struct TestEnvironment {
        let directory: URL
        let suite: String
        let defaults: UserDefaults

        func cleanup() {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
    }
}
