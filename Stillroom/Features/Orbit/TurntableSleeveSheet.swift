import SwiftUI

/// A sleeve belongs to the album/edition captured when opened. Playback may continue underneath;
/// callbacks carry the selected song or edition rather than retargeting the current player item.
struct TurntableSleeveSheet: View {
    let record: CraftedRecord?
    let album: Track
    let cover: UIImage?
    let tracks: [Track]
    let memories: [SongMemory]
    let images: [String: UIImage]
    let currentID: String
    let playing: Bool
    let isOnTurntable: Bool
    let collected: Bool
    let busy: Bool
    var onPlay: () -> Void
    var onMemory: (Track) -> Void
    var onEdit: (CraftedRecord) -> Void
    var onCollect: () async -> Bool
    var onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var back = false
    @State private var collecting = false
    @State private var collectionConfirmed = false
    @State private var collectionError: String?
    @State private var collectionTask: Task<Void, Never>?

    private var title: String { record?.title ?? album.album }
    private var allIDs: [String] { record?.allTrackIDs ?? tracks.map(\.id) }
    private var isCollected: Bool { collected || collectionConfirmed }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    coverSection
                    if let record, !record.dedication.isEmpty {
                        Text(record.dedication).font(.body).lineSpacing(5)
                            .foregroundStyle(SleeveSheetStyle.secondary)
                            .textSelection(.enabled)
                    }
                    if let record {
                        ForEach(CraftedSide.allCases) { side in
                            trackSection(ids: record.trackIDs(on: side), label: side.label)
                        }
                    } else {
                        trackSection(ids: allIDs, label: "曲目")
                    }
                    if let collectionError {
                        Text(collectionError).font(.callout).foregroundStyle(.red)
                            .accessibilityIdentifier("sleeve.error")
                    }
                    if record != nil { collectionButton }
                }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(SleeveSheetStyle.background.ignoresSafeArea())
            .navigationTitle("封套与记忆").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成", action: onClose).frame(minWidth: 44, minHeight: 44)
                        .disabled(collecting).accessibilityIdentifier("sleeve.close")
                }
                if let record {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { onEdit(record) } label: {
                            Image(systemName: "pencil").frame(width: 44, height: 44)
                        }.disabled(busy || collecting).accessibilityLabel("编辑这张唱片")
                            .accessibilityIdentifier("sleeve.edit")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { playBar }
        }
        .preferredColorScheme(.light).tint(SleeveSheetStyle.ink)
        .presentationDragIndicator(.visible).presentationCornerRadius(28)
        .interactiveDismissDisabled(collecting)
        .accessibilityElement(children: .contain).accessibilityIdentifier("sleeve.page")
        .onDisappear { collectionTask?.cancel(); collectionTask = nil }
    }

    private var coverSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let record {
                Button(action: flipCover) {
                    CraftedSleeveFlipView(record: record, image: cover, angle: back ? 180 : 0)
                        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 12)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                }.buttonStyle(.plain).accessibilityLabel(back ? "翻到封套正面" : "翻到封套背面")
                    .accessibilityValue(back ? "背面" : "正面")
                    .accessibilityIdentifier("sleeve.flip")
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.caption)
                    Text(back ? "封套背面 · 轻点翻回" : "封套正面 · 轻点翻面").font(.caption)
                    Spacer(minLength: 8)
                    if isCollected { Label("已收藏", systemImage: "checkmark.circle.fill").font(.caption) }
                }.foregroundStyle(SleeveSheetStyle.secondary)
            } else {
                ArtworkView(track: album, image: cover)
                    .aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 3))
                    .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 12)
                    .padding(.horizontal, 18).padding(.vertical, 10)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("sleeve.title")
                Text(record == nil ? album.artist : "自制唱片 · \(allIDs.count) 首")
                    .font(.subheadline).foregroundStyle(SleeveSheetStyle.secondary)
            }
        }
    }

    private func trackSection(ids: [String], label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(CraftStyle.duration(ids, tracks: tracks)).font(.caption)
                    .foregroundStyle(SleeveSheetStyle.secondary)
            }.padding(.bottom, 4)
            if ids.isEmpty {
                Text("这一面没有歌曲").font(.subheadline).foregroundStyle(SleeveSheetStyle.secondary)
                    .padding(.vertical, 12)
            }
            ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                if let track = tracks.first(where: { $0.id == id }) {
                    songRow(track, number: index + 1)
                } else {
                    HStack(spacing: 12) {
                        Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit())
                        Label("歌曲暂不可用", systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                        Spacer(minLength: 0)
                    }.foregroundStyle(SleeveSheetStyle.secondary).padding(.vertical, 14)
                }
            }
        }
    }

    private func songRow(_ track: Track, number: Int) -> some View {
        let memory = memories.filter { $0.trackID == track.id }.max { $0.updatedAt < $1.updatedAt }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    if isOnTurntable && currentID == track.id && playing { Image(systemName: "waveform").font(.caption) }
                    else { Text(String(format: "%02d", number)).font(.caption.monospacedDigit()) }
                }.frame(width: 24).foregroundStyle(SleeveSheetStyle.secondary).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    Text(track.artist).font(.caption).foregroundStyle(SleeveSheetStyle.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button { onMemory(track) } label: {
                    Image(systemName: memory == nil ? "square.and.pencil" : "book.closed")
                        .font(.body).frame(width: 44, height: 44)
                }.buttonStyle(.plain).disabled(busy || collecting)
                    .accessibilityLabel((memory == nil ? "记下这首，" : "查看歌曲记忆，") + track.title)
                    .accessibilityIdentifier("sleeve.memory." + track.id)
            }
            if let memory { memoryPreview(memory).padding(.leading, 36).padding(.trailing, 6) }
            Divider().overlay(SleeveSheetStyle.rule).padding(.leading, 36)
        }.padding(.top, 4)
    }

    private func memoryPreview(_ memory: SongMemory) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let asset = memory.photoAsset, let image = images[asset] {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 3)).accessibilityLabel("记忆照片")
            }
            VStack(alignment: .leading, spacing: 4) {
                if !memory.text.isEmpty {
                    Text(memory.text).font(.caption).lineSpacing(3).lineLimit(3)
                } else if memory.photoAsset != nil {
                    Text("一张照片记忆").font(.caption)
                }
                if let date = memory.rememberedOn {
                    Text(date, format: .dateTime.year().month().day())
                        .font(.caption2).foregroundStyle(SleeveSheetStyle.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.foregroundStyle(SleeveSheetStyle.secondary).padding(12)
            .background(SleeveSheetStyle.paper, in: RoundedRectangle(cornerRadius: 7))
    }

    private var collectionButton: some View {
        Button(action: collect) {
            HStack(spacing: 10) {
                if collecting { ProgressView() }
                else { Image(systemName: isCollected ? "checkmark.circle.fill" : "square.stack") }
                Text(isCollected ? "已收进唱片柜" : "收藏这张唱片").font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
            }.frame(minHeight: 44).padding(.horizontal, 16)
                .background(SleeveSheetStyle.paper, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).disabled(busy || collecting || isCollected)
            .accessibilityIdentifier("sleeve.collect")
    }

    private var playBar: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                Image(systemName: isOnTurntable ? "opticaldisc" : "play.fill")
                Text(isOnTurntable ? "回到唱机" : "放上唱机").font(.body.weight(.semibold))
                Spacer(minLength: 12)
                Image(systemName: "arrow.up.right").font(.subheadline)
            }.padding(.horizontal, 20).frame(minHeight: 52)
                .foregroundStyle(.white).background(SleeveSheetStyle.ink, in: Capsule())
        }.buttonStyle(.plain).disabled(collecting || allIDs.isEmpty)
            .accessibilityIdentifier("sleeve.play").padding(.horizontal, 24).padding(.vertical, 14)
            .background(.ultraThinMaterial)
    }

    private func flipCover() {
        withAnimation(reducedMotion ? nil : .easeInOut(duration: 0.42)) { back.toggle() }
    }

    private func collect() {
        guard record != nil, !busy, !collecting, !isCollected else { return }
        collecting = true
        collectionError = nil
        collectionTask = Task { @MainActor in
            let saved = await onCollect()
            guard !Task.isCancelled else { return }
            collecting = false
            collectionTask = nil
            // The stamp confirms the archive commit, never just the button press or animation.
            if saved { collectionConfirmed = true }
            else { collectionError = "这张唱片暂时没有收藏成功，请重试。" }
        }
    }
}

private enum SleeveSheetStyle {
    static let background = Color(hex: 0xE4E4E2)
    static let paper = Color(hex: 0xF3F2ED)
    static let ink = Color(hex: 0x262728)
    static let secondary = Color(hex: 0x696A6B)
    static let rule = Color.black.opacity(0.08)
}
