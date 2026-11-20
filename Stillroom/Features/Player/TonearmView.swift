import SwiftUI

struct TonearmView: View {
    let playing: Bool
    let position: Double
    let duration: Double
    var reducedMotion = false
    var landing = 1.0
    let onSeek: (Double) -> Void
    @State private var dragStart: Double?
    @State private var preview: Double?

    private var fraction: Double { MediaTime.clamped(preview ?? position, duration: duration) / max(1, duration) }
    private var angle: Double {
        let target = playing || preview != nil ? -1 + fraction * 21 : -16
        return -16 + (target + 16) * min(1, max(0, landing))
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 120
            ZStack(alignment: .topLeading) {
                Circle().fill(LinearGradient(colors: [Color(hex: 0xB6BDB3), Color(hex: 0x434F49)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42 * scale, height: 42 * scale).position(x: 81 * scale, y: 30 * scale)
                arm(scale: scale)
                    .rotationEffect(.degrees(angle), anchor: UnitPoint(x: 81 / 120, y: 30 / 330))
                    .animation(preview == nil && !reducedMotion && landing >= 1 ? .easeInOut(duration: 0.7) : nil, value: angle)
                Circle().fill(Color(hex: 0x25342E)).frame(width: 17 * scale, height: 17 * scale)
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)).position(x: 81 * scale, y: 30 * scale)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 5).onChanged { value in
                if dragStart == nil { dragStart = position }
                // Translation is in logical points; preview is seconds and commits once at gesture end.
                preview = MediaTime.clamped((dragStart ?? position) + value.translation.height / max(1, 230 * scale) * duration,
                                            duration: duration)
            }.onEnded { _ in
                if let preview { onSeek(preview) }
                preview = nil
                dragStart = nil
            })
        }.aspectRatio(120 / 330, contentMode: .fit)
            .accessibilityLabel("唱臂，上下拖动定位播放进度")
            .accessibilityAdjustableAction { direction in onSeek(position + (direction == .increment ? 5 : -5)) }
    }

    private func arm(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: 81 * scale, y: 3 * scale))
                path.addLine(to: CGPoint(x: 81 * scale, y: 195 * scale))
                path.addQuadCurve(to: CGPoint(x: 61 * scale, y: 242 * scale), control: CGPoint(x: 81 * scale, y: 226 * scale))
                path.addLine(to: CGPoint(x: 29 * scale, y: 283 * scale))
            }.stroke(LinearGradient(colors: [Color(hex: 0x17191D), Color(hex: 0x626469), Color(hex: 0x23252A)],
                                    startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round))
                .shadow(color: .black.opacity(0.6), radius: 5, x: 4, y: 4)
            RoundedRectangle(cornerRadius: 5).fill(LinearGradient(colors: [Color(hex: 0xC5CCBF), Color(hex: 0x68776E)],
                                                                                 startPoint: .leading, endPoint: .trailing))
                .frame(width: 25 * scale, height: 45 * scale).position(x: 81 * scale, y: 27 * scale)
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x45484D))
                .frame(width: 18 * scale, height: 39 * scale).rotationEffect(.degrees(36))
                .position(x: 24 * scale, y: 288 * scale)
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0x29372F))
                .frame(width: 14 * scale, height: 16 * scale).rotationEffect(.degrees(36))
                .position(x: 15 * scale, y: 303 * scale)
        }.frame(width: 120 * scale, height: 330 * scale)
    }
}

