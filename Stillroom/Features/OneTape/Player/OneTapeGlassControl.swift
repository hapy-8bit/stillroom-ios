import SwiftUI

struct OneTapeGlassControl<Cover: View>: View {
    let isOpen: Bool
    let summary: String
    let isEnabled: Bool
    let onTap: () -> Void
    let onSetOpen: (Bool) -> Void
    private let content: (CGFloat) -> Cover

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.5, dampingFraction: 0.9, blendDuration: 0)))
    private var dragTranslation: CGSize? = nil
    @State private var session: DragSession?
    @State private var isPresent = true

    init(
        isOpen: Bool,
        summary: String = "",
        isEnabled: Bool = true,
        onTap: @escaping () -> Void,
        onSetOpen: @escaping (Bool) -> Void,
        @ViewBuilder content: @escaping (CGFloat) -> Cover
    ) {
        self.isOpen = isOpen
        self.summary = summary
        self.isEnabled = isEnabled
        self.onTap = onTap
        self.onSetOpen = onSetOpen
        self.content = content
    }

    private var canInteract: Bool { isEnabled && isPresent && scenePhase == .active }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                content(progress)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Color.clear
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(RoundedRectangle(cornerRadius: 19.12))
            .gesture(interaction(height: geometry.size.height), including: canInteract ? .all : .none)
            .disabled(!canInteract)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("tape.glass")
            .accessibilityLabel("玻璃")
            .accessibilityValue(accessibilityValue)
            .accessibilityHint("轻点显示或隐藏播放器菜单，上下拖动开合玻璃。")
            .accessibilityAction {
                guard canInteract else { return }
                onTap()
            }
            .accessibilityAction(named: Text("打开玻璃")) { setFromAccessibility(true) }
            .accessibilityAction(named: Text("关闭玻璃")) { setFromAccessibility(false) }
        }
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .onAppear { isPresent = true }
        .onDisappear {
            isPresent = false
            cancelInteraction()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelInteraction() }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { cancelInteraction() }
        }
        .onChange(of: dragTranslation) { _, translation in
            // A system-cancelled touch has no onEnded callback. GestureState
            // still resets, so discard its snapshot before the next touch.
            if translation == nil { cancelInteraction() }
        }
    }

    private var progress: CGFloat {
        guard canInteract, let translation = dragTranslation, let session else {
            return isOpen ? 1 : 0
        }
        return OneTapeGlassMotion.resolve(
            isOpen: session.wasOpen,
            translationY: translation.height,
            height: session.height
        ).progress
    }

    private var accessibilityValue: String {
        let state = isOpen ? "已打开" : "已关闭"
        return summary.isEmpty ? state : "\(state)；\(summary)"
    }

    private func interaction(height: CGFloat) -> some Gesture {
        // Native Button press notifications can arrive after its release action.
        // An exclusive gesture resolves each touch as exactly one drag OR tap,
        // avoiding a consumed-drag flag that can swallow the next real tap.
        DragGesture(minimumDistance: OneTapeGlassMotion.minimumDragDistance, coordinateSpace: .local)
            .onChanged { _ in
                guard canInteract else { return }
                if session == nil { session = DragSession(wasOpen: isOpen, height: height) }
            }
            .exclusively(before: TapGesture())
            .updating($dragTranslation) { value, translation, transaction in
                if canInteract, case .first(let drag) = value {
                    translation = drag.translation
                } else {
                    translation = nil
                }
                // Follow the finger directly; the caller chooses the verified
                // settling animation when it accepts the released endpoint.
                transaction.animation = nil
            }
            .onEnded { value in
                guard canInteract else { return }
                if case .second = value {
                    session = nil
                    onTap()
                    return
                }
                guard case .first(let drag) = value, let session else { return }
                let result = OneTapeGlassMotion.resolve(
                    isOpen: session.wasOpen,
                    translationY: drag.translation.height,
                    predictedTranslationY: drag.predictedEndTranslation.height,
                    height: session.height
                )
                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9, blendDuration: 0)) {
                    onSetOpen(result.targetIsOpen)
                    self.session = nil
                }
            }
    }

    private func cancelInteraction() {
        session = nil
    }

    private func setFromAccessibility(_ open: Bool) {
        guard canInteract else { return }
        cancelInteraction()
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9, blendDuration: 0)) {
            onSetOpen(open)
        }
    }

    private struct DragSession {
        let wasOpen: Bool
        let height: CGFloat
    }
}
