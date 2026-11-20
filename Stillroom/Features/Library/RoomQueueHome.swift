import SwiftUI

/// A persistent queue destination using this product's native list presentation.
/// The reference's populated queue was not observed; rows and modes come only from the caller.
struct RoomQueueHome: View {
    let tracks: [Track]
    let queue: PlaybackQueue
    let title: String
    let currentID: String
    let playing: Bool
    let onSelect: (Track) -> Void
    let onShuffle: () -> Void
    let onRepeat: (RepeatMode) -> Void

    private var queuedTracks: [Track] {
        // Preserve the authoritative queue order and skip unresolved IDs without repairing
        // its state here. First-wins lookup also avoids trapping on a malformed duplicate track.
        var byID: [String: Track] = [:]
        for track in tracks where byID[track.id] == nil { byID[track.id] = track }
        return queue.ids.compactMap { byID[$0] }
    }

    var body: some View {
        let items = queuedTracks
        return NavigationStack {
            ZStack {
                RoomBackground()
                List {
                    Section {
                        if items.isEmpty {
                            emptyQueue
                        } else {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, track in
                                queueRow(track, ordinal: index + 1)
                            }
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(title.isEmpty ? "当前队列" : title)
                                .font(.headline).foregroundStyle(RoomStyle.paper)
                            Text("\(items.count) 首音乐")
                                .font(.caption).foregroundStyle(RoomStyle.secondary)
                        }.textCase(nil).padding(.bottom, 8)
                    }
                    Section("播放方式") {
                        shuffleControl
                        ForEach(RepeatMode.allCases, id: \.rawValue) { mode in
                            repeatControl(mode)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .listRowSeparatorTint(RoomStyle.muted.opacity(0.22))
            }
            .navigationTitle("待播放")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("room.queue")
    }

    private var emptyQueue: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet")
                .font(.system(size: 30, weight: .light)).accessibilityHidden(true)
            Text("队列里还没有音乐").font(.headline)
            Text("在资料库中选择音乐后，播放顺序会显示在这里。")
                .font(.subheadline).foregroundStyle(RoomStyle.secondary)
                .multilineTextAlignment(.center)
        }.foregroundStyle(RoomStyle.paper)
            .frame(maxWidth: .infinity).padding(.vertical, 24)
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("room.queue.empty")
    }

    private func queueRow(_ track: Track, ordinal: Int) -> some View {
        let current = track.id == currentID
        let metadata: String = [track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · ")
        let spokenTitle: String = [track.title, track.artist, track.album].filter { !$0.isEmpty }.joined(separator: "，")
        let spokenState: String = current ? (playing ? "当前歌曲，正在播放" : "当前歌曲，已暂停") : "第 \(ordinal) 首"
        return Button { onSelect(track) } label: {
            HStack(spacing: 12) {
                Group {
                    if current {
                        Image(systemName: playing ? "waveform" : "pause.fill")
                    } else {
                        Text("\(ordinal)").monospacedDigit()
                    }
                }.font(.caption).frame(width: 26).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(track.title).font(.body.weight(.medium)).lineLimit(2)
                    Text(metadata)
                        .font(.caption).foregroundStyle(RoomStyle.secondary).lineLimit(2)
                }
                Spacer(minLength: 8)
                if track.duration.isFinite, track.duration > 0 {
                    Text(MediaTime.label(track.duration)).font(.caption).monospacedDigit()
                        .foregroundStyle(RoomStyle.muted)
                }
            }.foregroundStyle(current ? RoomStyle.accent : RoomStyle.paper)
                .frame(minHeight: 52).padding(.vertical, 4).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(current ? RoomStyle.surface : Color.clear)
        .accessibilityLabel(spokenTitle)
        .accessibilityValue(spokenState)
        .accessibilityHint("播放这首歌曲")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(current ? .isSelected : [])
        .accessibilityIdentifier("room.queue.track." + track.id)
    }

    private var shuffleControl: some View {
        Button(action: onShuffle) {
            HStack {
                Label("随机播放", systemImage: "shuffle")
                Spacer()
                Text(queue.shuffled ? "已开启" : "已关闭").foregroundStyle(RoomStyle.secondary)
            }.frame(minHeight: 44).foregroundStyle(RoomStyle.paper)
        }.listRowBackground(Color.clear)
            .accessibilityLabel("随机播放")
            .accessibilityValue(queue.shuffled ? "已开启" : "已关闭")
            .accessibilityHint(queue.shuffled ? "关闭随机播放" : "开启随机播放")
            .accessibilityIdentifier("room.queue.shuffle")
    }

    private func repeatControl(_ mode: RepeatMode) -> some View {
        let selected = queue.repeatMode == mode
        return Button { onRepeat(mode) } label: {
            HStack {
                Label(mode.label, systemImage: mode == .off ? "arrow.right" : mode.symbol)
                Spacer()
                if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }.frame(minHeight: 44).foregroundStyle(selected ? RoomStyle.accent : RoomStyle.secondary)
        }.listRowBackground(Color.clear)
            .accessibilityLabel(mode.label)
            .accessibilityValue(selected ? "已选择" : "未选择")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("room.queue.repeat." + mode.rawValue)
    }
}
