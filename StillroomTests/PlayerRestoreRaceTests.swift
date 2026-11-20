import XCTest
@testable import Stillroom

@MainActor
final class PlayerRestoreRaceTests: XCTestCase {
    func testLocalRestoreCannotReinsertPreviousRemoteCatalogOverNewSelection() async throws {
        let environment = try environment()
        defer { environment.cleanup() }
        let local = localTrack()
        try await LibraryRepository(directory: environment.directory).save([local])
        let entered = expectation(description: "Local metadata is ready and publication is held")
        let gate = RestorePublicationGate { entered.fulfill() }
        let player = PlayerStore(directory: environment.directory, defaults: environment.defaults,
            emptyLibrary: true, beforeLocalRestorePublication: { await gate.hold() })
        let previous = remoteTrack("previous")
        player.setRemoteTracks([previous], streamURL: nil)
        let restore = Task { await player.restore() }
        await fulfillment(of: [entered], timeout: 5)
        let first = remoteTrack("new-first"), second = remoteTrack("new-second")
        player.setRemoteTracks([first, second], streamURL: nil)
        player.choose(second, in: [first, second], autoplay: false)
        await gate.open()
        await restore.value
        XCTAssertTrue(player.libraryReady)
        XCTAssertEqual(Set(player.tracks.map(\.id)), [local.id, first.id, second.id])
        XCTAssertFalse(player.tracks.contains { $0.id == previous.id })
        XCTAssertEqual(player.currentTrack?.id, second.id)
        XCTAssertEqual(player.queue.ids, [first.id, second.id])
        XCTAssertFalse(player.isPlaying)
    }

    func testDisconnectDuringLocalRestoreCannotResurrectCloudTracks() async throws {
        let environment = try environment()
        defer { environment.cleanup() }
        let local = localTrack()
        try await LibraryRepository(directory: environment.directory).save([local])
        let entered = expectation(description: "Local restoration awaits publication")
        let gate = RestorePublicationGate { entered.fulfill() }
        let player = PlayerStore(directory: environment.directory, defaults: environment.defaults,
            emptyLibrary: true, beforeLocalRestorePublication: { await gate.hold() })
        let oldRemote = remoteTrack("disconnected")
        player.setRemoteTracks([oldRemote], streamURL: nil)
        let restore = Task { await player.restore() }
        await fulfillment(of: [entered], timeout: 5)
        player.setRemoteTracks([], streamURL: nil)
        await gate.open()
        await restore.value
        XCTAssertTrue(player.libraryReady)
        XCTAssertEqual(player.tracks.map(\.id), [local.id])
        XCTAssertNil(player.currentTrack?.remote)
        XCTAssertEqual(player.queue.ids, [local.id])
        XCTAssertFalse(player.isPlaying)
        let stored = try await LibraryRepository(directory: environment.directory).restore()
        XCTAssertEqual(stored.map(\.id), [local.id])
        XCTAssertNil(stored.first?.remote)
    }

    private func localTrack() -> Track {
        // Missing files intentionally remain indexed for repair; no music bytes
        // are needed to exercise the asynchronous metadata publication boundary.
        Track(id: "local-kept", title: "Local", artist: "Artist", album: "Local Album", audioFile: "kept.wav",
              palette: .local, duration: 20, lyrics: "", isDemo: false, isLyricDemo: false)
    }

    private func remoteTrack(_ id: String) -> Track {
        Track(id: "remote:" + id, title: id, artist: "Artist", album: "Cloud Album", audioFile: "",
            palette: .local, duration: 20, lyrics: "", isDemo: false, isLyricDemo: false,
            remote: RemoteTrackReference(connectionID: "connection", songID: id, albumID: "album", coverArtID: nil))
    }

    private func environment() throws -> RestoreEnvironment {
        let suite = "OneTape.restore-race." + UUID().uuidString
        return RestoreEnvironment(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
                                  defaults: try XCTUnwrap(UserDefaults(suiteName: suite)), suite: suite)
    }
}

private actor RestorePublicationGate {
    private let didEnter: @Sendable () -> Void
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(didEnter: @escaping @Sendable () -> Void) { self.didEnter = didEnter }

    func hold() async {
        didEnter()
        guard !isOpen else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume(); continuation = nil
    }
}

private struct RestoreEnvironment {
    let directory: URL
    let defaults: UserDefaults
    let suite: String

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suite)
    }
}
