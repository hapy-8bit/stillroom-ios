import XCTest
import UIKit
@testable import Stillroom

final class CraftedArchiveTests: XCTestCase {
    func testSidesKeepChosenOrderAndRejectDuplicatesRatherThanSilentlyDroppingSongs() throws {
        var record = CraftedRecord(title: "回程", sideA: ["night", "sea"], sideB: ["window"], isDraft: false)
        try record.validate()
        XCTAssertEqual(record.trackIDs(on: .a), ["night", "sea"])
        XCTAssertEqual(record.trackIDs(on: .b), ["window"])
        XCTAssertEqual(record.allTrackIDs, ["night", "sea", "window"])
        record.sideB = ["sea"]
        XCTAssertThrowsError(try record.validate())
        XCTAssertEqual(record.allTrackIDs, ["night", "sea", "sea"])
    }

    func testDraftMayBeEmptyButPressingNeedsATitleAndOneATrack() throws {
        var record = CraftedRecord()
        try record.validate()
        record.isDraft = false
        XCTAssertThrowsError(try record.validate())
        record.title = "一张私人唱片"; record.sideB = ["night"]
        XCTAssertThrowsError(try record.validate())
        record.sideA = ["sea"]
        try record.validate()
        record.title = String(repeating: "字", count: 61)
        XCTAssertThrowsError(try record.validate())
        record.title = "一张私人唱片"; record.dedication = String(repeating: "字", count: 601)
        XCTAssertThrowsError(try record.validate())
    }

