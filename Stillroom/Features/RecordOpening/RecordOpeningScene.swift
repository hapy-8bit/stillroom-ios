import SwiftUI

/// A record-opening page. Albums and playback facts arrive from the existing state owner;
/// selection stays visual until an explicit needle action submits a cancellable play request.
struct RecordOpeningScene: View {
    let albums: [Track]
    let artworks: [String: UIImage]
    let playingTrackID: String
    let playing: Bool
    let preparing: Bool
    let libraryReady: Bool
    let reducedMotion: Bool
    let onPlay: (Track) -> Void
    let onPause: () -> Void
    let onFinish: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    @StateObject private var controller = RecordOpeningController()
    @StateObject private var gravity = OpeningGravitySource()
    @State private var experiencedPlayback = false

    private var motionReduced: Bool { reducedMotion || systemReducedMotion }
    private var selected: Track? {
        albums.first { $0.id == controller.journey.selectedTrackID }
    }
    private var selectedPlaying: Bool { selected?.id == playingTrackID && playing }
    private var selectedPreparing: Bool { selected?.id == playingTrackID && preparing }
    private var ready: Bool { controller.journey.stage == .ready }
    private var readsGravity: Bool {
        scenePhase == .active && !motionReduced && controller.journey.selectedTrackID == nil
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                if let selected {
                    RecordOpeningDeck(track: selected, artwork: artworks[selected.id],
                        reveal: controller.reveal, playerProgress: controller.playerProgress,
                        ready: ready && libraryReady, playing: selectedPlaying,
                        cueing: controller.cueing || selectedPreparing,
                        active: scenePhase == .active, reducedMotion: motionReduced,
                        onNeedle: lowerNeedle, onPause: pause)
                }
                RecordOpeningShelf(albums: albums, artworks: artworks,
                    selectedTrackID: controller.journey.selectedTrackID,
                    openProgress: controller.openProgress, exitProgress: controller.exitProgress,
                    reducedMotion: motionReduced, gravityY: motionReduced ? 0 : gravity.gravityY, onSelect: select)
                    .allowsHitTesting(controller.journey.stage == .list)
                    .accessibilityHidden(controller.journey.stage != .list)
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 12)
                    footer(compact: geometry.size.height < 600)
                }.padding(.horizontal, 26).padding(.top, 12).padding(.bottom, 20)
                    // The enlarged disc reaches behind this overlay. Keep visible controls
                    // ahead of the shelf/deck gesture surfaces instead of passing Back to Play.
                    .zIndex(10)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .background {
            // Keep the atmosphere outside the clipped interaction viewport so status-bar and
            // home-indicator safe areas have the same surface as the record stage.
            GeometryReader { geometry in backdrop(size: geometry.size) }.ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordOpening.scene")
        .onAppear { gravity.setActive(readsGravity) }
        .onChange(of: readsGravity) { _, active in gravity.setActive(active) }
        .onChange(of: selectedPlaying) { _, value in if value { experiencedPlayback = true } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                controller.suspend()
                // The visual ticket may already have reached the engine's activation task.
                // Cancel that still-silent preparation as well, retaining established playback.
                if selectedPreparing { onPause() }
            }
        }
        .onChange(of: motionReduced) { _, value in if value { controller.suspend() } }
        .onDisappear {
            gravity.stop()
            let wasPreparing = selectedPreparing
            controller.reset()
            if wasPreparing { onPause() }
        }
    }

    private var header: some View {
        HStack {
            if selected != nil {
                Button {
                    if selectedPlaying || selectedPreparing { onPause() }
                    controller.reset()
                    experiencedPlayback = false
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("重新选唱片")
                    .accessibilityIdentifier("recordOpening.back")
            } else {
                Text("STILLROOM").font(.system(size: 10, weight: .semibold)).tracking(2)
                    .foregroundStyle(.white.opacity(0.45)).accessibilityHidden(true)
            }
            Spacer()
            Button("跳过") { skip() }.font(.system(size: 14)).foregroundStyle(.white.opacity(0.75))
                .frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("recordOpening.skip")
        }.foregroundStyle(.white)
    }

    private func footer(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 18) {
            if controller.journey.selectedTrackID == nil, let problem = gravity.problem {
                Text(problem).font(.caption).foregroundStyle(.white.opacity(0.65))
                    .accessibilityIdentifier("recordOpening.motionStatus")
            }
            if albums.isEmpty {
                Text("先把一张唱片放进来。").font(.title2.bold())
                Button("进入唱片室") { finish() }.buttonStyle(.borderedProminent)
            } else if controller.journey.stage == .list {
                Text("以唱片的方式，\n翻开你的音乐。")
                    .font(.system(size: compact ? 24 : 29, weight: .bold)).lineSpacing(4)
                Text("轻点一张封套，放进唱机。")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.62))
            } else if ready {
                Text(experiencedPlayback ? "把这一刻，留给音乐。" : "轻轻移动唱臂，\n让音乐响起。")
                    .font(.system(size: compact ? 22 : 27, weight: .bold)).lineSpacing(4)
                if experiencedPlayback {
                    Button("进入唱片室") { finish() }
                        .buttonStyle(OpeningPrimaryButton())
                        .accessibilityIdentifier("recordOpening.continue")
                } else {
                    Button(action: lowerNeedle) {
                        HStack {
                            Text(!libraryReady ? "正在读取曲库" : controller.cueing ? "正在落针" : selectedPreparing ? "正在准备音乐" : "放下唱臂")
                            Spacer()
                            Image(systemName: "play.fill")
                        }
                    }.buttonStyle(OpeningPrimaryButton())
                        .disabled(!libraryReady || controller.cueing || selectedPreparing || scenePhase != .active)
                        .accessibilityIdentifier("recordOpening.play")
                }
            } else {
                Text("打开这一张，\n听见它的声音。")
                    .font(.system(size: compact ? 22 : 27, weight: .bold)).lineSpacing(4)
                    .opacity(0.65)
            }
        }.foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("recordOpening.instructions")
    }

    private func backdrop(size: CGSize) -> some View {
        ZStack {
            Color(white: 0.035)
            if let selected {
                ArtworkView(track: selected, image: artworks[selected.id])
                    .frame(width: max(size.width, size.height), height: max(size.width, size.height))
                    .scaleEffect(1.25).blur(radius: 70).opacity(0.50)
                Color.black.opacity(0.42)
            }
        }.frame(width: size.width, height: size.height)
            .animation(motionReduced ? nil : .easeInOut(duration: 0.45), value: selected?.id)
            .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func select(_ track: Track) {
        experiencedPlayback = false
        controller.select(trackID: track.id, reducedMotion: motionReduced)
    }

    private func lowerNeedle() {
        guard ready, libraryReady, !selectedPlaying, !selectedPreparing, scenePhase == .active else { return }
        controller.requestPlayback { trackID in
            guard let track = albums.first(where: { $0.id == trackID }) else { return }
            onPlay(track)
        }
    }

    private func pause() {
        controller.cancelPlayback()
        if selectedPlaying || selectedPreparing { onPause() }
    }

    private func finish() {
        controller.reset()
        onFinish()
    }

    private func skip() {
        controller.cancelPlayback()
        // A skipped scene must not start sounding later if the engine is still activating.
        // Already-playing music is retained when continuing into the ordinary player.
        if selectedPreparing { onPause() }
        finish()
    }
}

private struct OpeningPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 22).foregroundStyle(.black)
            .background(.white.opacity(configuration.isPressed ? 0.78 : 1), in: Capsule())
    }
}
