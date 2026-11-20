import SwiftUI

struct CraftListeningPresentation {
    var record: CraftedRecord
    var cover: UIImage?
    var tracks: [Track]
    var current: Track
    var session: CraftListeningSession?
    var playing: Bool
    var preparing: Bool
    var position: Double
    var duration: Double
    var collected: Bool
    var busy: Bool
    var reducedMotion: Bool
    var selectionRevision: Int
    var newerEditionAvailable: Bool
    var isLive: Bool { session?.record.id == record.id }
    var phase: CraftListeningPhase? { isLive ? session?.phase : nil }
    var sideFraction: Double? { isLive ? session?.fraction(currentID: current.id, position: position, duration: duration, tracks: tracks) : nil }
}

struct CraftListeningActions {
    var start: () -> Void
    var toggle: () -> Void
    var skip: (Int) -> Void
    var seek: (Double) -> Void
    var flip: () -> Void
    var end: () -> Void
    var collect: () async -> Bool
    var memory: (Track) -> Void
    var edit: () -> Void
    var close: () -> Void
}

/// The sleeve, side boundaries and end card describe the same frozen edition as PlayerStore.
/// Opening the sleeve or inspecting its back never starts audio or rebuilds that queue.
struct CraftedListeningView: View {
    let model: CraftListeningPresentation
    let actions: CraftListeningActions
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    @State private var back = false
    @State private var inspectedSide: CraftedSide = .a
    @State private var scrub: Double?
    @State private var scrubOwner: String?
    @State private var confirmingEnd = false
    private var reduced: Bool { model.reducedMotion || systemReducedMotion }
    private var side: CraftedSide { model.isLive ? model.session?.side ?? .a : .a }
    private var boundary: Bool { model.phase == .awaitingFlip || model.phase == .finished }
    private var hasEnded: Bool { model.phase == .finished }
    private var seekKey: String { model.current.id + "|" + String(model.selectionRevision) }

