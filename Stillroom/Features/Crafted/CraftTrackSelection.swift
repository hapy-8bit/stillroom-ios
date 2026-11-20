import SwiftUI

struct CraftTrackSelection: View {
    @Binding var record: CraftedRecord
    let tracks: [Track]
    let artworks: [String: UIImage]
    @State private var side: CraftedSide = .a
    @State private var query = ""
    @State private var limitNotice = false

    private var matches: [Track] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty ? tracks : tracks.filter { ($0.title + $0.artist + $0.album).lowercased().contains(value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            VStack(alignment: .leading, spacing: 9) {
                Text("先选几首，\n留给这一张。")
                    .font(.system(.title, design: .serif).weight(.semibold)).foregroundStyle(CraftStyle.paper)
                Text("轻点歌曲放入当前一面，下一步再调整顺序。")
                    .font(.footnote).foregroundStyle(CraftStyle.secondary)
            }.padding(.horizontal, 24)
            CraftSidePicker(selected: $side, sideA: record.sideA.count, sideB: record.sideB.count).padding(.horizontal, 24)
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(CraftStyle.secondary)
                TextField("找歌曲、歌手或专辑", text: $query).font(.subheadline).foregroundStyle(CraftStyle.paper)
                    .autocorrectionDisabled().submitLabel(.search).accessibilityIdentifier("craft.select.search")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(CraftStyle.secondary) }
                        .buttonStyle(.plain).accessibilityLabel("清空搜索")
                }
            }.padding(13).background(CraftStyle.surface, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 24)
            if limitNotice {
                Text("一张唱片最多放 40 首。可以先移出一首，再继续选择。")
                    .font(.footnote).foregroundStyle(CraftStyle.accent).padding(.horizontal, 24)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(matches) { track in row(track) }
                    if matches.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note").font(.system(size: 26, weight: .light))
                            Text(tracks.isEmpty ? "先把音乐放入本机曲库，再回来选曲。" : "没有找到这首歌，试试另一个名字。")
                                .font(.subheadline).multilineTextAlignment(.center)
                        }.foregroundStyle(CraftStyle.secondary).padding(.vertical, 45).frame(maxWidth: .infinity)
                    }
                }.padding(.horizontal, 24).padding(.bottom, 20)
            }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("craft.step.select")
    }

    private func selectionLabel(_ id: String) -> String? {
        if let index = record.sideA.firstIndex(of: id) { return String(format: "A%02d", index + 1) }
        if let index = record.sideB.firstIndex(of: id) { return String(format: "B%02d", index + 1) }
        return nil
    }

    private func row(_ track: Track) -> some View {
        let selected = selectionLabel(track.id)
        let currentSide = record.trackIDs(on: side).contains(track.id)
        return Button { select(track.id) } label: {
            HStack(spacing: 13) {
                ArtworkView(track: track, image: artworks[track.id]).frame(width: 46, height: 46)
                    .clipShape(Circle()).overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 0.6))
                VStack(alignment: .leading, spacing: 5) {
                    Text(track.title).font(.body.weight(.medium)).foregroundStyle(CraftStyle.paper).lineLimit(2)
                    Text(track.artist).font(.caption).foregroundStyle(CraftStyle.secondary).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if let selected {
                    Text(selected).font(CraftStyle.caption(11)).foregroundStyle(currentSide ? CraftStyle.desk : CraftStyle.paper)
                        .frame(width: 42, height: 32)
                        .background(currentSide ? CraftStyle.accent : CraftStyle.surface, in: Capsule())
                } else {
                    Image(systemName: "plus").font(.system(size: 16, weight: .light)).foregroundStyle(CraftStyle.secondary)
                        .frame(width: 42, height: 42)
                }
            }.padding(.vertical, 12).contentShape(Rectangle())
                .overlay(alignment: .bottom) { Rectangle().fill(CraftStyle.line).frame(height: 0.5) }
        }.buttonStyle(.plain).accessibilityIdentifier("craft.select.track." + track.id)
            .accessibilityLabel(track.title + "，" + track.artist + "，" + (currentSide ? "从" + side.label + "移出" : selected != nil ? "移到" + side.label : "加入" + side.label))
    }

    private func select(_ id: String) {
        if record.trackIDs(on: side).contains(id) {
            if side == .a { record.sideA.removeAll { $0 == id } } else { record.sideB.removeAll { $0 == id } }
            limitNotice = false
            return
        }
        guard record.allTrackIDs.contains(id) || record.allTrackIDs.count < 40 else { limitNotice = true; return }
        record.sideA.removeAll { $0 == id }; record.sideB.removeAll { $0 == id }
        if side == .a { record.sideA.append(id) } else { record.sideB.append(id) }
        limitNotice = false
    }
}

