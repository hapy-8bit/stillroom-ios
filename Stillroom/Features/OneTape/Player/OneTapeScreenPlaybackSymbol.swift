import SwiftUI

/// A visual projection of the authoritative state, with no playback action or
/// media timer. The optional loading clock belongs only to the progress glyph.
struct OneTapeScreenPlaybackSymbol: View {
    let style: OneTapeAppearance.ScreenStyle
    let state: OneTapeScreenState
    var unit: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if state == .loading {
                if reduceMotion || scenePhase != .active {
                    icon("hourglass")
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 12)) { timeline in
                        let turn = (timeline.date.timeIntervalSinceReferenceDate / 1.4).truncatingRemainder(dividingBy: 1)
                        Canvas { context, size in
                            let rect = CGRect(origin: .zero, size: size).insetBy(dx: unit, dy: unit)
                            var path = Path()
                            path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2,
                                        startAngle: .degrees(turn * 360), endAngle: .degrees(turn * 360 + 270),
                                        clockwise: false)
                            context.stroke(path, with: .color(color),
                                           style: StrokeStyle(lineWidth: 1.05 * unit, lineCap: .round))
                        }
                    }
                }
            } else if style == .name && state != .empty {
                icon(symbolName)
                    .mask {
                        Canvas { context, size in
                            let step = 1.35 * unit
                            for y in stride(from: 0.5 * unit, through: size.height, by: step) {
                                for x in stride(from: 0.5 * unit, through: size.width, by: step) {
                                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.74 * unit,
                                                                       height: 0.74 * unit)), with: .color(.white))
                                }
                            }
                        }
                    }
                    .overlay { icon(symbolName).opacity(0.22) }
            } else {
                icon(symbolName)
            }
        }
        .frame(width: 11.5 * unit, height: 11.5 * unit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibleLabel)
        .accessibilityIdentifier("screen.readout.status")
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
    }

    private var symbolName: String {
        guard state != .empty else { return "minus" }
        let filled = style == .fluid || style == .meters
        let name = state == .playing ? "play" : "pause"
        return name + (filled ? ".fill" : "")
    }

    private var color: Color {
        style == .trails ? Color(red: 200 / 255, green: 180 / 255, blue: 141 / 255)
            : Color(red: 200 / 255, green: 198 / 255, blue: 187 / 255)
    }

    private var accessibleLabel: String {
        switch state {
        case .empty: "未装入磁带"
        case .loading: "正在准备播放"
        case .playing: "播放中"
        case .paused: "已暂停"
        }
    }
}
