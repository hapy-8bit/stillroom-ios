import Foundation
import Combine

@MainActor
final class MusicImportCoordinator: ObservableObject {
    typealias AudioCommit = @MainActor (Track, URL) async throws -> String
    typealias LyricCommit = @MainActor (String, String, String) async throws -> Void
    typealias CoverCommit = @MainActor (String, URL, Bool) async throws -> Void

    @Published private(set) var phase: MusicImportPhase = .choice
    @Published private(set) var busy = false
    @Published private(set) var audioRows: [ImportAudioPreview] = []
    @Published private(set) var companions: [ImportCompanionPreview] = []
    @Published private(set) var results: [MusicImportResult] = []
    @Published private(set) var error = ""
    @Published private(set) var activeName = ""
    @Published private(set) var completed = 0
    @Published private(set) var total = 0
    @Published private(set) var addedBytes: Int64 = 0

    private let repository: LibraryRepository
    private let staging: ImportStaging
    private let liveTracks: @MainActor () -> [Track]
    private let commitAudio: AudioCommit
    private let commitLyrics: LyricCommit
    private let commitCover: CoverCommit
    private var items: [PreparedImportItem] = []
    private var audioChoices: [UUID: String] = [:]
    private enum Selection { case target(UUID), skip }
    private var companionChoices: [UUID: Selection] = [:]
    private var coverScopes: [UUID: Bool] = [:]
    private var cancelled = false
    private var replacement: (trackID: String, kind: ImportMediaKind, album: Bool, slot: UUID)?

    init(repository: LibraryRepository, directory: URL, tracks: @escaping @MainActor () -> [Track],
         commitAudio: @escaping AudioCommit, commitLyrics: @escaping LyricCommit, commitCover: @escaping CoverCommit) {
        self.repository = repository
        staging = ImportStaging(libraryDirectory: directory)
        liveTracks = tracks
        self.commitAudio = commitAudio
        self.commitLyrics = commitLyrics
        self.commitCover = commitCover
    }

    var title: String {
        guard let replacement else { return "把音乐带进来" }
        return replacement.kind == .lyrics ? "预览歌词与目标" : replacement.album ? "预览整张专辑封面" : "预览歌曲封面"
    }

    var canAddFiles: Bool { replacement == nil && phase == .preview && !busy }
    var canConfirm: Bool {
        !busy && phase == .preview && !items.isEmpty && audioRows.contains(where: \.valid) &&
            !audioRows.contains(where: { $0.existingChoices.count > 1 && $0.targetTrackID == nil }) &&
            companions.allSatisfy { [.target, .failed, .skipped].contains($0.state) }
    }

    func cancel() { cancelled = true }

    func reset() async {
        guard !busy else { cancelled = true; return }
        do { try await staging.cleanup() } catch { self.error = "临时预览未完全清理，请重试。"; return }
        items = []; audioRows = []; companions = []; results = []
        audioChoices = [:]; companionChoices = [:]; coverScopes = [:]; replacement = nil
        phase = .choice; error = ""; activeName = ""; completed = 0; total = 0; addedBytes = 0
    }

    func prepare(urls: [URL], folders: Bool = false, append: Bool = false) async {
        guard !busy else { return }
        if urls.isEmpty { return } // A cancelled append picker retains the existing preview and its decisions.
        if !append {
            await reset()
            guard phase == .choice else { return }
        } else if !canAddFiles { return }
        await read(urls: urls, folders: folders, append: append)
    }

    func prepareReplacement(urls: [URL], trackID: String, kind: ImportMediaKind, album: Bool = false) async {
        guard !busy, kind == .lyrics || kind == .cover else { return }
        await reset()
        guard phase == .choice else { return }
        replacement = (trackID, kind, album, UUID())
        await read(urls: Array(urls.prefix(1)), folders: false, append: false)
    }

