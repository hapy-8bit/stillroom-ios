import SwiftUI
import PhotosUI

@MainActor
struct CraftPhotoButton: View {
    var title = "选择照片"
    var identifier = "craft.photo.choose"
    var onBusyChange: @MainActor (Bool) -> Void = { _ in }
    let onPrepared: @MainActor (Data, UIImage) -> Void
    @State private var selection: PhotosPickerItem?
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var draft: CraftPhotoDraft?
    @State private var loadTask: Task<Void, Never>?
    @State private var revision = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                Label(title, systemImage: "photo.badge.plus").font(.subheadline.weight(.medium))
                    .frame(minHeight: 44).frame(maxWidth: .infinity)
                    .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityIdentifier(identifier)
            if loading {
                ProgressView("正在读取照片").font(.caption).accessibilityIdentifier("craft.photo.loading")
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
                    .accessibilityIdentifier("craft.photo.error")
            }
        }.accessibilityElement(children: .contain)
            .onChange(of: selection) { _, item in load(item) }
            .onChange(of: loading || draft != nil) { _, busy in onBusyChange(busy) }
            .sheet(item: $draft, onDismiss: { selection = nil }) { value in
                CraftPhotoCropSheet(source: value.source) { result in
                    guard revision == value.id else { return }
                    onPrepared(result.jpeg, result.image)
                    draft = nil
                }
            }
            .onDisappear {
                // A dismissed editor must not receive a late iCloud download or crop result.
                revision = UUID(); loadTask?.cancel(); loadTask = nil; loading = false
                onBusyChange(false)
            }
    }

    private func load(_ item: PhotosPickerItem?) {
        guard let item else { return }
        loadTask?.cancel()
        let token = UUID(); revision = token; loading = true; errorMessage = nil
        loadTask = Task { @MainActor in
            defer { if revision == token { loading = false; loadTask = nil } }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw CraftPhotoError.unavailable }
                try Task.checkCancellation()
                let worker = Task.detached(priority: .userInitiated) { try CraftPhotoProcessor.prepare(data) }
                let pixels = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                guard revision == token else { return }
                draft = CraftPhotoDraft(id: token, source: pixels)
            } catch is CancellationError {
                // Cancellation is an intentional dismissal or a newer selection, not an import error.
                return
            } catch {
                guard revision == token, !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                selection = nil // A failed transfer must allow choosing the same photo again.
            }
        }
    }
}

private struct CraftPhotoDraft: Identifiable {
    let id: UUID
    let source: CraftPhotoSource
}

