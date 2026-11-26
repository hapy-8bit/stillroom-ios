import SwiftUI

/// Interactive sliding glass controller over the cassette compartment.
/// Drives a continuous animatable `progress` (`0` = closed, `1` = open) so
/// incomplete drags spring smoothly back along their original travel path
/// instead of snapping when the gesture ends.
struct OneTapeGlassControl<Cover: View>: View {
    let isOpen: Bool
    let summary: String
    let isEnabled: Bool
    let onTap: () -> Void
    let onSetOpen: (Bool) -> Void
    private let content: (CGFloat, Bool) -> Cover

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Used strictly as a system-cancellation sentinel when a touch is aborted
    // without delivering `onEnded`; `renderedProgress` owns all animation state.
    @GestureState private var isGestureActive = false
    @State private var renderedProgress: CGFloat
    @State private var isTransitioning = false
    @State private var dragStartOpen: Bool?
    @State private var settleGeneration = 0
    @State private var isPresent = true

    private var settleSpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.9, blendDuration: 0)
    }

    init(
        isOpen: Bool,
        summary: String = "",
        isEnabled: Bool = true,
        onTap: @escaping () -> Void,
        onSetOpen: @escaping (Bool) -> Void,
        @ViewBuilder content: @escaping (CGFloat, Bool) -> Cover
    ) {
        self.isOpen = isOpen
        self.summary = summary
        self.isEnabled = isEnabled
        self.onTap = onTap
        self.onSetOpen = onSetOpen
        self.content = content
        _renderedProgress = State(initialValue: isOpen ? 1 : 0)
    }

    private var canInteract: Bool { isEnabled && isPresent && scenePhase == .active }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                content(renderedProgress, isTransitioning)
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
        .onAppear {
            isPresent = true
            let resting: CGFloat = isOpen ? 1 : 0
            if dragStartOpen == nil && !isTransitioning && renderedProgress != resting {
                renderedProgress = resting
            }
        }
        .onDisappear {
            isPresent = false
            cancelInteraction(animated: false)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelInteraction(animated: false) }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { cancelInteraction(animated: true) }
        }
        .onChange(of: isGestureActive) { _, active in
            // A system-cancelled touch resets GestureState without firing onEnded.
            // Smoothly return the glass along its original direction to `isOpen`.
            if !active, dragStartOpen != nil {
                cancelInteraction(animated: true)
            }
        }
        .onChange(of: isOpen) { _, open in
            guard dragStartOpen == nil else { return }
            let target: CGFloat = open ? 1 : 0
            guard abs(renderedProgress - target) > 0.001 else { return }
            animateSettle(to: target, commit: nil)
        }
    }

    private var accessibilityValue: String {
        let state = isOpen ? "已打开" : "已关闭"
        return summary.isEmpty ? state : "\(state)；\(summary)"
    }

    private func interaction(height: CGFloat) -> some Gesture {
        // Exclusive gesture resolves each touch as exactly one drag OR tap,
        // avoiding a consumed-drag flag that can swallow the next real tap.
        DragGesture(minimumDistance: OneTapeGlassMotion.minimumDragDistance, coordinateSpace: .local)
            .onChanged { drag in
                guard canInteract else { return }
                if dragStartOpen == nil {
                    dragStartOpen = isOpen
                }
                settleGeneration += 1
                isTransitioning = true
                let startOpen = dragStartOpen ?? isOpen
                let resolved = OneTapeGlassMotion.resolve(
                    isOpen: startOpen,
                    translationY: drag.translation.height,
                    height: height
                )
                var direct = Transaction(animation: nil)
                direct.disablesAnimations = true
                withTransaction(direct) {
                    renderedProgress = resolved.progress
                }
            }
            .exclusively(before: TapGesture())
            .updating($isGestureActive) { value, state, _ in
                if canInteract, case .first = value {
                    state = true
                }
            }
            .onEnded { value in
                guard canInteract else { return }
                if case .second = value {
                    dragStartOpen = nil
                    onTap()
                    return
                }
                guard case .first(let drag) = value else { return }
                let startOpen = dragStartOpen ?? isOpen
                dragStartOpen = nil
                let result = OneTapeGlassMotion.resolve(
                    isOpen: startOpen,
                    translationY: drag.translation.height,
                    predictedTranslationY: drag.predictedEndTranslation.height,
                    height: height
                )
                let target: CGFloat = result.targetIsOpen ? 1 : 0
                animateSettle(to: target, commit: result.targetIsOpen)
            }
    }

    private func animateSettle(to target: CGFloat, commit: Bool?) {
        settleGeneration += 1
        let generation = settleGeneration
        let alreadyMounted = isTransitioning
        isTransitioning = true

        if reduceMotion {
            var direct = Transaction(animation: nil)
            direct.disablesAnimations = true
            withTransaction(direct) {
                if let commit { onSetOpen(commit) }
                renderedProgress = target
            }
            isTransitioning = false
            return
        }

        let runSpring = {
            guard settleGeneration == generation else { return }
            // Keep both optical stacks alive until the spring logically finishes so
            // partial drags rebound continuously back in their original direction.
            withAnimation(settleSpring, completionCriteria: .logicallyComplete) {
                if let commit { onSetOpen(commit) }
                renderedProgress = target
            } completion: {
                if settleGeneration == generation, dragStartOpen == nil {
                    isTransitioning = false
                }
            }
        }

        if alreadyMounted {
            runSpring()
        } else {
            // When triggered from Customizer/Accessibility while idle, let SwiftUI
            // mount both glass layers at the starting progress on this frame first.
            DispatchQueue.main.async(execute: runSpring)
        }
    }

    private func cancelInteraction(animated: Bool) {
        dragStartOpen = nil
        let target: CGFloat = isOpen ? 1 : 0
        if animated && !reduceMotion && abs(renderedProgress - target) > 0.001 {
            animateSettle(to: target, commit: nil)
        } else {
            settleGeneration += 1
            var direct = Transaction(animation: nil)
            direct.disablesAnimations = true
            withTransaction(direct) {
                renderedProgress = target
            }
            isTransitioning = false
        }
    }

    private func setFromAccessibility(_ open: Bool) {
        guard canInteract else { return }
        dragStartOpen = nil
        animateSettle(to: open ? 1 : 0, commit: open)
    }
}
