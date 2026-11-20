import SwiftUI

/// Changes stay in this value-type draft until Save. Dismissal and Cancel never mutate preferences.
struct OrbitStickerEditor: View {
    let track: Track
    let artwork: UIImage?
    let style: OrbitRecordStyle
    let background: OrbitBackground
    var onSave: ([OrbitRecordSticker]) -> Void
    var onCancel: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [OrbitRecordSticker]
    @State private var selectedID: String?
    @State private var dragOrigin: OrbitRecordSticker?

    init(track: Track, artwork: UIImage?, style: OrbitRecordStyle, background: OrbitBackground,
         onSave: @escaping ([OrbitRecordSticker]) -> Void, onCancel: @escaping () -> Void = {}) {
        self.track = track; self.artwork = artwork; self.style = style; self.background = background
        self.onSave = onSave; self.onCancel = onCancel
        _draft = State(initialValue: Array(style.stickers.prefix(12)).map { $0.normalized() })
        _selectedID = State(initialValue: style.stickers.first?.id)
    }

    private var plainStyle: OrbitRecordStyle { var value = style; value.stickers = []; return value }
    private var selected: OrbitRecordSticker? { draft.first(where: { $0.id == selectedID }) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    preview
                    HStack {
                        Text("已添加 \(draft.count)/12").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.65))
                        Spacer()
                        if let selectedID {
                            Button(role: .destructive) {
                                draft.removeAll(where: { $0.id == selectedID }); self.selectedID = draft.last?.id
                            } label: { Label("移除", systemImage: "trash") }.font(.caption).accessibilityIdentifier("orbit.stickers.remove")
                        }
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: 9) {
                            ForEach(draft) { item in
                                Button { selectedID = item.id } label: {
                                    OrbitStickerArtwork(kind: item.kind).frame(width: 32, height: 32).padding(8)
                                        .background(selectedID == item.id ? OrbitInk.accent.opacity(0.2) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selectedID == item.id ? OrbitInk.accent : .clear))
                                }.buttonStyle(.plain).accessibilityLabel(item.kind.title)
                                    .accessibilityIdentifier("orbit.stickers.item." + item.id)
                            }
                        }
                    }.scrollIndicators(.hidden)
                    if selected != nil {
                        HStack {
                            Text("大小")
                            Slider(value: pose(\.size), in: 0.1...0.34).accessibilityIdentifier("orbit.stickers.size")
                        }
                        HStack {
                            Text("旋转")
                            Slider(value: pose(\.rotation), in: -180...180).accessibilityIdentifier("orbit.stickers.rotation")
                        }
                    } else {
                        Text("先添加一枚贴纸，再在唱片上拖动位置。")
                            .font(.footnote).foregroundStyle(.white.opacity(0.5))
                    }
                    Text("贴纸库").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.65))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(OrbitStickerKind.allCases) { kind in
                            Button { add(kind) } label: {
                                VStack(spacing: 10) {
                                    OrbitStickerArtwork(kind: kind).frame(width: 42, height: 42)
                                    Text(kind.title).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
                                }.frame(maxWidth: .infinity).frame(height: 80)
                                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).disabled(draft.count >= 12)
                                .accessibilityIdentifier("orbit.stickers.add." + kind.rawValue)
                        }
                    }
                }.padding(20).foregroundStyle(.white).tint(OrbitInk.accent)
            }.background(Color(white: 0.055)).navigationTitle("唱片贴纸").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") { onCancel(); dismiss() }.accessibilityIdentifier("orbit.stickers.cancel")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("保存") { onSave(draft.map { $0.normalized() }); dismiss() }
                            .accessibilityIdentifier("orbit.stickers.save")
                    }
                }.toolbarColorScheme(.dark, for: .navigationBar)
        }.preferredColorScheme(.dark)
            .accessibilityElement(children: .contain).accessibilityIdentifier("orbit.stickers.editor")
    }

    private var preview: some View {
        GeometryReader { geometry in
            let side = min(300, geometry.size.width - 28)
            ZStack(alignment: .topLeading) {
                OrbitDiscArtwork(track: track, artwork: artwork, style: plainStyle)
                ForEach(draft) { item in
                    OrbitStickerArtwork(kind: item.kind).frame(width: side * item.size, height: side * item.size)
                        .rotationEffect(.degrees(item.rotation))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(selectedID == item.id ? OrbitInk.accent : .clear, lineWidth: 1))
                        .position(x: side * item.x, y: side * item.y).zIndex(selectedID == item.id ? 1 : 0)
                        .onTapGesture { selectedID = item.id }
                        .gesture(DragGesture(minimumDistance: 3).onChanged { value in
                            if dragOrigin?.id != item.id { dragOrigin = item; selectedID = item.id }
                            guard let origin = dragOrigin else { return }
                            var next = origin
                            next.x += value.translation.width / side; next.y += value.translation.height / side
                            replace(next)
                        }.onEnded { _ in dragOrigin = nil })
                        .accessibilityLabel(item.kind.title).accessibilityIdentifier("orbit.stickers.canvas." + item.id)
                }
            }.frame(width: side, height: side).position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }.frame(height: 318).background(Color(hex: background.hex)).clipShape(RoundedRectangle(cornerRadius: 18))
    }
    private func add(_ kind: OrbitStickerKind) {
        var value = style; value.stickers = draft
        selectedID = value.addSticker(kind); draft = value.stickers
    }
    private func replace(_ value: OrbitRecordSticker) {
        guard let index = draft.firstIndex(where: { $0.id == value.id }) else { return }
        draft[index] = value.normalized()
    }
    private func pose(_ keyPath: WritableKeyPath<OrbitRecordSticker, Double>) -> Binding<Double> {
        Binding(get: { selected?[keyPath: keyPath] ?? 0 }, set: { value in
            guard var next = selected else { return }; next[keyPath: keyPath] = value; replace(next)
        })
    }
}
