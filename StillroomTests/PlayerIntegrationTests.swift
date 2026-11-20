import XCTest
@testable import Stillroom

@MainActor
final class PlayerIntegrationTests: XCTestCase {
    func testNewImportIsDurableDeduplicatedAndDoesNotRewriteLiveQueueOrAutoplay() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "Stillroom.integration." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: folder); defaults.removePersistentDomain(forName: suite) }
        let store = PlayerStore(directory: folder, defaults: defaults, sampleTracks: Track.demos)
        await store.restore()
        let originalQueue = store.queue.ids
        let url = try XCTUnwrap(Bundle.main.url(forResource: "sea.wav", withExtension: nil))
        await store.importCoordinator.prepare(urls: [url])
        XCTAssertTrue(store.importCoordinator.canConfirm)
        await store.importCoordinator.confirm()
        let imported = try XCTUnwrap(store.tracks.first(where: { !$0.isDemo }))
        XCTAssertEqual(store.tracks.count, 4); XCTAssertEqual(store.queue.ids, originalQueue)
        XCTAssertFalse(store.isPlaying)
        await store.importCoordinator.reset()
        await store.importCoordinator.prepare(urls: [url]); await store.importCoordinator.confirm()
        XCTAssertEqual(store.tracks.count, 4)
        XCTAssertEqual(store.tracks.first(where: { !$0.isDemo })?.id, imported.id)
        let reopened = PlayerStore(directory: folder, defaults: defaults, sampleTracks: Track.demos)
        await reopened.restore()
        XCTAssertTrue(reopened.tracks.contains(where: { $0.id == imported.id }))
        XCTAssertFalse(reopened.isPlaying)
    }

    func testFixedTargetLyricsSurviveColdRestoreWithoutChangingOtherCurrentSong() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "Stillroom.integration." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: folder); defaults.removePersistentDomain(forName: suite) }
        let store = PlayerStore(directory: folder, defaults: defaults, sampleTracks: Track.demos)
        await store.restore(); store.choose(Track.demos[1], autoplay: false)
        try await store.setImportedLyrics("sea", canonical: "[00:05.000][Chorus] new\n[00:05.000]translation", original: "original retained")
        XCTAssertEqual(store.current.id, "window")
        XCTAssertEqual(store.tracks.first(where: { $0.id == "sea" })?.lyrics, "[00:05.000][Chorus] new\n[00:05.000]translation")
        let reopened = PlayerStore(directory: folder, defaults: defaults, sampleTracks: Track.demos)
        await reopened.restore()
        XCTAssertEqual(reopened.current.id, "window"); XCTAssertFalse(reopened.isPlaying)
        XCTAssertEqual(reopened.tracks.first(where: { $0.id == "sea" })?.lyrics, store.tracks.first(where: { $0.id == "sea" })?.lyrics)
    }

    func testBookmarkFiltersStaleIDsAndPreservesQueueOrderAndPausePosition() throws {
        let suite = "Stillroom.bookmark." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let bookmarks = PlaybackBookmarkStore(defaults: defaults)
        try bookmarks.save(PlaybackBookmark(trackID: "b", queueIDs: ["b", "a", "a", "missing"], originalIDs: ["a", "b"],
                                           shuffled: true, repeatMode: .all, position: 12.5, queueTitle: "我的选择", finished: false))
        let value = try XCTUnwrap(bookmarks.restore(available: ["a", "b"]))
        XCTAssertEqual(value.queueIDs, ["b", "a"]); XCTAssertEqual(value.position, 12.5)
        var queue = PlaybackQueue(); queue.restore(ids: value.queueIDs, original: value.originalIDs, shuffled: value.shuffled, repeatMode: value.repeatMode)
        XCTAssertTrue(queue.shuffled); queue.toggleShuffle(current: "b"); XCTAssertEqual(queue.ids, ["a", "b"])
        defaults.set(Data("corrupt".utf8), forKey: "orbit.playback.v1")
        XCTAssertThrowsError(try bookmarks.restore(available: ["a", "b"]))
        XCTAssertEqual(defaults.data(forKey: "orbit.playback.v1"), Data("corrupt".utf8))
    }

    func testParkedAndPlayingHeadGeometryFitsNarrowAndLargePortraitWindows() {
        for width in [320.0, 375, 402, 440] {
            for height in [620.0, 760, 900] {
                let side = min(width * 0.88, height * 0.53), armWidth = side * 0.39
                let left = (width - side) * 0.42
                let frameCenter = OrbitArmPlacement.centerX(viewportWidth: width, recordLeft: left, recordSide: side)
                let pivotX = frameCenter - armWidth / 2 + armWidth * 81 / 120
                for angle in stride(from: -14.0, through: 18.0, by: 0.5) {
                    // Independent samples of the actual bent rod and the four rotated headshell corners.
                    var points = [CGPoint(x: 81, y: 25), CGPoint(x: 81, y: 228)]
                    for step in 0...40 {
                        let t = Double(step) / 40
                        points.append(CGPoint(x: (1-t)*(1-t)*81 + 2*(1-t)*t*81 + t*t*59,
                                              y: (1-t)*(1-t)*228 + 2*(1-t)*t*252 + t*t*266))
                    }
                    for dx in [-11.0, 11] { for dy in [-24.0, 24] {
                        let r = 34.0 * Double.pi / 180
                        points.append(CGPoint(x: 32 + dx*cos(r)-dy*sin(r), y: 290 + dx*sin(r)+dy*cos(r)))
                    } }
                    let radians = angle * Double.pi / 180
                    for point in points {
                        let x = pivotX + ((point.x-81)*cos(radians)-(point.y-30)*sin(radians)) * armWidth / 120
                        XCTAssertLessThanOrEqual(x + armWidth * 4 / 120, width - 7)
                        XCTAssertGreaterThanOrEqual(x, 0)
                    }
                }
            }
        }
    }
}
