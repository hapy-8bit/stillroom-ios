import SwiftUI

struct OrbitTurntableView: View {
    let presentation: OrbitPlaybackPresentation
    let style: OrbitRecordStyle
    let active: Bool
    var armLight: OrbitArmLight = .off
    var inputEnabled = true
    var onSkip: (Int) -> Void
    var onToggle: () -> Void
    @State private var displayedIdentity: String?
    @State private var displayedRevision: Int?
    @State private var texture: UIImage?
    @State private var installedPrintKey: String?
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var lifted = false
    @State private var drag = OrbitRecordDrag()
    @State private var requestedDirection = 0
    @State private var skipRequest = 0
    @GestureState private var dragging = false

    private var acceptsInput: Bool { active && inputEnabled && presentation.libraryReady && !presentation.albums.isEmpty }
    private var owner: String { "\(presentation.selectionRevision)|\(presentation.current.id)|\(presentation.recordIdentity)" }
    private var motionKey: String { "\(owner)|\(active)|\(presentation.reducedMotion)" }
    private var printKey: String {
        OrbitTurntableTexture.key(track: presentation.displayTrack, artwork: presentation.displayArtwork,
                                  style: style, session: presentation.craftedSession)
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = OrbitTurntableGeometry(size: geometry.size)
            ZStack(alignment: .topLeading) {
                record(side: layout.record.width)
                    .offset(x: offset).opacity(opacity)
                    .position(x: layout.record.midX, y: layout.record.midY)
                Circle().fill(LinearGradient(colors: [Color(white: 0.89), Color(white: 0.39), Color(white: 0.72)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().strokeBorder(.black.opacity(0.55), lineWidth: 1))
                    .frame(width: max(5, layout.record.width * 0.012), height: max(5, layout.record.width * 0.012))
                    .position(x: layout.record.midX, y: layout.record.midY)
                    .opacity(opacity).allowsHitTesting(false).accessibilityHidden(true)
                OrbitPickupArm(fraction: presentation.needleFraction, raised: lifted || !presentation.playing,
                               reducedMotion: presentation.reducedMotion, light: armLight)
                    .frame(width: layout.arm.width, height: layout.arm.height)
                    .position(x: layout.arm.midX, y: layout.arm.midY)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .task(id: motionKey + "|" + printKey) { await transition(width: geometry.size.width) }
                .task(id: skipRequest) {
                    guard skipRequest > 0 else { return }
                    // Local skip commits selection synchronously. A queue boundary that keeps
                    // this revision must still return the discarded drag to its resting anchor.
                    await Task.yield()
                    guard !Task.isCancelled, displayedRevision == presentation.selectionRevision else { return }
                    if requestedDirection != 0 {
                        requestedDirection = 0
                        returnToCenter()
                    }
                }
        }
        .task(id: dragging) {
            guard !dragging else { return }
            await Task.yield()
            guard !Task.isCancelled, !dragging else { return }
            drag.cancel()
        }
        .onChange(of: motionKey) { _, _ in drag.cancel(blockUntilRelease: dragging) }
        .onChange(of: inputEnabled) { _, enabled in
            if !enabled { drag.cancel(blockUntilRelease: dragging); returnToCenter() }
        }
        .onDisappear { drag.cancel() }
        .accessibilityElement(children: .contain).accessibilityIdentifier("orbit.turntable")
    }

    private func record(side: CGFloat) -> some View {
        ZStack {
            if presentation.albums.isEmpty {
                OrbitVinylSurface(track: presentation.displayTrack, artwork: nil, material: .black)
            } else if let texture {
                CompositedRecordSurface(image: texture,
                    running: active && presentation.playing && !presentation.reducedMotion && !dragging && !lifted)
            } else {
                OrbitDiscArtwork(track: presentation.displayTrack, artwork: presentation.displayArtwork, style: style)
            }
        }.frame(width: side, height: side)
            .shadow(color: .black.opacity(0.3), radius: 7, x: 1, y: 7)
            .contentShape(Circle()).gesture(recordDrag)
            .onTapGesture { if acceptsInput { onToggle() } }
            .allowsHitTesting(inputEnabled)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.albums.isEmpty ? "空唱片" : "\(presentation.displayRecordTitle)，唱片")
            .accessibilityValue(presentation.playing ? "正在转动" : "已暂停")
            .accessibilityHint("双击播放或暂停；左右拖动切歌")
            .accessibilityAddTraits(.isButton).accessibilityIdentifier("orbit.turntable.record")
            .accessibilityAdjustableAction { direction in
                guard acceptsInput else { return }
                if direction == .increment, presentation.canSkipNext { requestSkip(1) }
                if direction == .decrement, presentation.canSkipPrevious { requestSkip(-1) }
            }
    }

    private var recordDrag: some Gesture {
        // Recovered normal-scene minimum distance and coordinate space; this gesture
        // never converts rotation into media seconds. Arm seeking is a separate surface.
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .updating($dragging) { _, state, _ in state = true }
            .onChanged { value in
                guard acceptsInput, !lifted else { return }
                drag.update(owner: owner, x: value.translation.width, y: value.translation.height)
                offset = drag.translationX
            }
            .onEnded { value in
                let result = drag.finish(owner: owner, predictedX: value.predictedEndTranslation.width,
                    active: acceptsInput, canSkipNext: presentation.canSkipNext,
                    canSkipPrevious: presentation.canSkipPrevious)
                if let result { requestSkip(result) } else { returnToCenter() }
            }
    }

    private func requestSkip(_ direction: Int) {
        requestedDirection = direction
        skipRequest += 1
        onSkip(direction)
    }

    private func returnToCenter() {
        if presentation.reducedMotion { offset = 0 }
        else { withAnimation(.easeOut(duration: 0.24)) { offset = 0 } }
    }

    /// Audio selection already belongs to PlayerStore. This task owns only its old print
    /// and visual handoff; replacing the revision cancels superseded waits.
    @MainActor private func transition(width: CGFloat) async {
        let replacing = displayedIdentity != nil && displayedIdentity != presentation.recordIdentity
        let selected = displayedRevision != presentation.selectionRevision
        let draggedChange = selected && requestedDirection != 0
        let explicitReplacement = selected && presentation.transition == .replace && presentation.craftedSession == nil
        guard active, !presentation.reducedMotion else {
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { installPrint(); offset = 0; opacity = 1; lifted = false; requestedDirection = 0 }
            return
        }
        if replacing || explicitReplacement || draggedChange {
            let direction = requestedDirection == -1 ? -1.0 : 1.0
            requestedDirection = 0
            lifted = true
            // Observed direction/order: outgoing first, incoming from the opposite edge.
            // Durations are local presentation values, not a recovered audio-commit clock.
            withAnimation(.easeIn(duration: 0.22)) { offset = -direction * width * 1.6 }
            do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
            guard !Task.isCancelled else { return }
            installPrint()
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { offset = direction * width * 1.6 }
            do { try await Task.sleep(for: .milliseconds(160)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.38)) { offset = 0; opacity = 1 }
            do { try await Task.sleep(for: .milliseconds(380)) } catch { return }
            guard !Task.isCancelled else { return }
            lifted = false
        } else if selected && (presentation.transition == .relocate || presentation.transition == .replace) {
            lifted = true; installPrint(); offset = 0; opacity = 1
            do { try await Task.sleep(for: .milliseconds(280)) } catch { return }
            guard !Task.isCancelled else { return }
            lifted = false
        } else {
            installPrint(); offset = 0; opacity = 1; lifted = false
        }
    }

    @MainActor private func installPrint() {
        if installedPrintKey != printKey || texture == nil {
            texture = OrbitTurntableTexture.render(track: presentation.displayTrack, artwork: presentation.displayArtwork,
                                                   style: style, session: presentation.craftedSession)
            installedPrintKey = printKey
        }
        displayedIdentity = presentation.recordIdentity
        displayedRevision = presentation.selectionRevision
    }
}
