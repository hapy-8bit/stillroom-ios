import SwiftUI

struct ProgressScrubber: View {
    let position: Double
    let duration: Double
    let onSeek: (Double) -> Void
    @GestureState private var preview: Double?
    private var current: Double { MediaTime.clamped(preview ?? position, duration: duration) }

    var body: some View {
        GeometryReader { geometry in
            let inset: CGFloat = 5
            let travel = max(1, geometry.size.width - inset * 2)
            let fraction = duration > 0 ? current / duration : 0
            ZStack(alignment: .leading) {
                Capsule().fill(RoomStyle.paper.opacity(0.15)).frame(height: 2)
                Capsule().fill(RoomStyle.paper.opacity(0.85)).frame(width: travel * fraction, height: 2)
                Circle().fill(RoomStyle.paper).frame(width: 8, height: 8)
                    .offset(x: travel * fraction - 4)
            }.padding(.horizontal, inset).frame(height: 44).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).updating($preview) { value, state, _ in
                    // Points map to seconds. GestureState also clears a canceled/interrupted
                    // preview, so the displayed position returns to the authoritative engine.
                    state = MediaTime.clamped((value.location.x - inset) / travel * duration, duration: duration)
                }.onEnded { value in
                    onSeek(MediaTime.clamped((value.location.x - inset) / travel * duration, duration: duration))
                })
        }.frame(height: 44)
            .accessibilityElement(children: .ignore).accessibilityLabel("播放进度")
            .accessibilityValue("\(MediaTime.label(current)) / \(MediaTime.label(duration))")
            .accessibilityAdjustableAction { direction in
                onSeek(MediaTime.clamped(position + (direction == .increment ? 5 : -5), duration: duration))
            }
            .accessibilityIdentifier("player.progress")
    }
}

