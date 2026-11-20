import Foundation

enum CraftedSide: String, Codable, CaseIterable, Identifiable, Sendable {
    case a, b
    var id: String { rawValue }
    var label: String { self == .a ? "A 面" : "B 面" }
}

enum SleeveDesign: String, Codable, CaseIterable, Identifiable, Sendable {
    case typographic, photo, split
    var id: String { rawValue }
    var label: String {
        switch self { case .typographic: return "字印"; case .photo: return "照片"; case .split: return "拼色" }
    }
}

enum SleeveColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case ink, cobalt, vermilion, olive
    var id: String { rawValue }
    var label: String {
        switch self { case .ink: return "夜墨"; case .cobalt: return "钴蓝"; case .vermilion: return "朱砂"; case .olive: return "苔绿" }
    }
    var hex: String {
        switch self { case .ink: return "181C28"; case .cobalt: return "2546B8"; case .vermilion: return "B94332"; case .olive: return "52624A" }
    }
}

struct CraftedRecord: Identifiable, Codable, Equatable, Sendable {
    var id: String = UUID().uuidString
    var title = ""
    var dedication = ""
    var sideA: [String] = []
    var sideB: [String] = []
    var design: SleeveDesign = .typographic
    var color: SleeveColor = .cobalt
    var coverAsset: String? = nil
    var manualFlip = true
    var isDraft = true
    var createdAt = Date()
    var updatedAt = Date()
    var collectedAt: Date? = nil
    var completedAt: Date? = nil

    var allTrackIDs: [String] { sideA + sideB }
    func trackIDs(on side: CraftedSide) -> [String] { side == .a ? sideA : sideB }

    /// Collection/completion timestamps do not create a new edition of the printed record.
    func hasSameEdition(as other: CraftedRecord) -> Bool {
        id == other.id && title == other.title && dedication == other.dedication &&
        sideA == other.sideA && sideB == other.sideB && design == other.design &&
        color == other.color && coverAsset == other.coverAsset && manualFlip == other.manualFlip
    }

    func validate() throws {
        guard Self.validID(id), title.count <= 60, dedication.count <= 600,
              allTrackIDs.count <= 40, allTrackIDs.allSatisfy(Self.validID),
              Set(allTrackIDs).count == allTrackIDs.count,
              Self.validDates([createdAt, updatedAt] + [collectedAt, completedAt].compactMap { $0 }),
              coverAsset.map(CraftedArchive.validAsset) ?? true else { throw CraftedArchiveError.invalidRecord }
        if !isDraft {
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !sideA.isEmpty else {
                throw CraftedArchiveError.unfinishedRecord
            }
        }
        guard !isDraft || (collectedAt == nil && completedAt == nil) else { throw CraftedArchiveError.invalidRecord }
    }

    static func validID(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 4_096 && !value.contains("\0")
    }
    static func validDates(_ dates: [Date]) -> Bool { dates.allSatisfy { $0.timeIntervalSinceReferenceDate.isFinite } }
}

struct SongMemory: Identifiable, Codable, Equatable, Sendable {
    var id: String = UUID().uuidString
    var trackID: String
    var text = ""
    /// Optional and chosen by the person. Import or playback timestamps never masquerade as a memory date.
    var rememberedOn: Date? = nil
    var photoAsset: String? = nil
    var createdAt = Date()
    var updatedAt = Date()

    func validate() throws {
        guard CraftedRecord.validID(id), CraftedRecord.validID(trackID), text.count <= 2_000,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || photoAsset != nil,
              CraftedRecord.validDates([createdAt, updatedAt] + [rememberedOn].compactMap { $0 }),
              photoAsset.map(CraftedArchive.validAsset) ?? true else { throw CraftedArchiveError.invalidMemory }
    }
}

struct CraftedArchive: Codable, Equatable, Sendable {
    var version = 1
    var records: [CraftedRecord] = []
    var memories: [SongMemory] = []

    func validate() throws {
        guard version == 1, records.count <= 2_000, memories.count <= 20_000,
              Set(records.map(\.id)).count == records.count,
              Set(memories.map(\.id)).count == memories.count else { throw CraftedArchiveError.corruptArchive }
        try records.forEach { try $0.validate() }
        try memories.forEach { try $0.validate() }
    }

    static func validAsset(_ name: String) -> Bool {
        guard name.hasPrefix("craft-"), name.hasSuffix(".jpg"), !name.contains("/"), !name.contains("\\") else { return false }
        return UUID(uuidString: String(name.dropFirst(6).dropLast(4))) != nil
    }
}

enum CraftedArchiveError: Error, LocalizedError {
    case notReady, corruptArchive, invalidRecord, unfinishedRecord, invalidMemory, invalidPhoto, missingTarget, busy
    case saveFailed(cleanupPending: Bool)
    var errorDescription: String? {
        switch self {
        case .notReady: return "唱片柜尚未读取完成，请稍后重试。"
        case .corruptArchive: return "唱片柜资料无法完整读取，原文件已保留；请重试，不会覆盖旧资料。"
        case .invalidRecord: return "唱片资料无法保存：歌曲不能重复，最多 40 首，标题最多 60 字，寄语最多 600 字。"
        case .unfinishedRecord: return "请为唱片写下名字，并在 A 面至少放入一首歌。"
        case .invalidMemory: return "请写下一段记忆或放入照片，文字最多 2000 字。"
        case .invalidPhoto: return "照片未能保存，请重新裁切并选择完整的 JPEG 图片。"
        case .missingTarget: return "这张唱片暂不可用，请返回唱片柜重试。"
        case .busy: return "正在保存本次修改，请稍等。"
        case .saveFailed(let cleanup): return "修改未能保存，旧资料已保留，可以重试。" + (cleanup ? " 部分本次暂存照片未能清理。" : "")
        }
    }
}
