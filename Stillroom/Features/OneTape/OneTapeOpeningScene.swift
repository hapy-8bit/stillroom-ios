import SwiftUI

/// The overlay contains only the case lid and controls. The moving cassette
/// belongs to PlayerFace for the entire journey, including the final handoff.
struct OneTapeOpeningScene: View {
    @ObservedObject var opening: OneTapeOpeningStore
    let safeAreaInsets: EdgeInsets
    let reducedMotion: Bool
    let onOpenCase: () -> Void
    let onInsert: () -> Void
    let onSkip: () -> Void

    private var waiting: Bool { opening.journey.stage == .waiting }
    private var inspecting: Bool { opening.journey.stage == .inspecting }

    var body: some View {
        GeometryReader { geometry in
            let layout = OneTapeOpeningLayout(size: geometry.size)
            ZStack {
                Color.clear
                OneTapeOpeningCase(lid: true, opening: reducedMotion ? 0 : opening.caseOpening)
                    .rotation3DEffect(.degrees(reducedMotion ? 0 : 7), axis: (x: 1, y: 0, z: 0))
                    .scaleEffect(layout.caseScale * (reducedMotion ? 1 : 1 - 0.10 * opening.extraction))
                    .position(x: layout.looseCenter.x,
                              y: layout.looseCenter.y + (reducedMotion ? 0 : 24 * opening.extraction))
                    .opacity(opening.caseOpacity)
                if waiting || inspecting { accessibleObject(layout: layout) }
                VStack {
                    HStack {
                        Spacer()
                        Button("跳过", action: onSkip)
                            .font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("opening.skip")
                    }
                    Spacer()
                    if waiting || inspecting {
                        OneTapeOpeningGuideButton(upward: waiting, reducedMotion: reducedMotion,
                            action: waiting ? onOpenCase : onInsert)
                            .id(waiting)
                    }
                }
                .padding(.horizontal, max(22, safeAreaInsets.leading + 16))
                .padding(.top, safeAreaInsets.top + 10)
                .padding(.bottom, safeAreaInsets.bottom + 28)
                .opacity(1 - opening.homeReveal)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(interaction(width: geometry.size.width))
            .clipped()
        }
        .ignoresSafeArea(.container)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("opening.scene")
        .accessibilityValue(opening.journey.stage.caption)
    }

    private func interaction(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard inspecting else { return }
                opening.inspect(yaw: OneTapeOpeningGesture.yaw(translationX: value.translation.width, width: width),
                                reducedMotion: reducedMotion)
            }
            .onEnded { value in
                opening.releaseInspection(reducedMotion: reducedMotion)
                switch OneTapeOpeningGesture.action(stage: opening.journey.stage,
                    translation: value.translation, predicted: value.predictedEndTranslation, width: width) {
                case .openCase: onOpenCase()
                case .insert: onInsert()
                case .none: break
                }
            }
    }

    private func accessibleObject(layout: OneTapeOpeningLayout) -> some View {
        Color.clear
            .frame(width: (waiting ? 598 * layout.caseScale : 576 * layout.looseScale),
                   height: (waiting ? 392 * layout.caseScale : 376.33 * layout.looseScale))
            .position(x: layout.looseCenter.x,
                      y: layout.looseCenter.y - (waiting || reducedMotion ? 0 : layout.size.height * 0.022))
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(waiting ? "关闭的磁带盒" : "磁带")
            .accessibilityValue(waiting ? "已关闭" : "横向展示，可左右转动")
            .accessibilityHint(waiting ? "向上滑动打开磁带盒" : "左右轻拖转动，从右向左滑动放入播放器")
            .accessibilityAction { if waiting { onOpenCase() } else { onInsert() } }
            .accessibilityAdjustableAction { direction in
                guard inspecting else { return }
                opening.inspect(yaw: opening.inspectionYaw + (direction == .increment ? 15 : -15),
                                reducedMotion: reducedMotion)
            }
            .accessibilityIdentifier(waiting ? "opening.case" : "opening.cassette")
    }
}

private struct OneTapeOpeningGuideButton: View {
    let upward: Bool
    let reducedMotion: Bool
    let action: () -> Void
    @State private var nudge = false

    var body: some View {
        Button(action: action) {
            Image(systemName: upward ? "arrow.up" : "arrow.left")
                .font(.system(size: 24, weight: .ultraLight))
                .foregroundStyle(.white.opacity(nudge ? 0.82 : 0.4))
                .offset(x: upward || !nudge ? 0 : -9, y: upward && nudge ? -9 : 0)
                .frame(width: 64, height: 64).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(upward ? "打开磁带盒" : "放入磁带")
        .accessibilityHint(upward ? "向上滑动，也可轻点箭头" : "从右向左滑动，也可轻点箭头")
        .accessibilityIdentifier(upward ? "opening.openCase" : "opening.insert")
        .onAppear(perform: animateArrow)
        .onChange(of: reducedMotion) { _, reduced in
            if reduced {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { nudge = false }
            } else { animateArrow() }
        }
    }

    private func animateArrow() {
        guard !reducedMotion else { return }
        withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) { nudge = true }
    }
}

/// The player canvas is already scaled to the window. Convert window offsets
/// back to canvas points once; use the actual cassette center as every anchor.
struct OneTapeOpeningCassetteTransform: ViewModifier {
    let pose: OneTapeOpeningPlayerPose?
    let windowSize: CGSize

    func body(content: Content) -> some View {
        let value = pose ?? OneTapeOpeningPlayerPose()
        let layout = OneTapeOpeningLayout(size: windowSize)
        let anchor = UnitPoint(x: (8.33 + 376.33 / 2) / 393,
                               y: (57.33 + 576 / 2) / 852)
        let center = layout.center(progress: value.approach)
        let lift = value.reducedMotion ? 0 : windowSize.height * 0.022 * value.extraction * (1 - value.approach)
        return content
            .rotationEffect(.degrees(-90 * (1 - value.turn)), anchor: anchor)
            .rotation3DEffect(.degrees(value.reducedMotion ? 0 : 7 * (1 - value.turn)),
                              axis: (x: 1, y: 0, z: 0), anchor: anchor)
            .rotation3DEffect(.degrees(value.reducedMotion ? 0 : value.yaw),
                              axis: (x: 0, y: 1, z: 0), anchor: anchor, perspective: 0.45)
            .scaleEffect(layout.cassetteScale(extraction: value.extraction, approach: value.approach)
                         / layout.playerScale, anchor: anchor)
            .offset(x: (center.x - layout.dockCenter.x) / layout.playerScale,
                    y: (center.y - layout.dockCenter.y - lift) / layout.playerScale)
            .opacity(value.opacity)
    }
}
