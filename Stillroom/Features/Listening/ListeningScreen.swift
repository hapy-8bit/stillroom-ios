import SwiftUI

struct ListeningScreen: View {
    @EnvironmentObject private var player: PlayerStore
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    @Environment(\.roomMotionVisible) private var roomMotionVisible
    @State private var offset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .top)
    let artworkTransition: Namespace.ID
    let onRecord: (SleeveFlightOrigin) -> Void
    private var reducedMotion: Bool { player.reducedMotion || systemReducedMotion }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let travel = max(1, height * 0.86)
            let transitionOffset = min(offset, travel)
            let pose = ListeningPose(progress: offset / travel, reducedMotion: reducedMotion)
            ZStack {
                RoomBackground()
                ScrollView {
                    ZStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Stillroom").font(.custom("Damion", size: 43))
                                Spacer()
                                Text("留一点时间给音乐").font(.system(size: 10)).tracking(1).foregroundStyle(RoomStyle.secondary)
                            }
                            SectionEyebrow(text: "A ROOM FOR LISTENING")
                        }.padding(.horizontal, 26).padding(.top, 18)
                            .offset(y: transitionOffset).opacity(pose.hintOpacity)

                        SleeveDissolveView(track: player.current, artwork: player.artworks[player.current.id],
                                           progress: pose.dissolve, reducedMotion: reducedMotion, artworkTop: 108,
                                           viewportSize: CGSize(width: width, height: height),
                                           onPlayer: { origin in player.play(); onRecord(origin) },
                                           onShelf: { player.presentAlbums() }, artworkTransition: artworkTransition,
                                           recordPresented: player.showingPlayer, albumPresented: player.showingShelf)
                            .frame(width: width, height: height).offset(y: transitionOffset)
                            .opacity(pose.artworkOpacity).allowsHitTesting(offset < travel * 0.15)

                        VStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Text(player.current.title).font(RoomStyle.serif(23)).foregroundStyle(RoomStyle.paper)
                                Text(player.current.artist).font(.system(size: 11)).foregroundStyle(RoomStyle.secondary)
                            }
                            HStack(spacing: 12) {
                                Button {
                                    player.toggle()
                                } label: {
                                    Label(player.isPlaying ? "暂停片刻" : "落针播放", systemImage: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 12, weight: .medium)).padding(.horizontal, 24).frame(height: 44)
                                        .background(RoomStyle.paper, in: Capsule()).foregroundStyle(RoomStyle.background)
                                }.buttonStyle(.plain).accessibilityIdentifier("listen.play")
                                Button("挑一张唱片") { player.presentAlbums() }
                                    .font(.system(size: 12)).foregroundStyle(RoomStyle.secondary).frame(minHeight: 44)
                            }
                            Button {
                                withAnimation(.easeInOut(duration: reducedMotion ? 0.25 : 0.8)) { scrollPosition.scrollTo(y: travel) }
                            } label: {
                                VStack(spacing: 7) {
                                    Image(systemName: "chevron.up").font(.system(size: 11))
                                    Text("向上轻扫 · 随手听听").font(.system(size: 10)).tracking(1.5)
                                }.foregroundStyle(RoomStyle.muted).frame(minHeight: 44)
                            }.buttonStyle(.plain).accessibilityIdentifier("listen.reveal")
                        }.offset(y: min(height - 180, 104 + width * 0.83) + transitionOffset).opacity(pose.hintOpacity)
                            .allowsHitTesting(pose.hintOpacity > 0.5)

                        ListeningHome(width: width) {
                            withAnimation(.easeInOut(duration: reducedMotion ? 0.25 : 0.8)) { scrollPosition.scrollTo(y: 0) }
                        }.environment(\.roomMotionVisible, roomMotionVisible && pose.controller > 0.95)
                            .frame(width: width).frame(minHeight: height, alignment: .top)
                            .padding(.top, travel)
                            // During the reveal, compensate for scrolling to keep the original entry trajectory.
                            // At the endpoint this offset is zero and the same content scrolls normally.
                            .offset(y: transitionOffset - travel + (reducedMotion ? 0 : (1 - pose.controller) * height * 0.8))
                            .opacity(pose.controller).allowsHitTesting(pose.controller > 0.95)
                    }.frame(width: width, alignment: .top)
                }
                .scrollIndicators(.hidden).scrollPosition($scrollPosition).scrollBounceBehavior(.basedOnSize)
                .scrollTargetBehavior(ListeningScrollBehavior(travel: travel))
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                } action: { _, value in offset = value }
                .accessibilityIdentifier("listen.scene")
            }
        }
    }
}

private struct ListeningScrollBehavior: ScrollTargetBehavior {
    let travel: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.y = ListeningScrollDestination.resolve(proposed: target.rect.minY,
                                                                 origin: context.originalTarget.rect.minY, travel: travel)
    }
}

