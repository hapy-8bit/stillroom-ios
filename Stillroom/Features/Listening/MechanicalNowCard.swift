import SwiftUI

/// One mechanical readout of the canonical player snapshot; the apertures are drawn by the housing.
struct MechanicalNowCard: View {
    let track: Track
    let artwork: UIImage?
    let playing: Bool
    let position: Double
    let duration: Double
    let ordinal: Int
    let total: Int
    let reducedMotion: Bool
    let onOpen: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void
    @Environment(\.roomMotionVisible) private var motionVisible
    private var quietMotion: Bool { reducedMotion || !motionVisible }

    private var readout: MechanicalPlaybackReadout {
        MechanicalPlaybackReadout(position: position, duration: duration, ordinal: ordinal, total: total)
    }

    var body: some View {
        VStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 6) {
                Text("STILLROOM").font(.system(size: 10, weight: .black)).tracking(3.5).foregroundStyle(MechanicalCardStyle.text)
                HStack(spacing: 6) {
                    Circle().fill(playing ? RoomStyle.accent : RoomStyle.muted).frame(width: 4, height: 4)
                    Text(playing ? "正在播放" : "已暂停").font(.system(size: 8)).foregroundStyle(MechanicalCardStyle.text.opacity(0.6))
                }
            }.frame(maxWidth: .infinity, alignment: .leading).frame(height: 65, alignment: .bottom)
            HStack(spacing: 8) {
                MechanicalCounterWindow(value: String(format: "%02d", readout.ordinal), numericValue: Double(readout.ordinal),
                                        caption: "共 \(readout.total) 首", identifier: "home.counter.track", reducedMotion: quietMotion,
                                        accessibilityText: readout.trackLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                MechanicalRivet()
                MechanicalCounterWindow(value: readout.elapsedLabel, numericValue: floor(readout.elapsed),
                                        caption: "已播放", identifier: "home.counter.elapsed", reducedMotion: quietMotion)
                    .frame(maxWidth: .infinity)
                MechanicalRivet()
                MechanicalCounterWindow(value: readout.remainingLabel, numericValue: floor(readout.remaining),
                                        caption: "剩余", identifier: "home.counter.remaining", reducedMotion: quietMotion)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            HStack(spacing: 8) {
                Button(action: onOpen) {
                    HStack(spacing: 9) {
                        ArtworkView(track: track, image: artwork).frame(width: 25, height: 25)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(track.title).font(.system(size: 13, weight: .medium)).foregroundStyle(MechanicalCardStyle.text)
                                .lineLimit(1).accessibilityIdentifier("home.current-title")
                                .contentTransition(.opacity)
                            Text(track.artist).font(.system(size: 9)).foregroundStyle(MechanicalCardStyle.text.opacity(0.6)).lineLimit(1)
                                .contentTransition(.opacity)
                        }
                        Spacer(minLength: 0)
                    }.frame(minHeight: 48).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("home.current")
                transport(symbol: playing ? "pause.fill" : "play.fill", action: onToggle)
                    .accessibilityLabel(playing ? "暂停" : "播放").accessibilityIdentifier("home.play")
                transport(symbol: "forward.end.fill", action: onNext)
                    .accessibilityLabel("下一首").accessibilityIdentifier("home.next")
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
        .background {
            MechanicalHousing(elapsed: readout.elapsed, remaining: readout.remaining, playing: playing,
                              trackID: track.id, reducedMotion: quietMotion)
        }
        .shadow(color: .black.opacity(0.4), radius: 7, y: 7)
    }

    private func transport(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium)).foregroundStyle(MechanicalCardStyle.text)
                .frame(width: 32, height: 32)
                .background(LinearGradient(colors: [Color(hex: 0x555557), Color(hex: 0x303032)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 0.6))
                .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