    func testMissingLibraryIDsArePreservedAndPhotoNamesCannotEscapeArchive() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CraftedArchiveRepository(directory: directory)
        _ = try await repository.restore()
        let record = CraftedRecord(title: "旧收藏", sideA: ["file-no-longer-in-library"], isDraft: false)
        _ = try await repository.saveRecord(record)
        let reopened = CraftedArchiveRepository(directory: directory)
        let restored = try await reopened.restore()
        XCTAssertEqual(restored.records.first?.sideA, ["file-no-longer-in-library"])
        var unsafe = record; unsafe.coverAsset = "../outside.jpg"
        do { _ = try await reopened.saveRecord(unsafe); XCTFail("Unsafe asset accepted") }
        catch { XCTAssertTrue(error is CraftedArchiveError) }
    }

    func testCorruptJSONAndUnsupportedVersionsAreNeverOverwritten() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let index = directory.appendingPathComponent("crafted-archive.json")
        for data in [Data("{unfinished".utf8), try JSONEncoder().encode(CraftedArchive(version: 7))] {
            try data.write(to: index)
            let repository = CraftedArchiveRepository(directory: directory)
            do { _ = try await repository.restore(); XCTFail("Corrupt document accepted") } catch {}
            do { _ = try await repository.saveRecord(CraftedRecord()); XCTFail("Write after failed restore accepted") } catch {}
            XCTAssertEqual(try Data(contentsOf: index), data)
        }
    }

    func testPhotoAndCollectionSurviveColdRestoreWithoutInventingCompletion() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CraftedArchiveRepository(directory: directory)
        _ = try await repository.restore()
        let record = CraftedRecord(title: "海边", sideA: ["sea"], sideB: ["window"], isDraft: false)
        let saved = try await repository.saveRecord(record, photoJPEG: jpeg())
        let asset = try XCTUnwrap(saved.records.first?.coverAsset)
        _ = try await repository.collect(record.id)
        let reopened = CraftedArchiveRepository(directory: directory)
        var restored = try await reopened.restore()
        XCTAssertNotNil(restored.records.first?.collectedAt)
        XCTAssertNil(restored.records.first?.completedAt)
        let photos = try await reopened.loadAssets()
        XCTAssertEqual(photos.data[asset], try Data(contentsOf: directory.appendingPathComponent(asset)))
        XCTAssertTrue(photos.unavailable.isEmpty)
        restored = try await reopened.markCompleted(record.id)
        XCTAssertNotNil(restored.records.first?.completedAt)
        let oldEditorSnapshot = saved.records[0]
        restored = try await reopened.saveRecord(oldEditorSnapshot)
        XCTAssertNotNil(restored.records.first?.completedAt, "An older editor cannot erase the completed listening session")
        XCTAssertNotNil(restored.records.first?.collectedAt)
    }

    func testFailedPhotoReplacementKeepsOldDocumentAndOldPhotoAndCleansOnlyNewAsset() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CraftedArchiveRepository(directory: directory)
        _ = try await repository.restore()
        let record = CraftedRecord(title: "夜车", sideA: ["night"], isDraft: false)
        let saved = try await repository.saveRecord(record, photoJPEG: jpeg())
        let index = directory.appendingPathComponent("crafted-archive.json")
        let before = try Data(contentsOf: index)
        let oldAsset = try XCTUnwrap(saved.records.first?.coverAsset)
        let photo = try Data(contentsOf: directory.appendingPathComponent(oldAsset))
        let failing = CraftedArchiveRepository(directory: directory, indexWriter: { _, _ in throw CocoaError(.fileWriteUnknown) })
        _ = try await failing.restore()
        do { _ = try await failing.saveRecord(saved.records[0], photoJPEG: jpeg()); XCTFail("Injected commit failure ignored") } catch {}
        XCTAssertEqual(try Data(contentsOf: index), before)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(oldAsset)), photo)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".jpg") }, [oldAsset])
    }

    func testMalformedPhotoDoesNotCreateAnArchiveMutation() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CraftedArchiveRepository(directory: directory)
        _ = try await repository.restore()
        do {
            _ = try await repository.saveRecord(CraftedRecord(title: "照片", sideA: ["sea"], isDraft: false), photoJPEG: Data([255, 216, 1, 2, 255, 217]))
            XCTFail("JPEG marker wrapper is not a decodable photograph")
        } catch {}
        let restored = try await repository.restore()
        XCTAssertTrue(restored.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("crafted-archive.json").path))
    }

    func testPhotoOnlyMemoryHasNoInventedDateAndCannotBeRetargeted() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CraftedArchiveRepository(directory: directory)
        _ = try await repository.restore()
        let saved = try await repository.saveMemory(SongMemory(trackID: "sea"), photoJPEG: jpeg())
        let memory = try XCTUnwrap(saved.memories.first)
        XCTAssertNil(memory.rememberedOn)
        XCTAssertTrue(memory.text.isEmpty)
        var retargeted = memory; retargeted.trackID = "night"
        do { _ = try await repository.saveMemory(retargeted); XCTFail("Memory retargeted to another song") } catch {}
        let reopened = CraftedArchiveRepository(directory: directory)
        let archive = try await reopened.restore()
        XCTAssertEqual(archive.memories.first?.trackID, "sea")
    }

    @MainActor func testMissingPhotoStillRestoresTextAndRecordOrderWithVisibleWarning() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let missing = "craft-" + UUID().uuidString + ".jpg"
        let record = CraftedRecord(title: "保留的封套", sideA: ["night", "sea"], coverAsset: missing, isDraft: false)
        let memory = SongMemory(trackID: "sea", text: "那次回程", photoAsset: missing)
        try JSONEncoder().encode(CraftedArchive(records: [record], memories: [memory]))
            .write(to: directory.appendingPathComponent("crafted-archive.json"))
        let store = CraftedRecordsStore(directory: directory)
        await store.restore()
        XCTAssertTrue(store.ready)
        XCTAssertEqual(store.records.first?.sideA, ["night", "sea"])
        XCTAssertEqual(store.memories(for: "sea").first?.text, "那次回程")
        XCTAssertNotNil(store.error)
        XCTAssertTrue(store.images.isEmpty)
    }

    @MainActor func testStorePublishesOnlySuccessfulSaveAndDraftDiscardCannotRemoveReadyRecord() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CraftedRecordsStore(directory: directory)
        await store.restore()
        let draft = CraftedRecord()
        let draftSaved = await store.saveRecord(draft)
        XCTAssertTrue(draftSaved)
        let discarded = await store.discardDraft(draft.id)
        XCTAssertTrue(discarded); XCTAssertTrue(store.records.isEmpty)
        let ready = CraftedRecord(title: "完成的唱片", sideA: ["sea"], isDraft: false)
        let saved = await store.saveRecord(ready)
        XCTAssertTrue(saved)
        var bad = ready; bad.sideB = ["sea"]
        let invalid = await store.saveRecord(bad)
        XCTAssertFalse(invalid)
        XCTAssertEqual(store.records.first?.allTrackIDs, ["sea"])
        let removeReady = await store.discardDraft(ready.id)
        XCTAssertFalse(removeReady)
        XCTAssertEqual(store.records.count, 1)
    }

    @MainActor func testFrozenCoverCanBeReloadedAfterCurrentCoverChangesAndRemainsAcrossPublish() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CraftedRecordsStore(directory: directory)
        await store.restore()
        let oldJPEG = jpeg(color: .blue)
        let original = CraftedRecord(title: "初版封套", sideA: ["sea"], isDraft: false)
        let firstSaved = await store.saveRecord(original, photoJPEG: oldJPEG)
        XCTAssertTrue(firstSaved)
        let frozen = try XCTUnwrap(store.records.first)
        let oldAsset = try XCTUnwrap(frozen.coverAsset)
        let replacementSaved = await store.saveRecord(frozen, photoJPEG: jpeg(color: .orange))
        XCTAssertTrue(replacementSaved)
        let current = try XCTUnwrap(store.records.first)
        let currentAsset = try XCTUnwrap(current.coverAsset)
        XCTAssertNotEqual(oldAsset, currentAsset)
        XCTAssertNil(store.images[oldAsset], "The old image starts outside the current document cache")
        let before = try Data(contentsOf: directory.appendingPathComponent("crafted-archive.json"))
        let loaded = await store.prepareEdition(frozen)
        XCTAssertTrue(loaded)
        XCTAssertFalse(store.busy)
        XCTAssertEqual(store.images[oldAsset]?.pngData(), UIImage(data: oldJPEG)?.pngData())
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("crafted-archive.json")), before)
        let memorySaved = await store.saveMemory(SongMemory(trackID: "sea", text: "封套换过，正在播放的初版仍保留。"))
        XCTAssertTrue(memorySaved)
        XCTAssertNotNil(store.images[oldAsset])
        XCTAssertNotNil(store.images[currentAsset])
        let changedEdition = await store.prepareEdition(current)
        XCTAssertTrue(changedEdition)
        XCTAssertNil(store.images[oldAsset], "Only one unreferenced edition cover is retained")
        XCTAssertNotNil(store.images[currentAsset])
    }

    @MainActor func testMissingFrozenPhotoReportsRepairWithoutChangingCurrentArchiveOrBusyState() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CraftedRecordsStore(directory: directory)
        await store.restore()
        let saved = await store.saveRecord(CraftedRecord(title: "曾经的封套", sideA: ["sea"], isDraft: false), photoJPEG: jpeg())
        XCTAssertTrue(saved)
        let frozen = try XCTUnwrap(store.records.first)
        let oldAsset = try XCTUnwrap(frozen.coverAsset)
        let changed = await store.saveRecord(frozen, photoJPEG: jpeg(color: .orange))
        XCTAssertTrue(changed)
        try FileManager.default.removeItem(at: directory.appendingPathComponent(oldAsset))
        let before = try Data(contentsOf: directory.appendingPathComponent("crafted-archive.json"))
        let loaded = await store.prepareEdition(frozen)
        XCTAssertFalse(loaded)
        XCTAssertFalse(store.busy)
        XCTAssertTrue(store.error?.contains("重新选择照片修复") == true)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("crafted-archive.json")), before)
        XCTAssertNotNil(store.records.first?.coverAsset.flatMap { store.images[$0] })
    }

    func testRetainedAssetLoaderRejectsPathsAndMalformedAppOwnedPhotos() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CraftedArchiveRepository(directory: directory)
        _ = try await repository.restore()
        do { _ = try await repository.loadRetainedAsset("../outside.jpg"); XCTFail("Escaping asset name accepted") } catch {}
        let asset = "craft-" + UUID().uuidString + ".jpg"
        try Data([255, 216, 1, 2, 255, 217]).write(to: directory.appendingPathComponent(asset))
        do { _ = try await repository.loadRetainedAsset(asset); XCTFail("JPEG marker wrapper accepted") } catch {}
    }

    func testEditionIdentityIgnoresLifecycleDatesButDetectsChangedPrintedContent() {
        let original = CraftedRecord(title: "初版", dedication: "写在封套背面", sideA: ["sea", "window"], sideB: ["night"], isDraft: false)
        var changed = original
        changed.createdAt = .distantPast; changed.updatedAt = .distantFuture
        changed.completedAt = Date(); changed.collectedAt = Date()
        XCTAssertTrue(changed.hasSameEdition(as: original))
        changed.sideA.reverse()
        XCTAssertFalse(changed.hasSameEdition(as: original))
        changed = original; changed.coverAsset = "craft-" + UUID().uuidString + ".jpg"
        XCTAssertFalse(changed.hasSameEdition(as: original))
        changed = original; changed.dedication = "另一次制作"
        XCTAssertFalse(changed.hasSameEdition(as: original))
    }

    func testEditingACompletedEditionClearsCompletionButRetainsCollectionAndUnchangedSaveKeepsBoth() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CraftedArchiveRepository(directory: directory)
        _ = try await repository.restore()
        let editorSnapshot = CraftedRecord(title: "第一版", sideA: ["sea", "window"], sideB: ["night"], isDraft: false)
        _ = try await repository.saveRecord(editorSnapshot)
        _ = try await repository.markCompleted(editorSnapshot.id)
        let collected = try await repository.collect(editorSnapshot.id)
        let completed = try XCTUnwrap(collected.records.first)
        XCTAssertNotNil(completed.completedAt)
        let unchanged = try await repository.saveRecord(editorSnapshot)
        XCTAssertEqual(unchanged.records.first?.completedAt, completed.completedAt)
        XCTAssertEqual(unchanged.records.first?.collectedAt, completed.collectedAt)
        var changed = editorSnapshot
        changed.sideA.reverse()
        changed.dedication = "重新编排的第二版"
        let replacement = try await repository.saveRecord(changed)
        XCTAssertNil(replacement.records.first?.completedAt)
        XCTAssertEqual(replacement.records.first?.collectedAt, completed.collectedAt)
        let reopened = CraftedArchiveRepository(directory: directory)
        let restored = try await reopened.restore()
        XCTAssertNil(restored.records.first?.completedAt)
        XCTAssertEqual(restored.records.first?.sideA, ["window", "sea"])
        XCTAssertEqual(restored.records.first?.collectedAt, completed.collectedAt)
    }

    private func temporaryDirectory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func jpeg(color: UIColor = UIColor(red: 0.15, green: 0.3, blue: 0.65, alpha: 1)) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }.jpegData(compressionQuality: 0.85)!
    }
}
