import PhotosUI
import SwiftUI

struct OneTapeHalftoneEditorView: View {
    let tapeStyle: OneTapeAppearance.TapeStyle
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var editingTitle: String? = nil
    let onCancel: () -> Void
    let onSave: (_ renderedPrint: UIImage, _ sourceImage: UIImage, _ subjectMask: UIImage?, _ recipe: OneTapeArtworkRecipe) -> Void

    @State private var currentSourceImage: UIImage?
    @State private var subjectMask: UIImage?
    @State private var recipe: OneTapeArtworkRecipe
    @State private var previewImage: UIImage?
    @State private var previewErrorMessage: String?
    @State private var alertMessage: String?
    @State private var isLoadingPhoto = false
    @State private var isIsolatingSubject = false
    @State private var isFinalizing = false
    @State private var showsCropSheet = false
    @State private var photoPickerVisible = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var loadTask: Task<Void, Never>?
    @State private var renderTask: Task<Void, Never>?
    @State private var subjectTask: Task<Void, Never>?

    // Incremental gesture bases so drag/pinch/rotate combine smoothly in landscape preview coordinates.
    @State private var gestureBasePlacement: OneTapeArtworkPlacement?
    @State private var lastMagnification: CGFloat = 1
    @State private var lastRotation = Angle.zero

    init(
        initialSourceImage: UIImage? = nil,
        initialSubjectMask: UIImage? = nil,
        initialRecipe: OneTapeArtworkRecipe = OneTapeArtworkRecipe(),
        tapeStyle: OneTapeAppearance.TapeStyle,
        cassetteReadout: OneTapeCassetteReadout = .empty,
        editingTitle: String? = nil,
        onCancel: @escaping () -> Void,
        onSave: @escaping (_ renderedPrint: UIImage, _ sourceImage: UIImage, _ subjectMask: UIImage?, _ recipe: OneTapeArtworkRecipe) -> Void
    ) {
        self.tapeStyle = tapeStyle
        self.cassetteReadout = cassetteReadout
        self.editingTitle = editingTitle
        self.onCancel = onCancel
        self.onSave = onSave
        _currentSourceImage = State(initialValue: initialSourceImage)
        _subjectMask = State(initialValue: initialSubjectMask)
        _recipe = State(initialValue: initialRecipe)
    }

    private var previewShellAppearance: OneTapeAppearance {
        var copy = OneTapeAppearance()
        copy.tapeStyle = tapeStyle
        copy.printStyle = currentSourceImage == nil ? .brand : .blank
        copy.doodleStyle = .none
        return copy
    }

    private var resolvedPreviewPrint: OneTapeResolvedPrint? {
        guard let previewImage else { return nil }
        return OneTapeResolvedPrint(drawingID: UUID(), revision: 0, image: previewImage, inkMode: .originalColors)
    }

    private var canApply: Bool {
        currentSourceImage != nil && !isLoadingPhoto && !isFinalizing && !isIsolatingSubject && previewErrorMessage == nil
    }

    private var hasAdjustedPlacement: Bool {
        let p = recipe.placement
        return abs(p.offsetX) > 0.001 || abs(p.offsetY) > 0.001
            || abs(p.scale - 1.0) > 0.01 || abs(p.rotationDegrees) > 0.25
    }