    private func read(urls: [URL], folders: Bool, append: Bool) async {
        cancelled = false; busy = true; phase = .preparing; error = ""; results = []
        let previousCount = items.count
        do {
            let sources = try await repository.discoverPreview(urls, folders: folders)
            guard items.count + sources.count <= 30 else { throw ImportPreviewError.tooManyFiles }
            total = items.count + sources.count; completed = items.count
            for source in sources {
                if cancelled { break }
                activeName = source.url.lastPathComponent
                let occupied = items.reduce(Int64(0)) { $0 + ($1.error.isEmpty ? $1.bytes : $1.retainedFailedBytes) }
                var item = await staging.stage(source, remainingBytes: 1_073_741_824 - occupied)
                if let replacement, item.kind != replacement.kind {
                    item.error = "文件类型与本次要补充的资料不符，请重新选择。"
                }
                items.append(item); completed += 1
            }
            if cancelled && !append {
                try await staging.cleanup(); items = []; phase = .choice
            } else {
                rebuildPreview(); phase = .preview
                if cancelled { error = "已停止读取；本次已经读取的预览保留，尚未入库。" }
            }
        } catch {
            self.error = error.localizedDescription
            phase = append || previousCount > 0 ? .preview : .choice
            if phase == .preview { rebuildPreview() }
        }
        busy = false
    }

    func chooseAudio(itemID: UUID, trackID: String) {
        guard !busy, phase == .preview,
              audioRows.first(where: { $0.id == itemID })?.existingChoices.contains(where: { $0.id == trackID }) == true else { return }
        audioChoices[itemID] = trackID
        rebuildPreview()
    }

    func chooseCompanion(itemID: UUID, audioID: UUID?) {
        guard !busy, phase == .preview, companions.contains(where: { $0.id == itemID }) else { return }
        if let audioID {
            guard audioRows.contains(where: { $0.id == audioID && $0.valid }) else { return }
            companionChoices[itemID] = .target(audioID)
        } else { companionChoices[itemID] = .skip }
        // Changing the target starts with song scope; whole-album replacement
        // is an explicit separate choice after that target has been shown.
        coverScopes[itemID] = false
        rebuildPreview()
    }

    func chooseCoverScope(itemID: UUID, album: Bool) {
        guard !busy, phase == .preview,
              let row = companions.first(where: { $0.id == itemID }),
              row.canChooseAlbumScope, row.selectedAudioID != nil else { return }
        coverScopes[itemID] = album
        rebuildPreview()
    }

