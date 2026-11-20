import SwiftUI

@MainActor
struct SongMemoriesView: View {
    let memories: [SongMemory]
    let images: [String: UIImage]
    let onSave: (SongMemory, Data?) async -> Bool
    let onClose: () -> Void
    @State private var openingTrack: Track
    @State private var editing: SongMemory?

    init(track: Track, memories: [SongMemory], images: [String: UIImage],
         onSave: @escaping (SongMemory, Data?) async -> Bool, onClose: @escaping () -> Void) {
        self.memories = memories
        self.images = images
        self.onSave = onSave
        self.onClose = onClose
        // Listening can advance while this page is open. Its subject remains the song first opened.
        _openingTrack = State(initialValue: track)
    }

    private var entries: [SongMemory] {
        memories.filter { $0.trackID == openingTrack.id }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    heading
                    Button { editing = SongMemory(trackID: openingTrack.id) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus").font(.title3)
                            Text("给这首歌留一页").font(.body.weight(.medium))
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.subheadline)
                        }.padding(18).frame(minHeight: 56)
                            .foregroundStyle(CraftStyle.accent).background(CraftStyle.surface, in: RoundedRectangle(cornerRadius: 15))
                    }.buttonStyle(.plain).accessibilityIdentifier("memory.add")
                    if entries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("记忆还没有落笔").font(.title3.weight(.medium)).foregroundStyle(CraftStyle.paper)
                            Text("想记录时，再放进一句话或一张照片。\n听歌不必完成任何记录。")
                                .font(.subheadline).lineSpacing(6).foregroundStyle(CraftStyle.secondary)
                        }.padding(.vertical, 28).accessibilityIdentifier("memory.empty")
                    } else {
                        LazyVStack(spacing: 22) {
                            ForEach(entries) { memory in
                                Button { editing = memory } label: { card(memory) }.buttonStyle(.plain)
                                    .accessibilityLabel(memory.text.isEmpty ? "照片记忆" : memory.text)
                                    .accessibilityHint("打开编辑这条记忆")
                                    .accessibilityIdentifier("memory.entry." + memory.id)
                            }
                        }
                    }
                    Text("只属于这首歌，也只属于你。")
                        .font(.caption).foregroundStyle(CraftStyle.secondary).padding(.vertical, 12)
                }.padding(24).frame(maxWidth: 660).frame(maxWidth: .infinity, alignment: .center)
            }.background(CraftStyle.desk.ignoresSafeArea()).navigationTitle("歌曲记忆").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成", action: onClose).frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("memory.close")
                    }
                }
        }.preferredColorScheme(.dark).tint(CraftStyle.accent)
            .accessibilityElement(children: .contain).accessibilityIdentifier("memory.page")
            .sheet(item: $editing) { memory in
                SongMemoryEditor(track: openingTrack, initial: memory,
                    initialImage: memory.photoAsset.flatMap { images[$0] }, onSave: onSave)
            }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SONG / MEMORY").font(CraftStyle.caption(11)).tracking(3).foregroundStyle(CraftStyle.accent)
            Text(openingTrack.title).font(.system(.largeTitle, design: .serif).weight(.medium))
                .foregroundStyle(CraftStyle.paper).fixedSize(horizontal: false, vertical: true)
            Text(openingTrack.artist).font(.subheadline).foregroundStyle(CraftStyle.secondary)
            Rectangle().fill(CraftStyle.line).frame(height: 1).padding(.top, 10)
        }
    }

    private func card(_ memory: SongMemory) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if let asset = memory.photoAsset, let image = images[asset] {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 3)).accessibilityHidden(true)
            } else if memory.photoAsset != nil {
                Label("照片暂时无法读取，可打开重新选择", systemImage: "photo")
                    .font(.caption).foregroundStyle(CraftStyle.ink.opacity(0.6)).frame(minHeight: 80)
            }
            if !memory.text.isEmpty {
                Text(memory.text).font(.system(.body, design: .serif)).lineSpacing(7)
                    .foregroundStyle(CraftStyle.ink).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .firstTextBaseline) {
                if let date = memory.rememberedOn {
                    Text(date, format: .dateTime.year().month().day()).font(.caption).foregroundStyle(CraftStyle.ink.opacity(0.6))
                } else {
                    Text("未标日期").font(.caption).foregroundStyle(CraftStyle.ink.opacity(0.5))
                }
                Spacer(minLength: 8)
                Image(systemName: "pencil.line").font(.subheadline).foregroundStyle(CraftStyle.ink.opacity(0.65))
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(CraftStyle.paper, in: RoundedRectangle(cornerRadius: 5))
    }
}

@MainActor
private struct SongMemoryEditor: View {
    let track: Track
    let initial: SongMemory
    let initialImage: UIImage?
    let onSave: (SongMemory, Data?) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SongMemory
    @State private var includeDate: Bool
    @State private var chosenDate: Date
    @State private var photoJPEG: Data?
    @State private var photoPreview: UIImage?
    @State private var saving = false
    @State private var choosingPhoto = false
    @State private var errorMessage: String?
    @State private var discardConfirmation = false
    @State private var saveTask: Task<Void, Never>?

    init(track: Track, initial: SongMemory, initialImage: UIImage?,
         onSave: @escaping (SongMemory, Data?) async -> Bool) {
        self.track = track
        self.initial = initial
        self.initialImage = initialImage
        self.onSave = onSave
        _draft = State(initialValue: initial)
        _includeDate = State(initialValue: initial.rememberedOn != nil)
        _chosenDate = State(initialValue: initial.rememberedOn ?? Date())
    }