struct CraftTrackArrangement: View {
    @Binding var record: CraftedRecord
    let tracks: [Track]
    let artworks: [String: UIImage]
    @State private var side: CraftedSide = .a

    private var ids: [String] { record.trackIDs(on: side) }
    private var other: CraftedSide { side == .a ? .b : .a }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 9) {
                Text("一面开场，\n一面余韵。")
                    .font(.system(.title, design: .serif).weight(.semibold)).foregroundStyle(CraftStyle.paper)
                Text("拖动右侧曲序把手排列；菜单可移动到另一面。")
                    .font(.footnote).foregroundStyle(CraftStyle.secondary)
            }.padding(.horizontal, 24)
            CraftSidePicker(selected: $side, sideA: record.sideA.count, sideB: record.sideB.count).padding(.horizontal, 24)
            HStack {
                Text(CraftStyle.duration(ids, tracks: tracks))
                Spacer()
                Text(side == .a ? "A SIDE" : "B SIDE")
            }.font(CraftStyle.caption(11)).foregroundStyle(CraftStyle.secondary).padding(.horizontal, 28)
            if ids.isEmpty {
                VStack(spacing: 12) {
                    Text(side.label).font(.system(size: 64, weight: .ultraLight, design: .serif)).foregroundStyle(CraftStyle.paper.opacity(0.3))
                    Text(side == .a ? "A 面至少放入一首歌。" : "B 面可以留空，也可以放入下一段心情。")
                        .font(.footnote).foregroundStyle(CraftStyle.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
            } else {
                List {
                    ForEach(ids, id: \.self) { id in arrangementRow(id) }
                        .onMove { offsets, destination in
                            var moved = ids; moved.move(fromOffsets: offsets, toOffset: destination); replace(moved)
                        }
                        .onDelete { offsets in var remaining = ids; remaining.remove(atOffsets: offsets); replace(remaining) }
                }.listStyle(.plain).scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(.active))
                    .tint(CraftStyle.secondary).accessibilityIdentifier("craft.arrange.list")
            }
            if !record.sideB.isEmpty {
                Toggle(isOn: $record.manualFlip) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("亲手翻到 B 面").font(.subheadline.weight(.medium)).foregroundStyle(CraftStyle.paper)
                        Text(record.manualFlip ? "A 面结束后收针，等你翻面继续。" : "A 面结束后，连续播放 B 面。")
                            .font(.caption).foregroundStyle(CraftStyle.secondary)
                    }
                }.tint(CraftStyle.accent).padding(.horizontal, 24).padding(.bottom, 8).accessibilityIdentifier("craft.arrange.manualFlip")
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("craft.step.arrange")
    }

    private func arrangementRow(_ id: String) -> some View {
        let track = tracks.first { $0.id == id }
        let index = ids.firstIndex(of: id) ?? 0
        return HStack(spacing: 11) {
            Text(String(format: "%02d", index + 1)).font(CraftStyle.caption(12)).foregroundStyle(CraftStyle.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                Text(track?.title ?? "原曲暂不可用").font(.subheadline.weight(.medium)).foregroundStyle(CraftStyle.paper)
                Text(track?.artist ?? "重新导入原曲，或从本张唱片移出。")
                    .font(.caption).foregroundStyle(CraftStyle.secondary).lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button("移到" + other.label, systemImage: "arrow.left.arrow.right") { moveAcross(id) }
                Button("向前一首", systemImage: "arrow.up") { move(id, delta: -1) }.disabled(index == 0)
                Button("向后一首", systemImage: "arrow.down") { move(id, delta: 1) }.disabled(index == ids.count - 1)
                Button("移出这张唱片", systemImage: "minus.circle", role: .destructive) { replace(ids.filter { $0 != id }) }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 16)).frame(width: 44, height: 44).foregroundStyle(CraftStyle.secondary)
            }.accessibilityLabel("\(track?.title ?? "未找到歌曲")的曲序操作").accessibilityIdentifier("craft.arrange.track." + id)
        }.padding(.vertical, 8).listRowBackground(Color.clear).listRowSeparatorTint(CraftStyle.line)
    }

    private func replace(_ values: [String]) { if side == .a { record.sideA = values } else { record.sideB = values } }
    private func moveAcross(_ id: String) {
        replace(ids.filter { $0 != id })
        if other == .a { record.sideA.append(id) } else { record.sideB.append(id) }
    }
    private func move(_ id: String, delta: Int) {
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + delta) else { return }
        var moved = ids; moved.swapAt(index, index + delta); replace(moved)
    }
}