    private func rebuildPreview() {
        if let replacement {
            guard let target = liveTracks().first(where: { $0.id == replacement.trackID }) else {
                audioRows = []; companions = []; error = ImportPreviewError.targetChanged.localizedDescription; return
            }
            audioRows = [ImportAudioPreview(id: replacement.slot, name: target.title, bytes: 0,
                detail: "固定目标：" + target.title + (replacement.album ? " · 整张专辑封面，单曲例外保留" : " · 仅此曲"),
                targetTrackID: target.id, ownerID: replacement.slot, valid: true)]
        } else { buildAudioRows() }
        let choices = audioRows.filter(\.valid).map { ImportAudioTarget(id: $0.id, title: $0.name) }
        let coverCandidates = audioRows.filter(\.valid).compactMap { audio -> ImportCoverAudio? in
            guard let item = items.first(where: { $0.id == audio.id }), let key = albumKey(for: audio) else { return nil }
            return ImportCoverAudio(id: audio.id, directoryID: item.sourceDirectoryID, albumKey: key)
        }
        companions = items.filter { replacement != nil || $0.kind != .audio }.map { item in
            var row = ImportCompanionPreview(id: item.id, name: item.name, kind: replacement?.kind ?? item.kind,
                state: item.error.isEmpty ? .unmatched : .failed, choices: choices,
                detail: item.detail, error: item.error, preview: String(item.lyricText.prefix(1_200)), imageData: item.imageData)
            guard item.error.isEmpty else { return row }
            if let selection = companionChoices[item.id] {
                switch selection {
                case .skip: row.state = .skipped
                case .target(let id): row.selectedAudioID = id; row.state = choices.contains(where: { $0.id == id }) ? .target : .unmatched
                }
            } else if let replacement { row.selectedAudioID = replacement.slot; row.state = .target }
            else {
                let matches = audioRows.filter { $0.valid && ImportMediaKind.nameKey($0.name) == ImportMediaKind.nameKey(item.name) }
                if matches.count == 1 { row.selectedAudioID = matches[0].id; row.state = .target }
                else if matches.count > 1 { row.state = .ambiguous }
                else if item.kind == .cover {
                    let count = items.filter { $0.kind == .cover && $0.error.isEmpty &&
                        $0.sourceDirectoryID == item.sourceDirectoryID && ImportCoverMatching.isFolderCover($0.name) }.count
                    switch ImportCoverMatching.suggest(name: item.name, directoryID: item.sourceDirectoryID,
                                                      candidates: coverCandidates, folderCoverCount: count) {
                    case .none: break
                    case .ambiguous: row.state = .ambiguous
                    case .album(let id):
                        row.selectedAudioID = id; row.state = .target; row.appliesToAlbum = true
                        row.detail += " · 建议用于同目录的整张专辑，保存前可调整范围"
                    }
                }
            }
            row.appliesToAlbum = replacement?.album ?? coverScopes[item.id] ?? row.appliesToAlbum
            row.canChooseAlbumScope = item.kind == .cover && replacement == nil && row.selectedAudioID != nil
            return row
        }
        let candidates = companions.filter { $0.state == .target }
        for row in candidates {
            guard let audioID = row.selectedAudioID, let audio = audioRows.first(where: { $0.id == audioID }) else { continue }
            let clashes = candidates.filter { other in
                guard other.kind == row.kind,
                      let otherAudio = audioRows.first(where: { $0.id == other.selectedAudioID }) else { return false }
                if row.kind == .cover {
                    guard row.appliesToAlbum == other.appliesToAlbum else { return false }
                    if row.appliesToAlbum { return albumKey(for: otherAudio) == albumKey(for: audio) }
                }
                return otherAudio.ownerID == audio.ownerID
            }
            if clashes.count > 1 {
                for clash in clashes {
                    if let index = companions.firstIndex(where: { $0.id == clash.id }) {
                        companions[index].state = .conflict
                        companions[index].error = "同一歌曲存在多个同类资料；请保留一个，其余明确跳过。"
                    }
                }
            }
        }
        addedBytes = audioRows.filter(\.requiresCopy).reduce(0) { $0 + $1.bytes }
        if audioRows.isEmpty { error = "没有可关联的音乐；请继续添加音乐，或从已有歌曲补充资料。" }
    }

    private func buildAudioRows() {
        let existing = liveTracks().filter { !$0.isDemo }
        var owners: [String: ImportAudioPreview] = [:]
        audioRows = items.filter { $0.kind == .audio }.map { item in
            var row = ImportAudioPreview(id: item.id, name: item.name, bytes: item.bytes,
                detail: item.error, ownerID: item.id)
            guard item.error.isEmpty, item.track != nil,
                  item.hash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { return row }
            if let owner = owners[item.hash] {
                row.ownerID = owner.id; row.valid = owner.valid; row.targetTrackID = owner.targetTrackID
                row.detail = "同批内容重复，只保存一次；新配套继续关联"
                return row
            }
            let matches = existing.filter { $0.contentHash == item.hash }
            row.existingChoices = matches.map { ImportExistingChoice(id: $0.id, title: $0.title) }
            if let choice = audioChoices[item.id], matches.contains(where: { $0.id == choice }) { row.targetTrackID = choice }
            else if matches.count == 1 { row.targetTrackID = matches[0].id }
            row.valid = matches.count < 2 || row.targetTrackID != nil
            row.requiresCopy = matches.isEmpty
            row.detail = matches.isEmpty ? "新增音乐" : row.valid ? "复用原歌曲；新歌词和封面仍可补充" : "请选择一个已有歌曲身份"
            if !item.detail.isEmpty { row.detail += " · " + item.detail }
            owners[item.hash] = row
            return row
        }
    }

