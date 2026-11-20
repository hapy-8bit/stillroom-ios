import XCTest
import UIKit
@testable import Stillroom

@MainActor
final class ImportAlbumCoverTests: XCTestCase {
    func testSameDirectorySingleAlbumFolderImageSuggestsAlbumAndRequiresConfirmation() async throws {
        let env = try Harness()
        defer { env.cleanup() }
        _ = try await LocalCoverFixtures.audio(in: env.root, name: "First", album: "Shared")
        _ = try await LocalCoverFixtures.audio(in: env.root, name: "Second", album: "Shared")
        try LocalCoverFixtures.image(.orange).write(to: env.root.appendingPathComponent("cover.jpg"))
        await env.coordinator.prepare(urls: [env.root], folders: true)
        let cover = try XCTUnwrap(env.coordinator.companions.first)
        XCTAssertEqual(cover.state, .target)
        XCTAssertTrue(cover.appliesToAlbum)
        XCTAssertTrue(cover.canChooseAlbumScope)
        XCTAssertTrue(env.coordinator.canConfirm)
        XCTAssertTrue(env.tracks.isEmpty, "A suggested folder image is not a commit")
        XCTAssertTrue(env.coverTargets.isEmpty)
        await env.coordinator.confirm()
        XCTAssertEqual(env.tracks.count, 2)
        XCTAssertEqual(env.coverTargets.count, 1)
        XCTAssertEqual(env.coverTargets.first?.1, true)
        let serialized = try JSONEncoder().encode(try await LibraryRepository(directory: env.directory).restore())
        XCTAssertFalse(String(decoding: serialized, as: UTF8.self).contains(env.root.path),
                       "Source directory equality tokens and original paths are preview-only")
    }

    func testMixedAlbumsInOneDirectoryDoNotSilentlyShareFolderImage() async throws {
        let env = try Harness()
        defer { env.cleanup() }
        _ = try await LocalCoverFixtures.audio(in: env.root, name: "First", album: "One")
        _ = try await LocalCoverFixtures.audio(in: env.root, name: "Second", album: "Two")
        try LocalCoverFixtures.image(.orange).write(to: env.root.appendingPathComponent("folder.jpg"))
        await env.coordinator.prepare(urls: [env.root], folders: true)
        let cover = try XCTUnwrap(env.coordinator.companions.first)
        XCTAssertEqual(cover.state, .ambiguous)
        XCTAssertNil(cover.selectedAudioID)
        XCTAssertFalse(env.coordinator.canConfirm)
        env.coordinator.chooseCompanion(itemID: cover.id, audioID: nil)
        XCTAssertTrue(env.coordinator.canConfirm)
        await env.coordinator.confirm()
        XCTAssertTrue(env.coverTargets.isEmpty)
        XCTAssertEqual(env.tracks.count, 2)
    }

    func testManualScopeCanPreserveSongExceptionAndConflictingAlbumChoicesRequireResolution() async throws {
        let env = try Harness()
        defer { env.cleanup() }
        _ = try await LocalCoverFixtures.audio(in: env.root, name: "First", album: "Shared")
        _ = try await LocalCoverFixtures.audio(in: env.root, name: "Second", album: "Shared")
        try LocalCoverFixtures.image(.orange).write(to: env.root.appendingPathComponent("cover.jpg"))
        try LocalCoverFixtures.image(.blue).write(to: env.root.appendingPathComponent("folder.jpg"))
        await env.coordinator.prepare(urls: [env.root], folders: true)
        XCTAssertTrue(env.coordinator.companions.allSatisfy { $0.state == .ambiguous })
        let audio = try XCTUnwrap(env.coordinator.audioRows.first)
        let covers = env.coordinator.companions
        for cover in covers {
            env.coordinator.chooseCompanion(itemID: cover.id, audioID: audio.id)
            env.coordinator.chooseCoverScope(itemID: cover.id, album: true)
        }
        XCTAssertFalse(env.coordinator.canConfirm)
        XCTAssertTrue(env.coordinator.companions.allSatisfy { $0.state == .conflict })
        env.coordinator.chooseCoverScope(itemID: covers[1].id, album: false)
        XCTAssertTrue(env.coordinator.canConfirm)
        await env.coordinator.confirm()
        XCTAssertEqual(env.coverTargets.count, 2)
        XCTAssertEqual(Set(env.coverTargets.map { $0.1 }), [true, false])
    }

    func testFolderSuggestionNeverCrossesDirectoryBoundary() {
        let a = UUID(), b = UUID()
        let candidates = [ImportCoverAudio(id: a, directoryID: "first-directory", albumKey: "Album"),
                          ImportCoverAudio(id: b, directoryID: "second-directory", albumKey: "Different Album")]
        XCTAssertEqual(ImportCoverMatching.suggest(name: "cover.jpg", directoryID: "first-directory",
                                                   candidates: candidates, folderCoverCount: 1), .album(a))
        XCTAssertEqual(ImportCoverMatching.suggest(name: "folder.png", directoryID: "no-music-directory",
                                                   candidates: candidates, folderCoverCount: 1), .none)
        XCTAssertEqual(ImportCoverMatching.suggest(name: "other.jpg", directoryID: "first-directory",
                                                   candidates: candidates, folderCoverCount: 1), .none)
    }

    @MainActor private final class Harness {
        let root: URL
        let directory: URL
        let repository: LibraryRepository
        var tracks: [Track] = []
        var coverTargets: [(String, Bool)] = []
        var coordinator: MusicImportCoordinator!

        init() throws {
            root = try LocalCoverFixtures.directory()
            directory = root.appendingPathComponent("Library")
            repository = LibraryRepository(directory: directory)
            coordinator = MusicImportCoordinator(repository: repository, directory: directory,
                tracks: { [weak self] in self?.tracks ?? [] }, commitAudio: { [weak self] track, folder in
                    guard let self else { throw LibraryError.missingAudio }
                    let result = try await self.repository.appendPreviewAudio(track, from: folder)
                    self.tracks = result.tracks
                    return result.track.id
                }, commitLyrics: { _, _, _ in }, commitCover: { [weak self] id, _, album in
                    self?.coverTargets.append((id, album))
                })
        }

        func cleanup() { try? FileManager.default.removeItem(at: root) }
    }
}
