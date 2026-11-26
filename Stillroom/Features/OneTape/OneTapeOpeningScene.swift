import SwiftUI

/// Full-screen factory anti-static sleeve overlay sitting directly over the
/// real live `OneTapePlayerFace`. Sliding left/right glides the horizontal
/// zipper 1:1 while visibly parting the upper and lower sleeve flaps up and
/// down; tapping the red `"拆封"` pull-tab zips it smoothly open automatically.
struct OneTapeOpeningScene: View {
    @ObservedObject var opening: OneTapeOpeningStore
    let safeAreaInsets: EdgeInsets
    let reducedMotion: Bool
    let onCommitUnwrap: () -> Void
    let onSkip: () -> Void

    @State private var peakDragDistance: CGFloat = 0

    private var interactive: Bool {
        opening.journey.stage == .sealed || opening.journey.stage == .tearing
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let tearY = max(safeAreaInsets.top + 148, height * 0.28)
            let peel = opening.sleevePeel

            ZStack(alignment: .topLeading) {
                Color.clear.frame(width: width, height: height)

                // Top heat-sealed cap: parts UP behind the zipper, then glides off upward.
                OneTapeFactorySleeveHalf(
                    isTopCap: true,
                    tearProgress: opening.tearProgress,
                    sheenAnchor: opening.sheenAnchor,
                    peelProgress: peel,
                    bottomSafeInset: safeAreaInsets.bottom
                )
                .frame(width: width, height: tearY)
                .offset(y: -(reducedMotion ? 0 : (tearY + 60) * peel))
                .rotation3DEffect(
                    .degrees(reducedMotion ? 0 : -14 * Double(peel)),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .top,
                    perspective: 0.45
                )
                .opacity(opening.sleeveOpacity)

                // Main lower frosted pouch: parts DOWN behind the zipper, then glides off downward.
                OneTapeFactorySleeveHalf(
                    isTopCap: false,
                    tearProgress: opening.tearProgress,
                    sheenAnchor: opening.sheenAnchor,
                    peelProgress: peel,
                    bottomSafeInset: safeAreaInsets.bottom
                )
                .frame(width: width, height: max(1, height - tearY))
                .offset(y: tearY + (reducedMotion ? 0 : height * 0.88 * peel))
                .rotation3DEffect(
                    .degrees(reducedMotion ? 0 : 9 * Double(peel)),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    perspective: 0.45
                )
                .opacity(opening.sleeveOpacity)

                // Horizontal interlocking zipper track & red `"拆封 >"` slider pull-tab.
                OneTapeOpeningTearStrip(
                    tearProgress: opening.tearProgress,
                    detachment: opening.stripDetachment,
                    slideDirection: opening.slideDirection,
                    reducedMotion: reducedMotion,
                    onAccessibilityActivate: onCommitUnwrap
                )
                .offset(y: tearY - 26)
                .opacity(opening.sleeveOpacity)

                // Floating prompt pill below the zipper until the user begins unzipping.
                if opening.journey.stage == .sealed && opening.tearProgress < 0.06 {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 11, weight: .medium))
                        Text("左右滑动撕开封条，或轻点拆封")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(0.3)
                    }
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.56), in: Capsule())
                    .overlay { Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.6) }
                    .frame(maxWidth: .infinity)
                    .offset(y: tearY + 38)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }

                // Top-right Skip control (respects Dynamic Island / top safe inset).
                HStack {
                    Spacer()
                    Button("跳过", action: onSkip)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 13)
                        .frame(minWidth: 44, minHeight: 34)
                        .background(.black.opacity(0.36), in: Capsule())
                        .accessibilityIdentifier("opening.skip")
                }
                .padding(.horizontal, max(22, safeAreaInsets.trailing + 18))
                .padding(.top, max(54, safeAreaInsets.top + 8))
                .opacity(opening.sleeveOpacity)
            }
            .frame(width: width, height: height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(zipperGesture(width: width, height: height, tearY: tearY))
            .clipped()
        }
        .ignoresSafeArea(.container)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("opening.scene")
        .accessibilityValue(opening.journey.stage.caption)
    }

    /// Unified zero-conflict gesture handling both bidirectional left/right
    /// zipper sliding anywhere on the sleeve AND tapping directly on the red
    /// `"拆封"` pull-tab to smoothly unzip automatically.
    private func zipperGesture(width: CGFloat, height: CGFloat, tearY: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard interactive else { return }
                let dist = hypot(value.translation.width, value.translation.height)
                if dist > peakDragDistance { peakDragDistance = dist }
                let trackWidth = max(140, width - 92)
                if abs(value.translation.width) >= 4 || opening.journey.stage == .tearing {
                    opening.updateTear(
                        translationX: value.translation.width,
                        trackWidth: trackWidth,
                        reducedMotion: reducedMotion
                    )
                } else {
                    opening.updateSheen(
                        normalizedX: value.location.x / max(1, width),
                        normalizedY: value.location.y / max(1, height),
                        reducedMotion: reducedMotion
                    )
                }
            }
            .onEnded { value in
                let maxMoved = max(peakDragDistance, hypot(value.translation.width, value.translation.height))
                peakDragDistance = 0
                guard interactive else { return }
                let tabCenterX = OneTapeOpeningTearStrip.pullTabOriginX(
                    progress: opening.tearProgress,
                    width: width
                ) + 42
                let tappedTab = maxMoved < 14
                    && abs(value.startLocation.x - tabCenterX) <= 84
                    && abs(value.startLocation.y - tearY) <= 60
                if tappedTab {
                    onCommitUnwrap()
                    return
                }
                let trackWidth = max(140, width - 92)
                opening.endTear(
                    predictedTranslationX: value.predictedEndTranslation.width,
                    trackWidth: trackWidth,
                    reducedMotion: reducedMotion
                )
            }
    }
}

/// Subtle deck settling transform applied while the frosted sleeve unzips.
struct OneTapeOpeningCassetteTransform: ViewModifier {
    let pose: OneTapeOpeningPlayerPose?
    let windowSize: CGSize

    func body(content: Content) -> some View {
        let scale = pose?.deckScale ?? 1
        content.scaleEffect(scale, anchor: .center)
    }
}
