import Combine
import Foundation
import UIKit

/// UI-facing archive coordination only; the player owns media time and the listening session.
@MainActor
final class CraftedRecordsStore: ObservableObject {
    @Published private(set) var records: [CraftedRecord] = []
    @Published private(set) var memories: [SongMemory] = []
    @Published private(set) var images: [String: UIImage] = [:]
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published var error: String?
    private let repository: CraftedArchiveRepository
    private var retainedEditionAsset: String?
    private var editionPreparationRevision = 0
    private let editionPhotoRepairMessage = "本次播放版本的封面暂时无法读取；曲序和文字仍保留，可重新选择照片修复。"

    init(directory: URL? = nil) {
        let location = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stillroom/CraftedRecords", isDirectory: true)
        repository = CraftedArchiveRepository(directory: location)
    }

    func restore() async {
        guard !busy else { return }
        busy = true
        error = nil
        defer { busy = false }
        do {
            let archive = try await repository.restore()
            await publish(archive)
            ready = true
        } catch {
            // Existing in-memory records remain visible when a later disk read fails. New writes are blocked.
            ready = false
            self.error = error.localizedDescription
        }
    }

    func saveRecord(_ record: CraftedRecord, photoJPEG: Data? = nil) async -> Bool {
        await mutate { try await self.repository.saveRecord(record, photoJPEG: photoJPEG) }
    }

    func saveMemory(_ memory: SongMemory, photoJPEG: Data? = nil) async -> Bool {
        await mutate { try await self.repository.saveMemory(memory, photoJPEG: photoJPEG) }
    }

    func collect(_ id: String) async -> Bool {
        await mutate { try await self.repository.collect(id) }
    }

    func markCompleted(_ id: String) async -> Bool {
        await mutate { try await self.repository.markCompleted(id) }
    }

    func discardDraft(_ id: String) async -> Bool {
        await mutate { try await self.repository.discardDraft(id) }
    }

    func memories(for trackID: String) -> [SongMemory] {
        memories.filter { $0.trackID == trackID }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Playback owns a frozen edition; edits can replace that edition's cover in the current archive.
    /// Keep at most one unreferenced edition image, independently of document save/busy state.
    @discardableResult func prepareEdition(_ record: CraftedRecord) async -> Bool {
        if error == editionPhotoRepairMessage { error = nil }
        editionPreparationRevision += 1
        let request = editionPreparationRevision
        retainedEditionAsset = record.coverAsset
        pruneImages()
        guard let name = record.coverAsset else { return true }
        guard images[name] == nil else { return true }
        do {
            let bytes = try await repository.loadRetainedAsset(name)
            guard request == editionPreparationRevision, retainedEditionAsset == name else { return false }
            guard let image = UIImage(data: bytes) else { throw CraftedArchiveError.invalidPhoto }
            images[name] = image
            return true
        } catch {
            guard request == editionPreparationRevision else { return false }
            self.error = editionPhotoRepairMessage
            return false
        }
    }

    private func mutate(_ operation: () async throws -> CraftedArchive) async -> Bool {
        guard ready else { error = CraftedArchiveError.notReady.localizedDescription; return false }
        // An editor awaiting a disk commit cannot capture a second stale archive snapshot. Repeating an
        // action remains explicit and retryable instead of overwriting a concurrent completion or memory.
        guard !busy else { error = CraftedArchiveError.busy.localizedDescription; return false }
        busy = true
        error = nil
        defer { busy = false }
        do {
            let archive = try await operation()
            await publish(archive)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func publish(_ archive: CraftedArchive) async {
        records = archive.records.sorted { $0.updatedAt > $1.updatedAt }
        memories = archive.memories.sorted { $0.createdAt > $1.createdAt }
        do {
            let assets = try await repository.loadAssets()
            var currentImages = assets.data.compactMapValues { UIImage(data: $0) }
            if let retainedEditionAsset, let retained = images[retainedEditionAsset] {
                currentImages[retainedEditionAsset] = retained
            }
            images = currentImages
            if !assets.unavailable.isEmpty {
                error = "有 \(assets.unavailable.count) 张照片暂时无法读取；唱片、曲序和文字仍保留，可重新选择照片修复。"
            }
        } catch {
            // The document has already committed. An artwork read failure cannot turn a successful save
            // into a retry that creates another record; keep metadata and report the repairable picture issue.
            self.error = "资料已保存，照片暂时无法读取，请重新打开唱片柜重试。"
        }
    }

    private func pruneImages() {
        var names = Set(records.compactMap(\.coverAsset) + memories.compactMap(\.photoAsset))
        if let retainedEditionAsset { names.insert(retainedEditionAsset) }
        images = images.filter { names.contains($0.key) }
    }
}
