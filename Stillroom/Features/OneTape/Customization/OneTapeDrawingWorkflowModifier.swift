import PencilKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

enum OneTapeDrawingWorkflowRequest: Equatable {
    case startNewDrawing
    case editDrawing(OneTapeCustomDrawing)
    case exportPaper
    case importFromPhotos
    case importFromFiles
}

struct OneTapeDrawingWorkflowModifier: ViewModifier {
    @ObservedObject var drawingStore: OneTapeDrawingStore
    @Binding var appearance: OneTapeAppearance
    let cassetteReadout: OneTapeCassetteReadout
    @Binding var request: OneTapeDrawingWorkflowRequest?
    @Binding var notice: String?

    @State private var drawingCanvasSession: CanvasSession?
    @State private var drawingReviewSession: ReviewSession?
    @State private var pendingCanvasAfterReview: CanvasSession?
    @State private var paperSharePayload: PaperSharePayload?
    @State private var drawingPhotoPickerVisible = false
    @State private var selectedDrawingPhotoItem: PhotosPickerItem?
    @State private var drawingFilePickerVisible = false
    @State private var drawingImportTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, incoming in
                guard let incoming else { return }
                request = nil
                handleRequest(incoming)
            }
            .fullScreenCover(item: $drawingCanvasSession) { session in
                OneTapeDrawingCanvasView(
                    tapeStyle: appearance.tapeStyle,
                    initialDrawing: session.initialDrawing,
                    underlayImage: session.underlayImage,
                    cassetteReadout: cassetteReadout,
                    editingTitle: session.editingTitle,
                    onCancel: { drawingCanvasSession = nil },
                    onSave: { pkDrawing in
                        saveCanvasDrawing(session: session, pkDrawing: pkDrawing)
                    }
                )
            }
            .sheet(item: $drawingReviewSession, onDismiss: {
                if let pending = pendingCanvasAfterReview {
                    pendingCanvasAfterReview = nil
                    drawingCanvasSession = pending
                }
            }) { session in
                OneTapeDrawingReviewView(
                    imported: session.imported,
                    tapeStyle: appearance.tapeStyle,
                    cassetteReadout: cassetteReadout,
                    initialInkMode: session.initialInkMode,
                    onCancel: { drawingReviewSession = nil },
                    onDrawOnTop: { inkMode in
                        pendingCanvasAfterReview = CanvasSession(
                            editingID: nil,
                            editingTitle: nil,
                            initialDrawing: PKDrawing(),
                            underlayImage: session.imported.image,
                            inkMode: inkMode
                        )
                        drawingReviewSession = nil
                    },
                    onKeep: { inkMode in
                        keepImportedDrawing(session.imported, inkMode: inkMode)
                    }
                )
            }
            .sheet(item: $paperSharePayload) { payload in
                OneTapeActivityShareSheet(items: [payload.url])
                    .presentationDetents([.medium, .large])
            }
            .photosPicker(
                isPresented: $drawingPhotoPickerVisible,
                selection: $selectedDrawingPhotoItem,
                matching: .images
            )
            .fileImporter(
                isPresented: $drawingFilePickerVisible,
                allowedContentTypes: [.image, .png, .jpeg],
                allowsMultipleSelection: false
            ) { result in
                handleImportedFileResult(result)
            }
            .onChange(of: selectedDrawingPhotoItem) { _, item in
                guard let item else { return }
                selectedDrawingPhotoItem = nil
                handleImportedPhotoItem(item)
            }
            .onAppear {
                if let id = appearance.customDrawingID,
                   !drawingStore.hasCorruptedIndex,
                   !drawingStore.hasDrawing(id: id) {
                    appearance.clearCustomDrawingSelection()
                }
            }
            .onDisappear {
                drawingImportTask?.cancel()
            }
    }

    private func handleRequest(_ action: OneTapeDrawingWorkflowRequest) {
        switch action {
        case .startNewDrawing:
            drawingCanvasSession = CanvasSession(
                editingID: nil,
                editingTitle: nil,
                initialDrawing: PKDrawing(),
                underlayImage: nil,
                inkMode: .originalColors
            )
        case .editDrawing(let drawing):
            drawingCanvasSession = CanvasSession(
                editingID: drawing.id,
                editingTitle: drawingStore.displayTitle(for: drawing),
                initialDrawing: drawingStore.loadPKDrawing(for: drawing) ?? PKDrawing(),
                underlayImage: drawingStore.loadPortraitUnderlay(for: drawing),
                inkMode: drawing.inkMode
            )
        case .exportPaper:
            exportDrawingPaper()
        case .importFromPhotos:
            drawingPhotoPickerVisible = true
        case .importFromFiles:
            drawingFilePickerVisible = true
        }
    }

    private func saveCanvasDrawing(session: CanvasSession, pkDrawing: PKDrawing) {
        let hasContent = !pkDrawing.strokes.isEmpty || session.underlayImage != nil
        guard hasContent else {
            drawingCanvasSession = nil
            return
        }
        let resolvedInkMode: OneTapeDrawingInkMode
        if session.editingID == nil && session.underlayImage == nil {
            let strokeRender = pkDrawing.image(
                from: CGRect(origin: .zero, size: OneTapeDrawingGeometry.cassettePortraitSize),
                scale: 1
            )
            resolvedInkMode = OneTapeDrawingPaperService.suggestedInkMode(for: strokeRender)
        } else {
            resolvedInkMode = session.inkMode
        }
        do {
            let saved = try drawingStore.saveCanvasDrawing(
                editingID: session.editingID,
                pkDrawing: pkDrawing,
                portraitUnderlay: session.underlayImage,
                shell: appearance.tapeStyle,
                inkMode: resolvedInkMode
            )
            appearance.selectCustomDrawing(saved.id)
            drawingCanvasSession = nil
        } catch {
            drawingCanvasSession = nil
            notice = error.localizedDescription
        }
    }

    private func keepImportedDrawing(_ imported: OneTapeImportedPaper, inkMode: OneTapeDrawingInkMode) {
        do {
            let saved = try drawingStore.saveImportedInk(
                imported,
                shell: appearance.tapeStyle,
                inkMode: inkMode
            )
            appearance.selectCustomDrawing(saved.id)
            drawingReviewSession = nil
        } catch {
            drawingReviewSession = nil
            notice = error.localizedDescription
        }
    }

    private func exportDrawingPaper() {
        let style = appearance.tapeStyle
        guard let image = OneTapeDrawingPaperService.generatePaperImage(for: style) else {
            notice = "无法生成画纸，请重试。"
            return
        }
        do {
            let url = try OneTapeDrawingPaperService.writeTemporaryPaperFile(for: image, style: style)
            paperSharePayload = PaperSharePayload(url: url)
        } catch {
            notice = error.localizedDescription
        }
    }

    private func handleImportedPhotoItem(_ item: PhotosPickerItem) {
        drawingImportTask?.cancel()
        drawingImportTask = Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    if !Task.isCancelled {
                        notice = OneTapeDrawingPaperError.unreadable.localizedDescription
                    }
                    return
                }
                let imported = try await OneTapeDrawingPaperService.extractImportedDrawingAsync(fromData: data)
                if !Task.isCancelled {
                    presentReview(for: imported)
                }
            } catch is CancellationError {
                return
            } catch {
                if !Task.isCancelled {
                    notice = error.localizedDescription
                }
            }
        }
    }

    private func handleImportedFileResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            drawingImportTask?.cancel()
            drawingImportTask = Task {
                do {
                    let imported = try await OneTapeDrawingPaperService.extractImportedDrawingAsync(fromFileURL: url)
                    if !Task.isCancelled {
                        presentReview(for: imported)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    if !Task.isCancelled {
                        notice = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                notice = OneTapeDrawingPaperError.unreadable.localizedDescription
            }
        }
    }

    private func presentReview(for imported: OneTapeImportedPaper) {
        let suggested = OneTapeDrawingPaperService.suggestedInkMode(for: imported.image)
        drawingReviewSession = ReviewSession(imported: imported, initialInkMode: suggested)
    }
}

private struct CanvasSession: Identifiable {
    let id = UUID()
    let editingID: UUID?
    let editingTitle: String?
    let initialDrawing: PKDrawing
    let underlayImage: UIImage?
    let inkMode: OneTapeDrawingInkMode
}

private struct ReviewSession: Identifiable {
    let id = UUID()
    let imported: OneTapeImportedPaper
    let initialInkMode: OneTapeDrawingInkMode
}

private struct PaperSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}
