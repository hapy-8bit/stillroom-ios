import SwiftUI

/// An in-place turntable scene. Gestures operate the existing player; no second audio state is held here.
struct PlayerScreen: View {
    @EnvironmentObject private var player: PlayerStore
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.roomMotionVisible) private var motionVisible
    let origin: SleeveFlightOrigin?
    @State private var progress = 0.0
    @State private var ready = false
    @State private var ignoreTapUntil = Date.distantPast
    @GestureState private var interactionActive = false
    @State private var outgoing: Track?
    @State private var outgoingFraction = 0.0
    @State private var swapProgress = 1.0
    @State private var swapID: UUID?
    @State private var swapStarted = Date.distantPast
    @State private var requestedDirection = 1
    @State private var swapDirection = 1
    private var reducedMotion: Bool { player.reducedMotion || systemReducedMotion }
    private var visualSample: PlayerVisualSample {
        PlayerVisualSample(trackID: player.current.id, position: player.position, duration: player.duration)
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = PlayerStageGeometry(size: geometry.size)
            let track = player.current
            ZStack {
                PlayerRecordStage(track: track, artwork: player.artworks[track.id],
                                  playing: player.isPlaying, position: player.position, duration: player.duration,
                                  reducedMotion: reducedMotion, onSeek: { seconds in
                                      // A track switch cancels the old arm gesture instead of seeking the new song.
                                      if player.current.id == track.id { player.seek(seconds) }
                                  },
                                  origin: origin, progress: progress, swapProgress: swapProgress,
                                  outgoing: outgoing, outgoingArtwork: outgoing.flatMap { player.artworks[$0.id] },
                                  outgoingFraction: outgoingFraction, swapDirection: swapDirection, ready: ready,
                                  onToggle: { if Date.now >= ignoreTapUntil { player.toggle() } },
                                  onAlbums: { player.presentAlbums() },
                                  onFavorite: { player.toggleFavorite(track) }, onClose: close,
                                  onSkip: skip, onShuffle: player.toggleShuffle, onRepeat: player.cycleRepeat,
                                  shuffled: player.queue.shuffled, repeatTitle: player.queue.repeatMode.label,
                                  favorite: player.favorites.contains(player.current.id))
            }
            .contentShape(Rectangle())
            .simultaneousGesture(DragGesture(minimumDistance: 18)
                .updating($interactionActive) { _, active, _ in active = true }
                .onChanged { _ in
                // A swipe is a navigation/seek gesture, not a subsequent play/pause tap.
                if ready { ignoreTapUntil = .distantFuture }
            }.onEnded { value in
                guard ready else { return }
                // Suppress only the drag's release event, not a new intentional tap immediately after it.
                ignoreTapUntil = Date.now.addingTimeInterval(0.08)
                // Ignore a drag that began on the tonearm: its own vertical gesture seeks audio.
                switch QuietPlayerGesture.resolve(x: value.translation.width, y: value.translation.height,
                                                  predictedY: value.predictedEndTranslation.height,
                                                  width: geometry.size.width, height: geometry.size.height,
                                                  startsOnArm: layout.tonearm.insetBy(dx: -8, dy: -8).contains(value.startLocation)) {
                case .dismiss: close()
                case .next: skip(1)
                case .previous: skip(-1)
                case .none: break
                }
            })
            .accessibilityAction(.escape) { close() }
            .accessibilityIdentifier("player.quiet-scene")
        }
        .onChange(of: interactionActive) { _, active in
            if !active { ignoreTapUntil = Date.now.addingTimeInterval(0.08) }
        }
        .onChange(of: visualSample) { previous, next in
            guard previous.trackID != next.trackID else { return }
            guard ready, motionVisible, scenePhase == .active else { outgoing = nil; return }
            // On rapid input, keep the dominant visual and cancel the older completion task.
            // Only artwork and needle pose are retained; every control still targets PlayerStore.current.
            let retainOutgoing = outgoing != nil && Date.now.timeIntervalSince(swapStarted) < TrackChangeMotion.duration * 0.45
            if !retainOutgoing {
                outgoing = player.tracks.first { $0.id == previous.trackID }
                outgoingFraction = MediaTime.clamped(previous.position, duration: previous.duration) / max(1, previous.duration)
            }
            if outgoing?.id == next.trackID { outgoing = nil }
            swapDirection = requestedDirection
            requestedDirection = 1
            swapStarted = .now
            swapProgress = 0
            swapID = UUID()
        }
        .task(id: swapID) {
            guard let request = swapID, outgoing != nil else { return }
            let duration = reducedMotion ? 0.18 : TrackChangeMotion.duration
            withAnimation(.linear(duration: duration)) { swapProgress = 1 }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, swapID == request else { return }
            outgoing = nil
        }
        .task {
            // Only visual readiness waits for this timeline. Audio has already started in PlayerStore.
            // Dismissal cancels this task so completion cannot affect a later entry.
            let duration = reducedMotion ? 0.18 : (origin == nil ? 1.05 : TurntableJourneyPose.duration)
            withAnimation(.linear(duration: duration)) { progress = 1 }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            ready = true
        }
    }

    private func close() { player.showingPlayer = false }
    private func skip(_ delta: Int) { requestedDirection = delta < 0 ? -1 : 1; player.skip(delta) }
}

private struct PlayerVisualSample: Equatable {
    let trackID: String
    let position: Double
    let duration: Double
}