    var body: some View {
        ScrollViewReader { reader in
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                header.id("craft.top")
                CraftedListeningStage(record: model.record, image: model.cover, side: side,
                    fraction: model.sideFraction,
                    running: model.isLive && model.playing && scenePhase == .active && !reduced,
                    raised: !model.isLive || !model.playing, back: back, reducedMotion: reduced)
                    .aspectRatio(1, contentMode: .fit)
                    .accessibilityLabel("\(model.record.title)，\(side.label)，\(model.playing ? "正在播放" : "唱臂已收起")")
                titleBlock
                if model.isLive && !hasEnded { mediaControls }
                if hasEnded { endCard.id("craft.completion") }
                if !model.record.dedication.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("封套上的话").font(CraftStyle.caption()).foregroundStyle(CraftStyle.secondary)
                        Text(model.record.dedication).font(.system(.body, design: .serif)).lineSpacing(7)
                            .foregroundStyle(CraftStyle.paper).textSelection(.enabled)
                    }.padding(.vertical, 8)
                }
                trackListing
            }.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 24).frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
        }.scrollIndicators(.hidden).background(CraftStyle.desk.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { bottomDeck }
            .accessibilityElement(children: .contain).accessibilityIdentifier("craft.listening")
            .onAppear { inspectedSide = side }
            .onChange(of: side) { _, next in inspectedSide = next; scrub = nil; scrubOwner = nil }
            .onChange(of: model.current.id) { _, _ in scrub = nil; scrubOwner = nil }
            .onChange(of: model.selectionRevision) { _, _ in scrub = nil; scrubOwner = nil }
            .confirmationDialog("结束这次试听？唱片与当前位置会保留。", isPresented: $confirmingEnd) {
                Button("收针，结束这次试听", action: actions.end)
            }
            .task(id: hasEnded) {
                // Wait for the end card's new layout anchor, not for an arbitrary animation time.
                await Task.yield()
                let anchor = hasEnded ? "craft.completion" : "craft.top"
                if reduced { reader.scrollTo(anchor, anchor: .top) }
                else { withAnimation(.easeInOut(duration: 0.35)) { reader.scrollTo(anchor, anchor: .top) } }
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: actions.close) { Label("唱片柜", systemImage: "arrow.left").font(.subheadline).frame(minHeight: 44) }
                .accessibilityIdentifier("craft.listening.close")
            Spacer()
            Menu {
                Button("翻看封套") { withAnimation(reduced ? nil : .easeInOut(duration: 0.45)) { back.toggle() } }
                Button("编辑这张唱片", action: actions.edit)
                if model.isLive && !hasEnded { Button("结束这次试听") { confirmingEnd = true } }
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                .accessibilityLabel("唱片操作").accessibilityIdentifier("craft.listening.more")
        }.buttonStyle(.plain).foregroundStyle(CraftStyle.paper)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("PRIVATE PRESS / " + side.rawValue.uppercased()).font(CraftStyle.caption())
                if model.collected { Label("已收藏", systemImage: "checkmark.seal").font(.caption) }
            }.foregroundStyle(CraftStyle.accent)
            Text(model.record.title).font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(CraftStyle.paper).fixedSize(horizontal: false, vertical: true)
            Text(model.isLive && !hasEnded ? model.current.title : CraftStyle.duration(model.record.allTrackIDs, tracks: model.tracks))
                .font(.subheadline).foregroundStyle(CraftStyle.secondary)
            if model.newerEditionAvailable {
                Text("新封套与曲序已保存，下次从 A 面开始时使用。")
                    .font(.caption).foregroundStyle(CraftStyle.accent)
            }
        }
    }

    private var mediaControls: some View {
        VStack(spacing: 12) {
            if !boundary {
                Slider(value: Binding(get: { scrub ?? model.position }, set: { value in
                    if scrubOwner == nil { scrubOwner = seekKey }
                    scrub = value
                }), in: 0...max(1, model.duration), onEditingChanged: { editing in
                    if !editing {
                        if let value = scrub, scrubOwner == seekKey { actions.seek(value) }
                        scrub = nil; scrubOwner = nil
                    }
                }).tint(CraftStyle.accent).accessibilityLabel("歌曲进度").accessibilityIdentifier("craft.progress")
                HStack { Text(MediaTime.label(scrub ?? model.position)); Spacer(); Text(MediaTime.label(model.duration)) }
                    .font(CraftStyle.caption(11)).foregroundStyle(CraftStyle.secondary)
            } else {
                Text("A 面已经播放到末尾，翻到 B 面继续。").font(.subheadline).foregroundStyle(CraftStyle.accent)
                    .accessibilityIdentifier("craft.awaitingFlip")
            }
        }
    }

    private var endCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Image(systemName: "opticaldisc").font(.system(size: 25, weight: .ultraLight))
            Text(model.session?.allReachedEnd == true ? "这一张，听到了最后。" : "收针，留一点余响。")
                .font(.system(.title2, design: .serif)).accessibilityIdentifier("craft.finished")
            Text("可以给歌曲留下一句话，再把这张唱片收进柜子。").font(.subheadline).lineSpacing(5)
                .foregroundStyle(CraftStyle.secondary)
            Button { actions.memory(model.current) } label: { Label("给这首歌留一段记忆", systemImage: "square.and.pencil").frame(minHeight: 44) }
                .font(.subheadline).accessibilityIdentifier("craft.finished.memory")
        }.foregroundStyle(CraftStyle.paper).padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(CraftStyle.surface, in: RoundedRectangle(cornerRadius: 4))
            .overlay(alignment: .top) { Rectangle().fill(CraftStyle.accent).frame(height: 2) }
    }

    private var trackListing: some View {
        VStack(spacing: 8) {
            CraftSidePicker(selected: $inspectedSide, sideA: model.record.sideA.count, sideB: model.record.sideB.count)
            ForEach(Array(model.record.trackIDs(on: inspectedSide).enumerated()), id: \.element) { index, id in
                let track = model.tracks.first { $0.id == id }
                HStack(spacing: 14) {
                    Text(String(format: "%02d", index + 1)).font(CraftStyle.caption(11)).foregroundStyle(CraftStyle.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track?.title ?? "歌曲暂不可用").font(.subheadline).foregroundStyle(CraftStyle.paper)
                        Text(track?.artist ?? "请回制作页检查曲库").font(.caption).foregroundStyle(CraftStyle.secondary)
                    }
                    Spacer(minLength: 4)
                    if let track {
                        Button { actions.memory(track) } label: { Image(systemName: "text.bubble").frame(width: 44, height: 44) }
                            .accessibilityLabel("\(track.title)的歌曲记忆").accessibilityIdentifier("craft.track.memory." + id)
                    }
                }.padding(.vertical, 9).overlay(alignment: .bottom) { Rectangle().fill(CraftStyle.line).frame(height: 0.5) }
            }
            if model.record.trackIDs(on: inspectedSide).isEmpty {
                Text("这一面留白。").font(.subheadline).foregroundStyle(CraftStyle.secondary).padding(24)
            }
        }.foregroundStyle(CraftStyle.paper).buttonStyle(.plain)
    }

    private var bottomDeck: some View {
        VStack(spacing: 12) {
            if hasEnded {
                CraftPrimaryButton(title: model.collected ? "回到唱片柜" : "收进唱片柜", symbol: model.collected ? "arrow.left" : "square.stack.3d.up", enabled: !model.busy) {
                    if model.collected { actions.close() } else { Task { _ = await actions.collect() } }
                }.accessibilityIdentifier("craft.collect")
                Button("从 A 面再听一次", action: actions.start).font(.subheadline).frame(minHeight: 36)
                    .accessibilityIdentifier("craft.replay")
            } else if !model.isLive {
                CraftPrimaryButton(title: "落针，从 A 面开始", symbol: "play.fill", action: actions.start)
                    .accessibilityIdentifier("craft.start")
            } else if model.phase == .awaitingFlip {
                CraftPrimaryButton(title: "翻到 B 面 · 继续听", symbol: "arrow.triangle.2.circlepath", action: actions.flip)
                    .accessibilityIdentifier("craft.flip")
            } else {
                HStack(spacing: 26) {
                    transportButton("backward.end.fill", label: "上一首", id: "craft.previous") { actions.skip(-1) }
                    transportButton(model.playing || model.preparing ? "pause.fill" : "play.fill", label: model.playing ? "暂停" : "播放", id: "craft.play", prominent: true, action: actions.toggle)
                    transportButton("forward.end.fill", label: "下一首", id: "craft.next") { actions.skip(1) }
                    Spacer(minLength: 0)
                    Button { actions.memory(model.current) } label: { Image(systemName: "square.and.pencil").frame(width: 44, height: 44) }
                        .accessibilityLabel("记录当前歌曲的记忆").accessibilityIdentifier("craft.now.memory")
                }.buttonStyle(.plain)
            }
        }.foregroundStyle(CraftStyle.paper).padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 10)
            .background(CraftStyle.desk).overlay(alignment: .top) { Rectangle().fill(CraftStyle.line).frame(height: 0.5) }
    }

    private func transportButton(_ symbol: String, label: String, id: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: prominent ? 20 : 17))
            .frame(width: prominent ? 62 : 44, height: prominent ? 62 : 44)
            .foregroundStyle(prominent ? CraftStyle.desk : CraftStyle.paper)
            .background(prominent ? CraftStyle.paper : .clear, in: Circle())
        }.accessibilityLabel(label).accessibilityIdentifier(id)
    }
}
