import SwiftUI

/// Ready, collected and unfinished records are separate shelves over the same persisted record IDs.
struct CraftedCabinetView: View {
    let records: [CraftedRecord]
    let images: [String: UIImage]
    let tracks: [Track]
    let onCreate: () -> Void
    let onOpen: (CraftedRecord) -> Void
    let onEdit: (CraftedRecord) -> Void
    let onClose: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicType

    private var collected: [CraftedRecord] { records.filter { !$0.isDraft && $0.collectedAt != nil }.sorted { ($0.collectedAt ?? .distantPast) > ($1.collectedAt ?? .distantPast) } }
    private var ready: [CraftedRecord] { records.filter { !$0.isDraft && $0.collectedAt == nil }.sorted { $0.updatedAt > $1.updatedAt } }
    private var drafts: [CraftedRecord] { records.filter(\.isDraft).sorted { $0.updatedAt > $1.updatedAt } }
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 20), count: dynamicType.isAccessibilitySize ? 1 : 2) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("STILLROOM / PRIVATE PRESS").font(CraftStyle.caption(9)).tracking(1.5).foregroundStyle(CraftStyle.secondary)
                Spacer(minLength: 8)
                CraftCloseButton(action: onClose).accessibilityIdentifier("craft.cabinet.close")
            }.padding(.horizontal, 24).padding(.top, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    introduction
                    if records.isEmpty { emptyDesk }
                    if !ready.isEmpty { shelf("桌边唱片", subtitle: "已经做好，还留在手边。", records: ready) }
                    if !collected.isEmpty { shelf("唱片柜", subtitle: "留下自己制作的唱片。", records: collected) }
                    if !drafts.isEmpty { workbench }
                }.padding(.horizontal, 24).padding(.top, 17).padding(.bottom, 35)
            }.scrollIndicators(.hidden)
        }.background(CraftStyle.desk.ignoresSafeArea()).preferredColorScheme(.dark)
            .accessibilityElement(children: .contain).accessibilityIdentifier("craft.cabinet")
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("自己的唱片，\n自己制作。")
                        .font(.system(.title, design: .serif).weight(.semibold)).foregroundStyle(CraftStyle.paper)
                    Text("从几首歌，到一张值得留下的唱片。")
                        .font(.footnote).foregroundStyle(CraftStyle.secondary)
                }
                Spacer(minLength: 10)
                if !records.isEmpty {
                    Button(action: onCreate) {
                        Image(systemName: "plus").font(.system(size: 20, weight: .light))
                            .frame(width: 48, height: 48).foregroundStyle(CraftStyle.desk).background(CraftStyle.paper, in: Circle())
                    }.buttonStyle(.plain).accessibilityLabel("制作新唱片").accessibilityIdentifier("craft.cabinet.create")
                }
            }
            Rectangle().fill(CraftStyle.line).frame(height: 0.75)
        }
    }

    private var emptyDesk: some View {
        VStack(spacing: 27) {
            ZStack {
                Rectangle().fill(CraftStyle.surface).frame(width: 190, height: 190)
                    .rotationEffect(.degrees(8)).overlay(Rectangle().strokeBorder(.white.opacity(0.08), lineWidth: 0.7).rotationEffect(.degrees(8)))
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("YOUR FIRST\nPRIVATE PRESS").font(CraftStyle.caption(9)).tracking(1.2)
                        Spacer()
                        Image(systemName: "asterisk").font(.system(size: 20, weight: .light))
                    }
                    Spacer()
                    Text("留一张，\n给自己。")
                        .font(.system(size: 28, weight: .medium, design: .serif))
                    Spacer()
                    Text("SIDE A / SIDE B").font(CraftStyle.caption(9)).tracking(1)
                }.foregroundStyle(CraftStyle.ink).padding(21).frame(width: 190, height: 190)
                    .background(CraftStyle.paper).rotationEffect(.degrees(-7))
                    .shadow(color: .black.opacity(0.45), radius: 15, y: 12)
            }.frame(height: 235).accessibilityHidden(true)
            VStack(spacing: 9) {
                Text("第一张唱片，从选歌开始。")
                    .font(.system(.headline, design: .serif).weight(.medium)).foregroundStyle(CraftStyle.paper)
                Text("编排双面、印一张封套。\n听完后，把音乐和这一刻一起收藏。")
                    .font(.footnote).lineSpacing(6).foregroundStyle(CraftStyle.secondary).multilineTextAlignment(.center)
            }
            CraftPrimaryButton(title: "制作第一张唱片", symbol: "plus", action: onCreate)
                .accessibilityIdentifier("craft.cabinet.create")
        }.padding(.top, 12)
    }

    private func shelf(_ title: String, subtitle: String, records: [CraftedRecord]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(.title3, design: .serif).weight(.semibold)).foregroundStyle(CraftStyle.paper)
                Text(String(records.count)).font(CraftStyle.caption(11)).foregroundStyle(CraftStyle.secondary)
            }
            Text(subtitle).font(.caption).foregroundStyle(CraftStyle.secondary).padding(.top, -9)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 26) {
                ForEach(records) { record in cover(record) }
            }
        }
    }

    private func cover(_ record: CraftedRecord) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Button { onOpen(record) } label: {
                CraftedSleeveView(record: record, image: record.coverAsset.flatMap { images[$0] })
                    .shadow(color: .black.opacity(0.3), radius: 9, y: 8)
            }.buttonStyle(.plain).accessibilityIdentifier("craft.cabinet.record." + record.id)
            HStack(alignment: .top, spacing: 5) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.title).font(.subheadline.weight(.medium)).foregroundStyle(CraftStyle.paper).lineLimit(2)
                    Text(CraftStyle.duration(record.allTrackIDs, tracks: tracks))
                        .font(CraftStyle.caption(10)).foregroundStyle(CraftStyle.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Menu {
                    Button("打开唱片", systemImage: "opticaldisc") { onOpen(record) }
                    Button("编辑封套与曲序", systemImage: "pencil") { onEdit(record) }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 15)).frame(width: 36, height: 44).foregroundStyle(CraftStyle.secondary)
                }.accessibilityLabel(record.title + "的更多操作").accessibilityIdentifier("craft.cabinet.menu." + record.id)
            }
        }.accessibilityElement(children: .contain)
    }

    private var workbench: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .firstTextBaseline) {
                Text("工作台").font(.system(.title3, design: .serif).weight(.semibold)).foregroundStyle(CraftStyle.paper)
                Text("还没做完，也先存好。")
                    .font(.caption).foregroundStyle(CraftStyle.secondary)
            }
            ForEach(drafts) { record in
                Button { onEdit(record) } label: {
                    HStack(spacing: 15) {
                        CraftedSleeveView(record: record, image: record.coverAsset.flatMap { images[$0] })
                            .frame(width: 64, height: 64).rotationEffect(.degrees(-3))
                        VStack(alignment: .leading, spacing: 7) {
                            Text(record.title.isEmpty ? "未命名唱片" : record.title).font(.body.weight(.medium)).foregroundStyle(CraftStyle.paper).lineLimit(1)
                            Text("草稿 · " + CraftStyle.duration(record.allTrackIDs, tracks: tracks)).font(.caption).foregroundStyle(CraftStyle.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.up.right").font(.system(size: 15, weight: .light)).foregroundStyle(CraftStyle.secondary).frame(width: 32, height: 44)
                    }.padding(.vertical, 10).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("craft.cabinet.draft." + record.id)
                Rectangle().fill(CraftStyle.line).frame(height: 0.5)
            }
        }
    }
}