@MainActor
private struct CraftPhotoCropSheet: View {
    let source: CraftPhotoSource
    let onUse: @MainActor (CraftPhotoResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var crop = CraftPhotoCrop()
    @GestureState private var drag: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var saveTask: Task<Void, Never>?

    private var displayed: CraftPhotoCrop {
        CraftPhotoProcessor.constrained(CraftPhotoCrop(zoom: crop.zoom * magnification,
            offset: CGSize(width: crop.offset.width + drag.width, height: crop.offset.height + drag.height)), imageSize: source.size)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("留住画面的一角").font(.title2.weight(.semibold))
                        Text("拖动和双指缩放，方框内就是保存的画面。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    viewport.aspectRatio(1, contentMode: .fit).frame(maxWidth: 520).frame(maxWidth: .infinity)
                        .allowsHitTesting(!busy)
                    HStack {
                        Text("缩放").font(.subheadline)
                        Slider(value: Binding(get: { crop.zoom }, set: {
                            crop = CraftPhotoProcessor.constrained(CraftPhotoCrop(zoom: $0, offset: crop.offset), imageSize: source.size)
                        }), in: 1...6).accessibilityIdentifier("craft.photo.zoom").accessibilityLabel("照片缩放")
                        Button("重置") {
                            withAnimation(reducedMotion ? nil : .easeOut(duration: 0.18)) { crop = CraftPhotoCrop() }
                        }.frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("craft.photo.reset")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("移动照片").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            moveButton("left", label: "向左移动照片", x: -0.1, y: 0)
                            moveButton("right", label: "向右移动照片", x: 0.1, y: 0)
                            moveButton("up", label: "向上移动照片", x: 0, y: -0.1)
                            moveButton("down", label: "向下移动照片", x: 0, y: 0.1)
                        }
                    }
                    Text("只保存裁切后的副本，不修改原照片。照片原有的位置等附加信息不会带入。")
                        .font(.caption).foregroundStyle(.secondary)
                    if let errorMessage { Text(errorMessage).font(.callout).foregroundStyle(.red).accessibilityIdentifier("craft.photo.crop.error") }
                }.padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }.background(Color(white: 0.055)).navigationTitle("裁切照片").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") { saveTask?.cancel(); dismiss() }.disabled(busy).frame(minHeight: 44)
                            .accessibilityIdentifier("craft.photo.crop.cancel")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: finish) {
                            if busy { ProgressView() } else { Text("使用照片").fontWeight(.semibold) }
                        }.disabled(busy).frame(minHeight: 44).accessibilityIdentifier("craft.photo.crop.use")
                    }
                }
        }.preferredColorScheme(.dark).interactiveDismissDisabled(busy)
            .accessibilityElement(children: .contain).accessibilityIdentifier("craft.photo.crop")
            .onDisappear { saveTask?.cancel(); saveTask = nil }
    }

    private var viewport: some View {
        GeometryReader { geometry in
            let side = max(1, min(geometry.size.width, geometry.size.height))
            let value = displayed
            let factor = side * value.zoom / min(source.size.width, source.size.height)
            Image(uiImage: UIImage(cgImage: source.image)).resizable()
                .frame(width: source.size.width * factor, height: source.size.height * factor)
                .position(x: side / 2 + value.offset.width * side, y: side / 2 + value.offset.height * side)
                .frame(width: side, height: side).clipped()
                .overlay(Rectangle().strokeBorder(.white.opacity(0.75), lineWidth: 1))
                .overlay {
                    VStack(spacing: 0) {
                        Spacer(); Rectangle().fill(.white.opacity(0.22)).frame(height: 0.5)
                        Spacer(); Rectangle().fill(.white.opacity(0.22)).frame(height: 0.5); Spacer()
                    }.allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture().updating($drag) { value, state, _ in
                    state = CGSize(width: value.translation.width / side, height: value.translation.height / side)
                }.onEnded { value in
                    crop = CraftPhotoProcessor.constrained(CraftPhotoCrop(zoom: crop.zoom,
                        offset: CGSize(width: crop.offset.width + value.translation.width / side,
                                       height: crop.offset.height + value.translation.height / side)), imageSize: source.size)
                })
                .simultaneousGesture(MagnificationGesture().updating($magnification) { value, state, _ in state = value }
                    .onEnded { value in
                        crop = CraftPhotoProcessor.constrained(CraftPhotoCrop(zoom: crop.zoom * value, offset: crop.offset), imageSize: source.size)
                    })
                .accessibilityElement(children: .ignore).accessibilityLabel("照片裁切预览")
                .accessibilityValue("缩放 \(Int(value.zoom * 100))%")
                .accessibilityHint("使用下方缩放滑块调整；重置回到居中画面")
                .accessibilityIdentifier("craft.photo.viewport")
        }
    }

    private func moveButton(_ direction: String, label: String, x: CGFloat, y: CGFloat) -> some View {
        Button {
            crop = CraftPhotoProcessor.constrained(CraftPhotoCrop(zoom: crop.zoom,
                offset: CGSize(width: crop.offset.width + x, height: crop.offset.height + y)), imageSize: source.size)
        } label: {
            Image(systemName: "arrow." + direction).frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier("craft.photo.move." + direction)
    }

    private func finish() {
        guard !busy else { return }
        busy = true; errorMessage = nil
        let frozenCrop = displayed
        let pixels = source
        saveTask = Task { @MainActor in
            defer { busy = false; saveTask = nil }
            do {
                let worker = Task.detached(priority: .userInitiated) {
                    try CraftPhotoProcessor.finish(pixels, crop: frozenCrop)
                }
                let result = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                onUse(result)
            } catch is CancellationError {
                return
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
