import SwiftUI

/// The caller owns playback and all delayed work. This view only draws the selected record,
/// previews the user's arm position and forwards explicit needle/pause actions.
struct RecordOpeningDeck: View {
    let track: Track
    let artwork: UIImage?
    let reveal: Double
    let playerProgress: Double
    let ready: Bool
    let playing: Bool
    let cueing: Bool
    let active: Bool
    let reducedMotion: Bool
    let onNeedle: () -> Void
    let onPause: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    @State private var texture: UIImage?
    @State private var installedTextureKey: String?
    @State private var dragOwner: String?
    @State private var initialAngle = 0.0
    @State private var blockedUntilRelease = false
    @GestureState private var translation: CGFloat = 0
    @GestureState private var armDragging = false

    private var motionReduced: Bool { reducedMotion || systemReducedMotion }
    private var phase: Double { RecordOpeningGeometry.clampedProgress(playerProgress) }
    private var opacity: Double { RecordOpeningGeometry.clampedProgress(reveal) }
    private var canInteract: Bool { ready && active }
    private var style: OrbitRecordStyle { OrbitRecordStyle(material: .black) }
    private var textureKey: String {
        OrbitTurntableTexture.key(track: track, artwork: artwork, style: style, session: nil)
    }
    private var interactionKey: String { "\(track.id)|\(ready)|\(active)|\(playing)|\(cueing)" }

