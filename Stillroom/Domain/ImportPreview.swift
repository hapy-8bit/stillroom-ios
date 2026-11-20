import Foundation

enum ImportMediaKind: String, Sendable {
    case audio, lyrics, cover, unsupported

    static func classify(_ name: String) -> Self {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"),
              !name.contains("\\"), !name.contains("\0") else { return .unsupported }
        switch URL(fileURLWithPath: name).pathExtension.lowercased() {
        case "mp3", "m4a", "aac", "wav", "flac", "aif", "aiff", "caf", "alac": return .audio
        case "lrc", "txt": return .lyrics
        case "jpg", "jpeg", "png": return .cover
        default: return .unsupported
        }
    }

    static func nameKey(_ name: String) -> String {
        URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum MusicImportPhase: Sendable { case choice, preparing, preview, importing, result }
enum ImportCompanionState: Sendable { case target, unmatched, ambiguous, conflict, failed, skipped }
enum ImportResultState: Sendable { case success, skipped, failed }

struct ImportExistingChoice: Identifiable, Sendable {
    let id: String
    let title: String
}

struct ImportAudioPreview: Identifiable, Sendable {
    let id: UUID
    let name: String
    let bytes: Int64
    var detail: String
    var existingChoices: [ImportExistingChoice] = []
    var targetTrackID: String?
    var ownerID: UUID
    var valid = false
    var requiresCopy = false
}

struct ImportAudioTarget: Identifiable, Sendable {
    let id: UUID
    let title: String
}

struct ImportCompanionPreview: Identifiable, Sendable {
    let id: UUID
    let name: String
    let kind: ImportMediaKind
    var state: ImportCompanionState
    var selectedAudioID: UUID?
    var choices: [ImportAudioTarget] = []
    var detail = ""
    var error = ""
    var preview = ""
    /// App-generated JPEG bytes only; views never receive a picker URL or security scope.
    var imageData: Data?
    var appliesToAlbum = false
    var canChooseAlbumScope = false
}

struct MusicImportResult: Identifiable, Sendable {
    let id: UUID
    let name: String
    let state: ImportResultState
    let message: String
}

struct LibraryAppendResult: Sendable {
    let track: Track
    let tracks: [Track]
    let reused: Bool
}

enum ImportPreviewError: LocalizedError {
    case invalidType, emptyOrLarge, targetChanged, unresolved, tooManyFiles, batchTooLarge
    var errorDescription: String? {
        switch self {
        case .invalidType: return "请选择音乐、LRC／TXT 或 JPEG／PNG 文件。"
        case .emptyOrLarge: return "文件为空或过大，请分批添加；音乐限512 MB、歌词1 MB、封面16 MB。"
        case .targetChanged: return "目标歌曲已变化，请重新确认预览。"
        case .unresolved: return "请确认重复歌曲与配套目标，或明确跳过配套。"
        case .tooManyFiles: return "每批最多30个文件；已选内容保留，请分批添加。"
        case .batchTooLarge: return "本批原文件合计限1 GB，请分批添加；已有音乐保留。"
        }
    }
}
