import SwiftUI

enum OneTapeHalftoneWorkflowRequest: Equatable {
    case startNewArtwork
    case editArtwork(OneTapeCustomArtwork)
}

struct OneTapeHalftoneWorkflowModifier: ViewModifier {
    @ObservedObject var artworkStore: OneTapeArtworkStore
    @Binding var appearance: OneTapeAppearance
    let cassetteReadout: OneTapeCassetteReadout
    @Binding var request: OneTapeHalftoneWorkflowRequest?
    @Binding var notice: String?

    @State private var editorSession: HalftoneEditorSession?

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, incoming in
                guard let incoming else { return }
                request = nil
                handleRequest(incoming)
            }
            .sheet(item: $editorSession) { session in
                OneTapeHalftoneEditorView(
                    initialSourceImage: session.sourceImage,
                    initialSubjectMask: session.subjectMask,
                    initialRecipe: session.initialRecipe,
                    tapeStyle: appearance.tapeStyle,
                    cassetteReadout: cassetteReadout,
                    editingTitle: session.editingTitle,
                    onCancel: { editorSession = nil },
                    onSave: { renderedPrint, sourceImage, subjectMask, recipe in
                        saveEditedArtwork(
                            session: session,
                            sourceImage: sourceImage,
                            renderedPrint: renderedPrint,
                            subjectMask: subjectMask,
                            recipe: recipe
                        )
                    }
                )
                .presentationDetents([.large])
                .presentationCornerRadius(30)
            }
            .onAppear {
                if let id = appearance.customArtworkID,
                   !artworkStore.hasCorruptedIndex,
                   !artworkStore.hasArtwork(id: id) {
                    appearance.clearCustomArtworkSelection()
                }
            }
    }

    private func handleRequest(_ action: OneTapeHalftoneWorkflowRequest) {
        switch action {
        case .startNewArtwork:
            if artworkStore.isAtCapacity {
                notice = OneTapeArtworkError.tooManyPhotos(OneTapeArtworkStore.maxArtworkCount).localizedDescription
            } else {
                editorSession = HalftoneEditorSession(
                    editingID: nil,
                    editingTitle: nil,
                    sourceImage: nil,
                    subjectMask: nil,
                    initialRecipe: OneTapeArtworkRecipe()
                )
            }
        case .editArtwork(let artwork):
            guard let source = artworkStore.loadSourceImage(for: artwork) else {
                notice = "无法打开这张照片印花。你可以删除它，再重新印制照片。"
                return
            }
            let mask = artworkStore.loadSubjectMaskImage(for: artwork)
            editorSession = HalftoneEditorSession(
                editingID: artwork.id,
                editingTitle: artworkStore.displayTitle(for: artwork),
                sourceImage: source,
                subjectMask: mask,
                initialRecipe: artwork.recipe
            )
        }
    }

    private func saveEditedArtwork(
        session: HalftoneEditorSession,
        sourceImage: UIImage,
        renderedPrint: UIImage,
        subjectMask: UIImage?,
        recipe: OneTapeArtworkRecipe
    ) {
        do {
            let saved = try artworkStore.saveArtwork(
                editingID: session.editingID,
                sourceImage: sourceImage,
                subjectMaskImage: subjectMask,
                renderedPrint: renderedPrint,
                recipe: recipe,
                shell: appearance.tapeStyle
            )
            appearance.selectCustomArtwork(saved.id)
            editorSession = nil
        } catch {
            editorSession = nil
            notice = error.localizedDescription
        }
    }
}

private struct HalftoneEditorSession: Identifiable {
    let id = UUID()
    let editingID: UUID?
    let editingTitle: String?
    let sourceImage: UIImage?
    let subjectMask: UIImage?
    let initialRecipe: OneTapeArtworkRecipe
}