    var body: some View {
        GeometryReader { geometry in
            let layout = OrbitTurntableGeometry(size: geometry.size, safeTop: geometry.safeAreaInsets.top,
                                               safeBottom: geometry.safeAreaInsets.bottom)
            let frame = RecordOpeningGeometry.interpolatedFrame(
                from: OpeningShelfPreviewLayout(size: geometry.size).openFrame,
                to: layout.record, progress: phase)
            ZStack(alignment: .topLeading) {
                disc(side: frame.width)
                    .position(x: frame.midX, y: frame.midY)
                    .opacity(opacity)
                spindle(side: frame.width)
                    .position(x: frame.midX, y: frame.midY)
                    .opacity(opacity)
                arm(layout: layout, viewport: geometry.size)
                    .opacity(phase * opacity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .task(id: textureKey) { await installTexture() }
        .task(id: armDragging) {
            guard !armDragging else { return }
            // System cancellation has no onEnded callback. Yield so ordinary release can commit
            // first; this lifecycle-bound cleanup then releases cancelled gesture ownership.
            await Task.yield()
            guard !Task.isCancelled, !armDragging else { return }
            dragOwner = nil
            blockedUntilRelease = false
        }
        .onChange(of: interactionKey) { _, _ in
            blockedUntilRelease = armDragging
            dragOwner = nil
        }
        .onDisappear { dragOwner = nil }
        .transaction { if motionReduced { $0.animation = nil } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordOpening.deck")
    }

    private func disc(side: CGFloat) -> some View {
        ZStack {
            if installedTextureKey == textureKey, let texture {
                CompositedRecordSurface(image: texture, running: playing && active && !motionReduced)
            } else {
                OrbitDiscArtwork(track: track, artwork: artwork, style: style)
            }
        }
        .frame(width: side, height: side)
        .shadow(color: .black.opacity(0.28), radius: side * 0.018, x: 1, y: side * 0.015)
        .contentShape(Circle())
        .onTapGesture(perform: activate)
        .allowsHitTesting(canInteract)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(track.album + "，黑胶唱片")
        .accessibilityValue(playing ? "正在播放" : cueing ? "正在落针" : "尚未播放")
        .accessibilityHint(playing || cueing ? "双击暂停并收针" : "双击落针播放")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { activate() }
        .accessibilityHidden(!ready)
        .accessibilityIdentifier("recordOpening.disc")
    }

    private func spindle(side: CGFloat) -> some View {
        Circle()
            .fill(LinearGradient(colors: [Color(white: 0.89), Color(white: 0.39), Color(white: 0.72)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Circle().strokeBorder(.black.opacity(0.55), lineWidth: 1))
            .frame(width: max(5, side * 0.012), height: max(5, side * 0.012))
            .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func arm(layout: OrbitTurntableGeometry, viewport: CGSize) -> some View {
        let ownsDrag = dragOwner == interactionKey
        let lever = max(1, layout.arm.height * OpeningNeedlePreview.leverRatio)
        let preview = ownsDrag ? OpeningNeedlePreview.angle(initial: initialAngle,
            horizontalTranslation: translation, lever: lever) : nil
        // The hit region includes the headshell's inward travel, not just the thin silver rod.
        let hitWidth = max(44, layout.arm.width * OpeningNeedlePreview.hitWidthRatio)
        let hitHeight = max(44, layout.arm.height * OpeningNeedlePreview.hitHeightRatio)
        let hitX = layout.arm.midX - layout.arm.width * 0.20
        let hitY = layout.arm.minY + layout.arm.height * 0.63

        return ZStack(alignment: .topLeading) {
            OrbitPickupArm(fraction: 0, raised: !(playing || cueing), reducedMotion: motionReduced,
                           previewAngle: preview)
                .frame(width: layout.arm.width, height: layout.arm.height)
                .position(x: layout.arm.midX, y: layout.arm.midY)
            Color.clear
                .frame(width: hitWidth, height: hitHeight)
                .contentShape(Rectangle())
                .position(x: hitX, y: hitY)
                .gesture(armGesture(threshold: OpeningNeedlePreview.commitDistance(width: viewport.width)))
                .onTapGesture(perform: activate)
                .allowsHitTesting(canInteract)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("唱臂")
                .accessibilityValue(playing ? "已落针，正在播放" : cueing ? "正在落针" : "已停放")
                .accessibilityHint("向左拖动落针；向右拖动或双击收针暂停")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { activate() }
                .accessibilityAction(named: "落针播放") { if canInteract { onNeedle() } }
                .accessibilityAction(named: "收针暂停") { if canInteract { onPause() } }
                .accessibilityHidden(!ready)
                .accessibilityIdentifier("recordOpening.arm")
        }
    }

    private func armGesture(threshold: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .updating($armDragging) { _, state, _ in state = true }
            .updating($translation) { value, state, transaction in
                guard canInteract, !blockedUntilRelease else { return }
                transaction.animation = nil
                state = value.translation.width
            }
            .onChanged { _ in
                guard canInteract, !blockedUntilRelease else { return }
                if dragOwner == nil {
                    dragOwner = interactionKey
                    initialAngle = playing || cueing ? OpeningNeedlePreview.landedAngle : 0
                }
            }
            .onEnded { value in
                defer { dragOwner = nil; blockedUntilRelease = false }
                guard canInteract, !blockedUntilRelease, dragOwner == interactionKey else { return }
                if value.translation.width <= -threshold, !playing, !cueing { onNeedle() }
                else if value.translation.width >= threshold, playing || cueing { onPause() }
            }
    }

    private func activate() {
        guard canInteract else { return }
        if playing || cueing { onPause() }
        else { onNeedle() }
    }

    @MainActor private func installTexture() async {
        let key = textureKey
        guard installedTextureKey != key || texture == nil else { return }
        // Rendering happens once per selected print, not per media tick or animated geometry.
        // The task belongs to this view identity; a replaced selection cannot install an old print.
        await Task.yield()
        guard !Task.isCancelled else { return }
        texture = OrbitTurntableTexture.render(track: track, artwork: artwork, style: style, session: nil)
        installedTextureKey = key
    }
}

/// Explicit preview interaction inputs in logical points/degrees. These thresholds and the
/// linear drag gain are usability choices; the reference's drag/landing rule is not yet proven.
private enum OpeningNeedlePreview {
    static let landedAngle = 11.0
    static let maximumAngle = 28.0
    static let leverRatio: CGFloat = 0.80
    static let hitWidthRatio: CGFloat = 1.6
    static let hitHeightRatio: CGFloat = 0.65
    static let commitWidthRatio: CGFloat = 0.075

    static func commitDistance(width: CGFloat) -> CGFloat {
        max(18, min(56, width * commitWidthRatio))
    }

    static func angle(initial: Double, horizontalTranslation: CGFloat, lever: CGFloat) -> Double {
        min(maximumAngle, max(0, initial - Double(horizontalTranslation / lever) * 180 / .pi))
    }
}
