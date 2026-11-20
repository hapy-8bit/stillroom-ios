import SwiftUI

/// The same record stays mounted through extraction and playback. A single interpolated
/// progress avoids a hero match across TabView's separate native hosting views.
struct PlayerRecordStage: View, Animatable {
    let track: Track
    let artwork: UIImage?
    let playing: Bool
    let position: Double
    let duration: Double
    let reducedMotion: Bool
    let onSeek: (Double) -> Void
    let origin: SleeveFlightOrigin?
    var progress: Double
    var swapProgress: Double
    let outgoing: Track?
    let outgoingArtwork: UIImage?
    let outgoingFraction: Double
    let swapDirection: Int
    let ready: Bool
    let onToggle: () -> Void
    let onAlbums: () -> Void
    let onFavorite: () -> Void
    let onClose: () -> Void
    let onSkip: (Int) -> Void
    let onShuffle: () -> Void
    let onRepeat: () -> Void
    let shuffled: Bool
    let repeatTitle: String
    let favorite: Bool

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, swapProgress) }
        set { progress = newValue.first; swapProgress = newValue.second }
    }

    private var tracks: [Track] { outgoing.map { [$0, track] } ?? [track] }

    var body: some View {
        GeometryReader { geometry in
            let layout = PlayerStageGeometry(size: geometry.size)
            let pose = TurntableJourneyPose(progress: progress, origin: origin,
                                            container: geometry.frame(in: .global), reducedMotion: reducedMotion)
            let swap = TrackChangeMotion(progress: swapProgress, direction: swapDirection, reducedMotion: reducedMotion)
            ZStack(alignment: .topLeading) {
                ZStack {
                    ForEach(tracks) { item in
                        TurntableBackdrop(track: item, artwork: item.id == track.id ? artwork : outgoingArtwork).equatable()
                            .opacity(outgoing == nil ? 1 : (item.id == track.id ? swap.atmosphere : 1 - swap.atmosphere))
                    }
                }.opacity(pose.backdrop)
                Button(action: onToggle) {
                    ZStack {
                        ForEach(tracks) { item in
                            let incoming = item.id == track.id
                            VinylRecord(track: item, artwork: incoming ? artwork : outgoingArtwork,
                                        running: incoming && playing && pose.placed && (outgoing == nil || swap.needle > 0.95),
                                        reducedMotion: reducedMotion, studio: true)
                                .frame(width: pose.record.width, height: pose.record.height)
                                .scaleEffect(outgoing == nil ? 1 : (incoming ? swap.incomingScale : swap.outgoingScale))
                                .offset(x: outgoing == nil ? 0 : pose.record.width * (incoming ? swap.incomingX : swap.outgoingX))
                                .opacity(outgoing == nil ? 1 : (incoming ? swap.incomingOpacity : swap.outgoingOpacity))
                        }
                    }.frame(width: pose.record.width, height: pose.record.height).contentShape(Circle())
                }.buttonStyle(.plain)
                    .accessibilityLabel((playing ? "暂停，" : "播放，") + track.title)
                    .accessibilityValue("\(playing ? "播放中" : "已暂停")，\(MediaTime.label(position)) / \(MediaTime.label(duration))")
                    .accessibilityHint("左右轻扫切歌，下滑返回；长按可选择专辑或收藏")
                    // A visible moving record is not an operable playback button until it is placed.
                    .accessibilityIdentifier(ready ? "player.record" : "player.record-in-flight")
                    .accessibilityAction(named: "返回封套") { onClose() }
                    .accessibilityAction(named: "下一首") { onSkip(1) }
                    .accessibilityAction(named: "上一首") { onSkip(-1) }
                    .contextMenu {
                        Button("选择专辑", systemImage: "square.stack", action: onAlbums).accessibilityIdentifier("player.shelf")
                        Button(favorite ? "取消喜欢" : "加入喜欢", systemImage: favorite ? "heart.fill" : "heart", action: onFavorite)
                            .accessibilityIdentifier("player.favorite")
                        Button("下一首", systemImage: "forward.end", action: { onSkip(1) })
                        Button(shuffled ? "关闭随机播放" : "开启随机播放", systemImage: "shuffle", action: onShuffle)
                        Button(repeatTitle, systemImage: "repeat", action: onRepeat)
                        Button("返回封套", systemImage: "chevron.down", action: onClose)
                            .accessibilityIdentifier("player.close")
                    } preview: {
                        // UIKit previews share neither the live clock nor its animated geometry.
                        VinylRecord(track: track, artwork: artwork, reducedMotion: true, studio: true)
                            .frame(width: 240, height: 240).padding(12)
                    }
                    .position(x: pose.record.midX, y: pose.record.midY).opacity(pose.recordOpacity)
                if origin != nil && !reducedMotion {
                    ArtworkView(track: track, image: artwork, printed: true)
                        .frame(width: pose.sleeve.width, height: pose.sleeve.height)
                        .overlay(Rectangle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                        .shadow(color: .black.opacity(0.45), radius: 14, x: 5, y: 16)
                        .rotationEffect(.degrees(pose.sleeveAngle))
                        .position(x: pose.sleeve.midX, y: pose.sleeve.midY)
                        .opacity(pose.sleeveOpacity).allowsHitTesting(false).accessibilityHidden(true)
                }
                TonearmView(playing: playing,
                            position: outgoing != nil && swapProgress < 0.16 ? outgoingFraction * duration : position,
                            duration: duration, reducedMotion: reducedMotion,
                            landing: pose.needle * (outgoing == nil ? 1 : swap.needle), onSeek: onSeek)
                    .id(track.id)
                    .frame(width: layout.tonearm.width, height: layout.tonearm.height)
                    .position(x: layout.tonearm.midX, y: layout.tonearm.midY).opacity(pose.armOpacity)
                    .accessibilityIdentifier("player.tonearm")
                VStack {
                    Spacer(minLength: 0)
                    TurntableTransport(track: track, playing: playing, outgoing: outgoing,
                                       titleProgress: outgoing == nil ? 1 : swap.atmosphere,
                                       onToggle: onToggle, onSkip: onSkip)
                        .padding(.bottom, max(32, geometry.safeAreaInsets.bottom + 12))
                }.opacity(pose.controls).offset(y: (1 - pose.controls) * 12)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.allowsHitTesting(ready).accessibilityHidden(!ready)
            .accessibilityElement(children: .contain).accessibilityIdentifier("player.stage")
    }
}
