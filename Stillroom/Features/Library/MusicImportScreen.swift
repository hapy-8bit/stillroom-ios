import SwiftUI
import UniformTypeIdentifiers

enum MusicImportPresentation { case stillroom, oneTape }

/// Only snapshots and intentions cross this view; picker scopes and persistence stay in adapters.
struct MusicImportScreen: View {
    @ObservedObject var coordinator: MusicImportCoordinator
    var presentation: MusicImportPresentation = .stillroom
    @Environment(\.dismiss) private var dismiss
    @State private var pickerVisible = false
    @State private var folders = false
    @State private var bundle = false
    @State private var append = false
    @State private var pickerError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                importBackground
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if coordinator.phase == .choice { sourceChoices }
                        if coordinator.busy { progress }
                        if coordinator.phase == .preview { preview }
                        if coordinator.phase == .result { results }
                        if !coordinator.error.isEmpty { Text(coordinator.error).foregroundStyle(importWarning) }
                        if let pickerError { Text(pickerError).foregroundStyle(importWarning) }
                    }.font(.subheadline).padding(24)
                }
            }.navigationTitle(coordinator.title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { Task { await coordinator.reset(); dismiss() } }
                            .disabled(coordinator.busy).accessibilityIdentifier("import.close")
                    }
                }
        }
        .tint(presentation == .oneTape ? .white : RoomStyle.accent)
        .interactiveDismissDisabled(coordinator.busy)
        .fileImporter(isPresented: $pickerVisible, allowedContentTypes: contentTypes,
                      allowsMultipleSelection: !folders) { result in
            switch result {
            case .success(let urls):
                let isFolder = folders
                let shouldAppend = append
                Task { await coordinator.prepare(urls: urls, folders: isFolder, append: shouldAppend) }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { pickerError = error.localizedDescription }
            }
        }
    }

    @ViewBuilder
    private var importBackground: some View {
        if presentation == .oneTape { Color(white: 0.065).ignoresSafeArea() }
        else { RoomBackground() }
    }

    private var importText: Color { presentation == .oneTape ? .white : RoomStyle.paper }
    private var importSecondary: Color { presentation == .oneTape ? .white.opacity(0.6) : RoomStyle.secondary }
    private var importMuted: Color { presentation == .oneTape ? .white.opacity(0.4) : RoomStyle.muted }
    private var importWarning: Color { presentation == .oneTape ? .orange : RoomStyle.copper }
    private var importSurface: Color { presentation == .oneTape ? Color(white: 0.12) : RoomStyle.surface }

    private var contentTypes: [UTType] {
        if folders { return [.folder] }
        if !bundle { return [.audio] }
        return [.audio, .plainText, .text, .jpeg, .png, UTType(filenameExtension: "lrc") ?? .text]
    }

    private var sourceChoices: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("YOUR OWN COLLECTION").font(RoomStyle.caption(9)).tracking(2).foregroundStyle(importMuted)
            Text(presentation == .oneTape ? "把自己的音乐，\n装进一盘磁带。" : "先放入音乐，\n再确认自己的唱片。").font(.system(.largeTitle, design: .serif)).foregroundStyle(importText)
            sourceButton("选择音乐文件", detail: "先预览，再复制入库", symbol: "doc.badge.plus", id: "import.files") {
                openPicker(folder: false, bundle: false)
            }
            sourceButton("音乐与歌词、封面", detail: "LRC／TXT、JPEG／PNG 同批匹配", symbol: "square.stack.3d.up", id: "import.bundle") {
                openPicker(folder: false, bundle: true)
            }
            sourceButton("选择音乐文件夹", detail: "读取已授权目录中的音乐和配套；每批最多30项", symbol: "folder.badge.plus", id: "import.folder") {
                openPicker(folder: true, bundle: true)
            }
            Text("在系统「文件」中选择自己的音乐或服务器共享文件。文件复制到 \(presentation == .oneTape ? "One Cassette" : "Stillroom")，原件保留；不会从商业订阅曲库下载或自动播放。")
                .font(.caption).foregroundStyle(importSecondary).lineSpacing(5)
            if presentation == .oneTape {
                Text("专辑封面优先读取音乐内嵌图片。也可随音乐选择同目录的 cover.jpg／folder.jpg，并在预览中确认应用到整张专辑；导入后长按专辑封套可设置或更换封面。")
                    .font(.caption).foregroundStyle(importSecondary).lineSpacing(5)
                    .accessibilityIdentifier("import.coverHelp")
            }
        }
    }

    private func sourceButton(_ title: String, detail: String, symbol: String, id: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title2).frame(width: 32)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.headline)
                    Text(detail).font(.caption).foregroundStyle(importSecondary)
                }
                Spacer(minLength: 0)
            }.foregroundStyle(importText).padding(18)
                .background(importSurface, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }

    private func openPicker(folder: Bool, bundle: Bool, append: Bool = false) {
        folders = folder; self.bundle = bundle; self.append = append; pickerError = nil; pickerVisible = true
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(coordinator.phase == .importing ? "保存已确认项目" : "读取与校验所选文件").font(.headline)
                Spacer()
                Button("停止") { coordinator.cancel() }.accessibilityIdentifier("import.cancel")
            }
            ProgressView(value: Double(coordinator.completed), total: Double(max(1, coordinator.total)))
            Text("已处理 \(coordinator.completed) / \(coordinator.total)").font(.caption)
            Text(coordinator.activeName).font(.caption).lineLimit(2)
            Text("停止会保留已经成功保存的项目。读取与确认均不会启动播放。")
                .font(.caption2).foregroundStyle(importSecondary)
        }.foregroundStyle(importText).accessibilityIdentifier("import.progress")
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("确认音乐与资料目标").font(.title2).foregroundStyle(importText)
            Text("预计新增音频 \(ByteCountFormatter.string(fromByteCount: coordinator.addedBytes, countStyle: .file))；配套资料另存。相同音频复用原歌曲，新歌词与封面继续关联。")
                .font(.caption).foregroundStyle(importSecondary)
            ForEach(coordinator.audioRows) { row in audioRow(row) }
            ForEach(coordinator.companions) { row in companionRow(row) }
            if coordinator.canAddFiles {
                Button("继续添加文件到本批") { openPicker(folder: false, bundle: true, append: true) }
                    .accessibilityIdentifier("import.add-files")
            }
            Button("确认保存") { Task { await coordinator.confirm() } }
                .buttonStyle(.borderedProminent).disabled(!coordinator.canConfirm)
                .accessibilityIdentifier("import.confirm")
            Text("歌词／封面只写入上方确认的目标。整张专辑换封面会保留单曲例外；图片按方向校正并居中裁为方形，原文件不变。")
                .font(.caption2).foregroundStyle(importSecondary)
        }
    }

    private func audioRow(_ row: ImportAudioPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(row.name).font(.headline)
            Text(row.detail).font(.caption).foregroundStyle(row.valid ? importSecondary : importWarning)
            if row.existingChoices.count > 1 {
                Picker("保留哪首已有歌曲", selection: Binding(get: { row.targetTrackID ?? "" }, set: {
                    coordinator.chooseAudio(itemID: row.id, trackID: $0)
                })) {
                    Text("请选择").tag("")
                    ForEach(row.existingChoices) { Text($0.title).tag($0.id) }
                }.pickerStyle(.menu)
            }
        }.foregroundStyle(importText).frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).background(importSurface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func companionRow(_ row: ImportCompanionPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(row.name).font(.headline)
            if !row.detail.isEmpty { Text(row.detail).font(.caption).foregroundStyle(importSecondary) }
            if let data = row.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                    .accessibilityLabel("本次裁切后的封面预览")
            }
            if !row.preview.isEmpty { Text(row.preview).font(.caption.monospaced()).lineLimit(8).textSelection(.enabled) }
            if !row.error.isEmpty { Text(row.error).font(.caption).foregroundStyle(importWarning) }
            if row.kind == .cover && row.canChooseAlbumScope {
                Toggle("应用到整张专辑", isOn: Binding(get: { row.appliesToAlbum }, set: {
                    coordinator.chooseCoverScope(itemID: row.id, album: $0)
                }))
                .accessibilityIdentifier("import.coverScope.\(row.id.uuidString)")
            }
            if row.state != .failed {
                Menu {
                    ForEach(row.choices) { target in
                        Button(target.title) { coordinator.chooseCompanion(itemID: row.id, audioID: target.id) }
                    }
                    Button("跳过此配套，保留旧资料") { coordinator.chooseCompanion(itemID: row.id, audioID: nil) }
                } label: {
                    Label(selectionLabel(row), systemImage: row.state == .target ? "checkmark.circle" : "arrow.triangle.branch")
                }.accessibilityIdentifier("import.target.\(row.id.uuidString)")
            }
        }.foregroundStyle(importText).frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).background(importSurface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func selectionLabel(_ row: ImportCompanionPreview) -> String {
        if row.state == .skipped { return "已选择跳过" }
        if row.state == .target, let id = row.selectedAudioID,
           let target = row.choices.first(where: { $0.id == id }) { return "关联到：" + target.title }
        return "请选择资料目标或跳过"
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("本次处理结果").font(.title2).foregroundStyle(importText)
            ForEach(coordinator.results) { row in
                VStack(alignment: .leading, spacing: 5) {
                    Label(row.name, systemImage: row.state == .success ? "checkmark.circle" : row.state == .failed ? "exclamationmark.circle" : "minus.circle")
                    Text(row.message).font(.caption).foregroundStyle(importSecondary)
                }.foregroundStyle(row.state == .failed ? importWarning : importText)
            }
            Button("再添加一批") { Task { await coordinator.reset() } }
                .accessibilityIdentifier("import.another-batch")
        }.accessibilityIdentifier("import.summary")
    }
}