    private var previewIdentity: String {
        let audio = audioRows.map { "\($0.id):\($0.targetTrackID ?? ""):\($0.ownerID):\($0.requiresCopy)" }.joined(separator: "|")
        let covers = companions.filter { $0.kind == .cover }.map { row in
            let key = audioRows.first(where: { $0.id == row.selectedAudioID }).flatMap(albumKey(for:)) ?? ""
            return "\(row.id):\(row.selectedAudioID?.uuidString ?? ""):\(row.appliesToAlbum):\(key)"
        }.joined(separator: "|")
        return audio + "|" + covers
    }

    private func albumKey(for audio: ImportAudioPreview) -> String? {
        if let id = audio.targetTrackID, let track = liveTracks().first(where: { $0.id == id }) { return track.albumKey }
        return items.first(where: { $0.id == audio.id })?.track?.albumKey
    }

    func confirm() async {
        guard !busy, phase == .preview else { return }
        let before = previewIdentity
        rebuildPreview()
        guard before == previewIdentity else { error = "曲库目标已变化，请重新核对上方预览；尚未开始导入。"; return }
        guard canConfirm else { error = ImportPreviewError.unresolved.localizedDescription; return }
        cancelled = false; busy = true; phase = .importing; results = []; error = ""
        completed = 0; total = items.count
        var targets: [UUID: String] = [:]
        if let replacement { targets[replacement.slot] = replacement.trackID }
        if replacement == nil {
            for audio in audioRows {
                if cancelled { break }
                activeName = audio.name
                do {
                    guard audio.valid else { throw ImportPreviewError.invalidType }
                    let target: String
                    if audio.ownerID != audio.id {
                        guard let owner = targets[audio.ownerID] else { throw ImportPreviewError.targetChanged }
                        target = owner
                    } else if let old = audio.targetTrackID { target = old }
                    else {
                        guard let track = items.first(where: { $0.id == audio.id })?.track else { throw ImportPreviewError.invalidType }
                        target = try await commitAudio(track, staging.directory)
                    }
                    guard liveTracks().contains(where: { $0.id == target }) else { throw ImportPreviewError.targetChanged }
                    targets[audio.id] = target
                    let inserted = audio.requiresCopy && items.first(where: { $0.id == audio.id })?.track?.id == target
                    results.append(MusicImportResult(id: audio.id, name: audio.name, state: inserted ? .success : .skipped,
                        message: (inserted ? "音乐已保存到本机" : "重复音频已复用，继续补充资料") +
                            (items.first(where: { $0.id == audio.id })?.detail.contains("未能") == true ? "；内嵌封面未能保存，可稍后补充。" : "")))
                } catch { fail(audio.id, audio.name, error) }
                completed += 1
            }
        }
        for row in companions {
            if cancelled { break }
            activeName = row.name
            do {
                if row.state == .failed { throw NSError(domain: "Import", code: 1, userInfo: [NSLocalizedDescriptionKey: row.error]) }
                if row.state == .skipped {
                    results.append(MusicImportResult(id: row.id, name: row.name, state: .skipped, message: "已按选择跳过，旧资料保留"))
                } else {
                    guard row.state == .target, let id = row.selectedAudioID, let target = targets[id],
                          let item = items.first(where: { $0.id == row.id }), item.error.isEmpty else { throw ImportPreviewError.unresolved }
                    if row.kind == .lyrics { try await commitLyrics(target, item.lyricText, item.lyricOriginal) }
                    else if row.kind == .cover, let url = item.coverURL { try await commitCover(target, url, row.appliesToAlbum) }
                    else { throw ImportPreviewError.invalidType }
                    results.append(MusicImportResult(id: row.id, name: row.name, state: .success, message: "资料已保存到确认的目标"))
                }
            } catch { fail(row.id, row.name, error) }
            completed += 1
        }
        if cancelled { error = "已取消剩余项目；已经保存的音乐和资料保留。" }
        do { try await staging.cleanup() } catch { self.error += " 临时预览尚未完全清理，请重试。" }
        phase = .result; busy = false
    }

    private func fail(_ id: UUID, _ name: String, _ error: Error) {
        results.append(MusicImportResult(id: id, name: name, state: .failed, message: error.localizedDescription))
    }
}