    private var deviceStorageNote: String {
        "保存在这台 \(UIDevice.current.model) 上。稍后可以调整印花和位置。"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 18.0 / 255.0, green: 18.0 / 255.0, blue: 18.0 / 255.0)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    previewStage
                        .frame(height: 214)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    previewCaptionBar
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)

                    Divider().overlay(.white.opacity(0.08))

                    ScrollView {
                        if currentSourceImage == nil {
                            emptyStateContent
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 32)
                        } else {
                            loadedControlsContent
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 36)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                        .foregroundStyle(.white.opacity(0.9))
                        .disabled(isFinalizing)
                        .accessibilityIdentifier("halftoneEditor.cancel")
                }
                ToolbarItem(placement: .principal) {
                    Text(editingTitle ?? "新照片印花")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        commitFinalPrint()
                    } label: {
                        if isFinalizing {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Text("应用")
                        }
                    }
                    .foregroundStyle(canApply ? .white : .white.opacity(0.32))
                    .disabled(!canApply)
                    .accessibilityIdentifier("halftoneEditor.done")
                }
            }
        }
        .preferredColorScheme(.dark)
        .photosPicker(
            isPresented: $photoPickerVisible,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            selectedPhotoItem = nil
            loadPickedPhoto(item)
        }
        .sheet(isPresented: $showsCropSheet) {
            if let source = currentSourceImage {
                OneTapeArtworkCropSheet(
                    sourceImage: source,
                    initialCrop: recipe.placement.cropRect,
                    onCancel: { showsCropSheet = false },
                    onApply: { newCrop in
                        recipe.placement.cropRect = newCrop
                        showsCropSheet = false
                        schedulePreviewRender(immediate: true)
                    }
                )
            }
        }
        .alert("网点照片", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            if currentSourceImage != nil {
                schedulePreviewRender(immediate: true)
            }
        }
        .onDisappear {
            loadTask?.cancel()
            renderTask?.cancel()
            subjectTask?.cancel()
        }
    }

    private var previewStage: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.115))

                OneTapeTapeThumbnail(
                    tilt: 0,
                    appearance: previewShellAppearance,
                    cassetteReadout: cassetteReadout,
                    customPrint: resolvedPreviewPrint
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                if isLoadingPhoto {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.black.opacity(0.45))
                    ProgressView()
                        .tint(.white)
                }

                if let previewErrorMessage, currentSourceImage != nil {
                    Text(previewErrorMessage)
                        .font(.caption.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 16)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                placementGesture(canvasSize: proxy.size),
                including: currentSourceImage == nil ? .none : .all
            )
        }
    }

    private var previewCaptionBar: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            Text(currentSourceImage == nil ? "选一张照片，印在这盘磁带上。" : "拖动调整位置 · 双指缩放 · 转动旋转")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .overlay(alignment: .trailing) {
            if currentSourceImage != nil && hasAdjustedPlacement {
                Button("重置") {
                    recipe.placement.offsetX = 0
                    recipe.placement.offsetY = 0
                    recipe.placement.scale = 1
                    recipe.placement.rotationDegrees = 0
                    schedulePreviewRender(immediate: true)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyStateContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("让这盘磁带成为你的专属。")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))

            Text("选一张照片，做成网点印花；也可以选一幅画在浅色素纸上的画，只印出线条。")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.65))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            imagePickerButton(title: "选择图片", identifier: "halftoneEditor.chooseImage")
                .padding(.top, 2)

            Text(deviceStorageNote)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadedControlsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    imagePickerButton(title: "更换图片", identifier: "halftoneEditor.replaceImage")
                    Button {
                        showsCropSheet = true
                    } label: {
                        Label("裁剪", systemImage: "crop")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(red: 235.0 / 255.0, green: 231.0 / 255.0, blue: 214.0 / 255.0))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(red: 52.0 / 255.0, green: 50.0 / 255.0, blue: 43.0 / 255.0), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("halftoneEditor.crop")
                }

                Text(deviceStorageNote)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }

            OneTapeHalftoneControlsPanel(
                recipe: $recipe,
                tapeStyle: tapeStyle,
                isIsolatingSubject: isIsolatingSubject,
                onToggleSubjectOnly: handleSubjectOnlyChanged,
                onParameterChanged: { immediate in
                    schedulePreviewRender(immediate: immediate)
                }
            )
        }
    }

    private func imagePickerButton(title: String, identifier: String) -> some View {
        Button {
            photoPickerVisible = true
        } label: {
            Label(title, systemImage: "photo")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 235.0 / 255.0, green: 231.0 / 255.0, blue: 214.0 / 255.0))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 52.0 / 255.0, green: 50.0 / 255.0, blue: 43.0 / 255.0), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLoadingPhoto)
        .accessibilityIdentifier(identifier)
    }

    private func placementGesture(canvasSize: CGSize) -> some Gesture {
        let drag = DragGesture()
            .onChanged { value in
                if gestureBasePlacement == nil {
                    gestureBasePlacement = recipe.placement
                }
                let base = gestureBasePlacement ?? recipe.placement
                recipe.placement.offsetX = min(1.0, max(-1.0, base.offsetX + Double(value.translation.width / max(1, canvasSize.width))))
                recipe.placement.offsetY = min(1.0, max(-1.0, base.offsetY + Double(value.translation.height / max(1, canvasSize.height))))
            }
            .onEnded { _ in
                gestureBasePlacement = nil
                schedulePreviewRender(immediate: true)
            }

        let magnify = MagnificationGesture()
            .onChanged { factor in
                let delta = factor / max(0.01, lastMagnification)
                lastMagnification = factor
                recipe.placement.scale = min(4.0, max(0.35, recipe.placement.scale * Double(delta)))
            }
            .onEnded { _ in
                lastMagnification = 1
                schedulePreviewRender(immediate: true)
            }

        let rotate = RotationGesture()
            .onChanged { angle in
                let delta = angle.degrees - lastRotation.degrees
                lastRotation = angle
                recipe.placement.rotationDegrees += delta
            }
            .onEnded { _ in
                lastRotation = .zero
                schedulePreviewRender(immediate: true)
            }

        return drag.simultaneously(with: magnify).simultaneously(with: rotate)
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem) {
        loadTask?.cancel()
        isLoadingPhoto = true
        loadTask = Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let raw = UIImage(data: data) else {
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        isLoadingPhoto = false
                        alertMessage = OneTapeArtworkError.unreadable.localizedDescription
                    }
                    return
                }
                let normalized = try await Task.detached(priority: .userInitiated) {
                    try OneTapeHalftoneEngine.normalizeSourceImage(raw)
                }.value
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    isLoadingPhoto = false
                    subjectTask?.cancel()
                    subjectMask = nil
                    recipe.subjectOnly = false
                    recipe.placement = .init()
                    currentSourceImage = normalized
                    previewErrorMessage = nil
                    schedulePreviewRender(immediate: true)
                }
            } catch is CancellationError {
                await MainActor.run { isLoadingPhoto = false }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    isLoadingPhoto = false
                    alertMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleSubjectOnlyChanged(_ enabled: Bool) {
        guard let image = currentSourceImage else { return }
        if !enabled {
            subjectTask?.cancel()
            recipe.subjectOnly = false
            schedulePreviewRender(immediate: true)
            return
        }
        if subjectMask != nil {
            recipe.subjectOnly = true
            schedulePreviewRender(immediate: true)
            return
        }

        isIsolatingSubject = true
        subjectTask?.cancel()
        subjectTask = Task.detached(priority: .userInitiated) {
            do {
                let extracted = try OneTapeHalftoneEngine.extractSubjectCutout(from: image)
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    subjectMask = extracted
                    recipe.subjectOnly = true
                    isIsolatingSubject = false
                    schedulePreviewRender(immediate: true)
                }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    recipe.subjectOnly = false
                    isIsolatingSubject = false
                    alertMessage = error.localizedDescription
                }
            }
        }
    }

    private func schedulePreviewRender(immediate: Bool) {
        renderTask?.cancel()
        guard let snapshotSource = currentSourceImage else {
            previewImage = nil
            previewErrorMessage = nil
            return
        }
        let snapshotRecipe = recipe
        let snapshotMask = subjectMask
        let style = tapeStyle

        renderTask = Task.detached(priority: .userInitiated) {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(75))
            }
            guard !Task.isCancelled else { return }
            do {
                let image = try OneTapeHalftoneEngine.renderArtworkPrint(
                    sourceImage: snapshotSource,
                    subjectMaskImage: snapshotMask,
                    recipe: snapshotRecipe,
                    shell: style,
                    targetSize: OneTapeHalftoneEngine.previewRenderSize
                )
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    previewImage = image
                    previewErrorMessage = nil
                }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    previewImage = nil
                    previewErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func commitFinalPrint() {
        guard let snapshotSource = currentSourceImage else { return }
        isFinalizing = true
        let snapshotRecipe = recipe
        let snapshotMask = subjectMask
        let style = tapeStyle

        Task.detached(priority: .userInitiated) {
            do {
                let fullPrint = try OneTapeHalftoneEngine.renderArtworkPrint(
                    sourceImage: snapshotSource,
                    subjectMaskImage: snapshotMask,
                    recipe: snapshotRecipe,
                    shell: style,
                    targetSize: OneTapeHalftoneEngine.finalExportSize
                )
                await MainActor.run {
                    isFinalizing = false
                    onSave(fullPrint, snapshotSource, snapshotMask, snapshotRecipe)
                }
            } catch {
                await MainActor.run {
                    isFinalizing = false
                    alertMessage = error.localizedDescription
                }
            }
        }
    }
}