    private var shownImage: UIImage? { photoPreview ?? (draft.photoAsset == nil ? nil : initialImage) }
    private var canSave: Bool {
        !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || photoJPEG != nil || draft.photoAsset != nil
    }
    private var hasChanges: Bool {
        draft.text != initial.text || draft.photoAsset != initial.photoAsset || photoJPEG != nil ||
            includeDate != (initial.rememberedOn != nil) || (includeDate && chosenDate != initial.rememberedOn)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FOR THIS SONG").font(CraftStyle.caption(10)).tracking(2).foregroundStyle(CraftStyle.accent)
                        Text(track.title).font(.title2.weight(.medium)).foregroundStyle(CraftStyle.paper)
                        Text(track.artist).font(.subheadline).foregroundStyle(CraftStyle.secondary)
                    }
                    writingPaper
                    photoSection
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("为记忆标一个日期", isOn: $includeDate).font(.subheadline)
                            .accessibilityIdentifier("memory.date.enabled")
                        if includeDate {
                            DatePicker("记忆日期", selection: $chosenDate, displayedComponents: .date)
                                .accessibilityIdentifier("memory.date")
                        }
                        Text("日期由你选择，不会从播放或照片信息推断。")
                            .font(.caption).foregroundStyle(CraftStyle.secondary)
                    }.padding(18).background(CraftStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                    if let errorMessage {
                        Text(errorMessage).font(.callout).foregroundStyle(.red).accessibilityIdentifier("memory.error")
                    }
                    Text("保存后可再次打开修改。")
                        .font(.caption).foregroundStyle(CraftStyle.secondary).padding(.bottom, 12)
                }.padding(24).frame(maxWidth: 660).frame(maxWidth: .infinity)
            }.disabled(saving).background(CraftStyle.desk.ignoresSafeArea()).navigationTitle("留一页").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消", action: cancel).disabled(saving).frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("memory.cancel")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: save) {
                            if saving { ProgressView() } else { Text("保存").fontWeight(.semibold) }
                        }.disabled(saving || choosingPhoto || !canSave).frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("memory.save")
                    }
                }
        }.preferredColorScheme(.dark).tint(CraftStyle.accent)
            .interactiveDismissDisabled(saving || hasChanges)
            .accessibilityElement(children: .contain).accessibilityIdentifier("memory.editor")
            .confirmationDialog("放弃未保存的修改？", isPresented: $discardConfirmation, titleVisibility: .visible) {
                Button("放弃修改", role: .destructive) { dismiss() }.accessibilityIdentifier("memory.discard")
                Button("继续编辑", role: .cancel) { }
            }
            .onDisappear { saveTask?.cancel(); saveTask = nil }
    }

    private var writingPaper: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("想留下的话").font(.caption.weight(.medium)).foregroundStyle(CraftStyle.ink.opacity(0.6))
            TextEditor(text: $draft.text).font(.system(.body, design: .serif)).lineSpacing(6)
                .frame(minHeight: 180).scrollContentBackground(.hidden)
                .foregroundStyle(CraftStyle.ink).tint(CraftStyle.ink)
                .accessibilityLabel("记忆文字").accessibilityIdentifier("memory.text")
                .onChange(of: draft.text) { _, value in
                    if value.count > 2_000 { draft.text = String(value.prefix(2_000)) }
                }
            HStack {
                Text("一句话或一张照片，都可以。").font(.caption)
                Spacer(minLength: 8)
                Text("\(draft.text.count) / 2000").font(CraftStyle.caption(10))
            }.foregroundStyle(CraftStyle.ink.opacity(0.55))
        }.padding(18).background(CraftStyle.paper, in: RoundedRectangle(cornerRadius: 5))
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let image = shownImage {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 5)).accessibilityLabel("记忆照片")
            } else if draft.photoAsset != nil {
                Text("原照片暂时无法读取，可以重新选择；不更换也能保留这条记忆。")
                    .font(.caption).foregroundStyle(CraftStyle.secondary)
            }
            CraftPhotoButton(title: shownImage == nil ? "放入一张照片" : "更换照片", identifier: "memory.photo",
                             onBusyChange: { choosingPhoto = $0 }) { data, image in
                photoJPEG = data; photoPreview = image; errorMessage = nil
            }
            if photoJPEG != nil || draft.photoAsset != nil {
                Button(role: .destructive) {
                    photoJPEG = nil; photoPreview = nil; draft.photoAsset = nil
                } label: { Text("移除照片").font(.subheadline).frame(minHeight: 44) }
                    .accessibilityIdentifier("memory.photo.remove")
            }
        }.disabled(saving)
    }

    private func cancel() {
        if hasChanges { discardConfirmation = true } else { dismiss() }
    }

    private func save() {
        guard !saving, canSave else { return }
        var value = draft
        value.text = value.text.trimmingCharacters(in: .whitespacesAndNewlines)
        value.rememberedOn = includeDate ? chosenDate : nil
        value.updatedAt = Date()
        // The editor's track identity is captured on opening. Playback cannot retarget this commit.
        value.trackID = track.id
        saving = true; errorMessage = nil
        let image = photoJPEG
        saveTask = Task { @MainActor in
            defer { saving = false; saveTask = nil }
            let saved = await onSave(value, image)
            guard !Task.isCancelled else { return }
            if saved { dismiss() }
            else { errorMessage = "这页暂时没有保存成功，文字和照片仍在这里，可以重试。" }
        }
    }
}
