import SwiftUI

/// Editor state is a local value draft. Only the awaited save callback may commit it or start audio.
struct CraftedRecordComposer: View {
    let tracks: [Track]
    let artworks: [String: UIImage]
    let existingCover: UIImage?
    let onSave: (CraftedRecord, Data?, Bool) async -> Bool
    let onClose: () -> Void
    private let original: CraftedRecord
    @State private var draft: CraftedRecord
    @State private var step = 0
    @State private var photoJPEG: Data?
    @State private var photo: UIImage?
    @State private var saving = false
    @State private var photoBusy = false
    @State private var saveFailed = false
    @State private var showingExit = false
    @State private var coverFieldFocused = false

    init(record: CraftedRecord = CraftedRecord(), tracks: [Track], artworks: [String: UIImage], existingCover: UIImage? = nil,
         onSave: @escaping (CraftedRecord, Data?, Bool) async -> Bool, onClose: @escaping () -> Void) {
        original = record; self.tracks = tracks; self.artworks = artworks; self.existingCover = existingCover
        self.onSave = onSave; self.onClose = onClose; _draft = State(initialValue: record)
    }

    private var locked: Bool { saving || photoBusy }
    private var modified: Bool { draft != original || photoJPEG != nil }
    private var validReady: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !draft.sideA.isEmpty && draft.allTrackIDs.count <= 40 &&
            (draft.design != .photo || photo != nil || existingCover != nil)
    }
    private var missingTracks: Bool { draft.allTrackIDs.contains { id in !tracks.contains(where: { $0.id == id }) } }

    var body: some View {
        VStack(spacing: 0) {
            header
            stages.padding(.horizontal, 24).padding(.bottom, 23)
            Group {
                switch step {
                case 0: CraftTrackSelection(record: $draft, tracks: tracks, artworks: artworks)
                case 1: CraftTrackArrangement(record: $draft, tracks: tracks, artworks: artworks)
                default:
                    CraftCoverEditor(record: $draft, image: photo ?? existingCover,
                                     onPhotoBusyChange: { photoBusy = $0 }, onFocusChange: { coverFieldFocused = $0 }) { data, image in
                        photoJPEG = data; photo = image
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(!saving)
        }.background(CraftStyle.desk.ignoresSafeArea()).preferredColorScheme(.dark)
            .interactiveDismissDisabled(modified || locked)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // The keyboard already consumes the lower safe area. Keeping the large production
                // controls above it squeezes the form and can cover the very field being edited.
                if !coverFieldFocused { footer }
            }
            .accessibilityElement(children: .contain).accessibilityIdentifier("craft.composer")
            .confirmationDialog("将这次制作留在工作台？", isPresented: $showingExit, titleVisibility: .visible) {
                Button(original.isDraft ? "保存草稿后离开" : "保存修改后离开") { save(asDraft: original.isDraft, start: false) }
                    .disabled(locked || (!original.isDraft && !validReady))
                Button("放弃本次修改", role: .destructive) { if !locked { onClose() } }
                Button("继续制作", role: .cancel) {}
            } message: { Text("只有保存成功，唱片柜才会更新。") }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("STILLROOM / PRIVATE PRESS").font(CraftStyle.caption(9)).tracking(1.7).foregroundStyle(CraftStyle.secondary)
                Text(original.isDraft ? "制作一张唱片" : "重新编排").font(.headline).foregroundStyle(CraftStyle.paper)
            }
            Spacer(minLength: 8)
            CraftCloseButton(label: "离开制作") { if modified { showingExit = true } else { onClose() } }
                .disabled(locked).accessibilityIdentifier("craft.composer.close")
        }.padding(.horizontal, 24).padding(.top, 15).padding(.bottom, 20)
    }

    private var stages: some View {
        HStack(spacing: 0) {
            ForEach(Array(["选曲", "双面", "封套"].enumerated()), id: \.offset) { index, label in
                Button {
                    guard index <= step || !draft.allTrackIDs.isEmpty else { return }
                    step = index
                } label: {
                    HStack(spacing: 7) {
                        Text(String(format: "%02d", index + 1)).font(CraftStyle.caption(11))
                        Text(label).font(.system(size: 12, weight: index == step ? .semibold : .regular))
                        if index < 2 { Rectangle().fill(index < step ? CraftStyle.paper.opacity(0.6) : CraftStyle.line).frame(height: 0.7).padding(.horizontal, 9) }
                    }.foregroundStyle(index == step ? CraftStyle.paper : CraftStyle.secondary).frame(minHeight: 34)
                }.buttonStyle(.plain).accessibilityIdentifier("craft.composer.step.\(index)")
                    .disabled(locked || (index > step && draft.allTrackIDs.isEmpty))
                    .accessibilityAddTraits(index == step ? .isSelected : [])
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if saveFailed {
                Text("保存未完成，请重试。当前编辑仍留在这里。")
                    .font(.footnote).foregroundStyle(CraftStyle.accent).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("craft.composer.saveError")
            }
            if step < 2 {
                HStack {
                    Button(original.isDraft ? "存为草稿" : "保存修改") { save(asDraft: original.isDraft, start: false) }
                        .font(.footnote).foregroundStyle(CraftStyle.secondary).frame(minHeight: 44)
                        .disabled(locked || (!original.isDraft && !validReady)).accessibilityIdentifier("craft.composer.saveDraft")
                    Spacer()
                    Text(CraftStyle.duration(draft.allTrackIDs, tracks: tracks)).font(CraftStyle.caption(11)).foregroundStyle(CraftStyle.secondary)
                }
                CraftPrimaryButton(title: step == 0 ? "继续编排双面" : "开始制作封套",
                                   enabled: !locked && (step == 0 ? !draft.allTrackIDs.isEmpty : !draft.sideA.isEmpty)) { step += 1 }
                    .accessibilityIdentifier("craft.composer.next")
                if step == 1 && draft.sideA.isEmpty { Text("A 面至少需要一首歌，才能开始制作封套。")
                    .font(.footnote).foregroundStyle(CraftStyle.secondary) }
            } else {
                if !validReady {
                    Text(draft.sideA.isEmpty ? "请先在 A 面放入一首歌。" : draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                         "先为这张唱片写下名字。" : "给照片封套加入一张照片，或换一种构图。")
                        .font(.footnote).foregroundStyle(CraftStyle.secondary)
                } else if missingTracks {
                    Text("有歌曲暂不可用；可以先保存，再补齐原曲后播放。")
                        .font(.footnote).foregroundStyle(CraftStyle.secondary)
                }
                HStack(spacing: 16) {
                    if original.isDraft {
                        Button("存为草稿") { save(asDraft: true, start: false) }.accessibilityIdentifier("craft.composer.saveDraft")
                    }
                    Spacer()
                    Button(original.isDraft ? "只保存唱片" : "保存修改") { save(asDraft: false, start: false) }
                        .disabled(!validReady).accessibilityIdentifier("craft.composer.saveReady")
                }.font(.footnote).foregroundStyle(CraftStyle.secondary).frame(minHeight: 32).disabled(locked)
                CraftPrimaryButton(title: saving ? "正在压制这张唱片…" : original.isDraft ? "制作完成并落针" : "保存并落针", symbol: "play.fill",
                                   enabled: !locked && validReady && !missingTracks) { save(asDraft: false, start: true) }
                    .accessibilityIdentifier("craft.composer.play")
            }
        }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 12)
            .background(CraftStyle.desk.opacity(0.98).overlay(alignment: .top) { Rectangle().fill(CraftStyle.line).frame(height: 0.5) })
    }

    private func save(asDraft: Bool, start: Bool) {
        // A selected iCloud photo is not part of this value draft until its crop has finished.
        guard !locked else { return }
        var value = draft
        value.isDraft = asDraft
        if asDraft { value.collectedAt = nil; value.completedAt = nil }
        saving = true; saveFailed = false
        Task {
            let success = await onSave(value, photoJPEG, start)
            saving = false
            if success { onClose() } else { saveFailed = true }
        }
    }
}
