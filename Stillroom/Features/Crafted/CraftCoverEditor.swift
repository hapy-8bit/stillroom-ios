import SwiftUI

struct CraftCoverEditor: View {
    @Binding var record: CraftedRecord
    var image: UIImage?
    var onPhotoBusyChange: @MainActor (Bool) -> Void = { _ in }
    var onFocusChange: @MainActor (Bool) -> Void = { _ in }
    let onPreparedPhoto: (Data, UIImage) -> Void
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var back = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case title, dedication }

    var body: some View {
        GeometryReader { viewport in
            // Only the available logical width defines printed squares. Keyboard height changes
            // may shorten the scroll viewport, but must never compress the sleeve's aspect ratio.
            let width = viewport.size.width.isFinite ? max(1, viewport.size.width - 48) : 1
            ScrollView { form(width: width) }
                .scrollIndicators(.hidden).scrollDismissesKeyboard(.immediately)
        }
        .toolbar {
            if focusedField != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成输入") { focusedField = nil }
                        .accessibilityIdentifier("craft.cover.keyboardDone")
                }
            }
        }
        .onChange(of: focusedField != nil) { _, focused in onFocusChange(focused) }
        .onDisappear {
            focusedField = nil
            onFocusChange(false)
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("craft.step.cover")
    }

    private func form(width: CGFloat) -> some View {
        let previewSide = min(290, max(1, width - 36))
        let thumbnailSide = max(1, (width - 24) / 3)
        return VStack(alignment: .leading, spacing: 25) {
            HStack(alignment: .firstTextBaseline) {
                Text("给它一张封套。")
                    .font(.system(.title2, design: .serif).weight(.semibold)).foregroundStyle(CraftStyle.paper)
                Spacer(minLength: 8)
                Text(back ? "背面" : "正面").font(CraftStyle.caption(11)).foregroundStyle(CraftStyle.secondary)
            }
            VStack(spacing: 12) {
                Button {
                    focusedField = nil
                    withAnimation(reducedMotion ? nil : .easeInOut(duration: 0.48)) { back.toggle() }
                } label: {
                    CraftedSleeveFlipView(record: record, image: image, angle: back ? 180 : 0)
                        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 14)
                }.buttonStyle(.plain).frame(width: previewSide, height: previewSide).padding(.horizontal, 18)
                    .accessibilityLabel(back ? "查看封套正面" : "翻看封套背面").accessibilityIdentifier("craft.cover.flip")
                Label("轻点翻看" + (back ? "正面" : "背面"), systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.caption).foregroundStyle(CraftStyle.secondary)
            }.frame(maxWidth: .infinity).padding(.top, 2)
            VStack(alignment: .leading, spacing: 11) {
                fieldHeader("唱片名字", count: record.title.count, limit: 60)
                TextField("例如：回家的那段路", text: limited(\.title, to: 60), axis: .vertical)
                    .focused($focusedField, equals: .title)
                    .font(.system(.title3, design: .serif).weight(.medium)).foregroundStyle(CraftStyle.paper)
                    .lineLimit(1...3).padding(.vertical, 7).accessibilityIdentifier("craft.cover.title")
                Rectangle().fill(CraftStyle.line).frame(height: 0.75)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("封套构图").font(.subheadline.weight(.medium)).foregroundStyle(CraftStyle.paper)
                HStack(alignment: .top, spacing: 12) {
                    ForEach(SleeveDesign.allCases) { design in
                        Button { focusedField = nil; record.design = design; back = false } label: {
                            VStack(spacing: 9) {
                                CraftedSleeveView(record: preview(design), image: image)
                                    .frame(width: thumbnailSide, height: thumbnailSide)
                                    .overlay(alignment: .bottom) {
                                        if record.design == design { Rectangle().fill(CraftStyle.accent).frame(height: 3) }
                                    }.accessibilityHidden(true)
                                Text(design.label).font(.system(size: 12, weight: record.design == design ? .semibold : .regular))
                                    .foregroundStyle(record.design == design ? CraftStyle.paper : CraftStyle.secondary)
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(.plain).accessibilityLabel(design.label + "封套")
                            .accessibilityAddTraits(record.design == design ? .isSelected : [])
                            .accessibilityIdentifier("craft.cover.design." + design.rawValue)
                    }
                }
                CraftPhotoButton(onBusyChange: onPhotoBusyChange) { data, image in
                    onPreparedPhoto(data, image); record.design = .photo; back = false
                }.accessibilityIdentifier("craft.cover.photo")
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("印刷颜色").font(.subheadline.weight(.medium)).foregroundStyle(CraftStyle.paper)
                HStack(spacing: 9) {
                    ForEach(SleeveColor.allCases) { color in
                        Button { focusedField = nil; record.color = color } label: {
                            VStack(spacing: 8) {
                                Circle().fill(CraftStyle.color(color)).frame(width: 34, height: 34)
                                    .padding(4).overlay(Circle().strokeBorder(record.color == color ? CraftStyle.paper : .white.opacity(0.16), lineWidth: record.color == color ? 1.5 : 0.7))
                                Text(color.label).font(.caption).foregroundStyle(record.color == color ? CraftStyle.paper : CraftStyle.secondary)
                            }.frame(maxWidth: .infinity).frame(minHeight: 64)
                        }.buttonStyle(.plain).accessibilityLabel(color.label)
                            .accessibilityAddTraits(record.color == color ? .isSelected : [])
                            .accessibilityIdentifier("craft.cover.color." + color.rawValue)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                fieldHeader("背面寄语", count: record.dedication.count, limit: 600)
                TextField("写给某个人，或写给此刻的自己。", text: limited(\.dedication, to: 600), axis: .vertical)
                    .focused($focusedField, equals: .dedication)
                    .font(.body).lineSpacing(6).foregroundStyle(CraftStyle.paper).lineLimit(4...10)
                    .padding(15).frame(maxWidth: .infinity, alignment: .leading)
                    .background(CraftStyle.surface, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("craft.cover.dedication")
                Text("寄语会印在封套背面，也可以留白。")
                    .font(.caption).foregroundStyle(CraftStyle.secondary)
            }
        }.padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 28)
    }

    private func preview(_ design: SleeveDesign) -> CraftedRecord { var copy = record; copy.design = design; return copy }
    private func limited(_ key: WritableKeyPath<CraftedRecord, String>, to count: Int) -> Binding<String> {
        Binding(get: { record[keyPath: key] }, set: { record[keyPath: key] = String($0.prefix(count)) })
    }
    private func fieldHeader(_ title: String, count: Int, limit: Int) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(CraftStyle.paper)
            Spacer()
            Text("\(count) / \(limit)").font(CraftStyle.caption(10)).foregroundStyle(CraftStyle.secondary)
        }
    }
}
