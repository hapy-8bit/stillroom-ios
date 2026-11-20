import SwiftUI

struct OneTapeEmptyLCD: View {
    var readout: OneTapePlaybackReadout = .empty
    var quarterTurns: Int = 0
    var material: OneTapeLCDMaterial = .original
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var bright = true

    private var ink: Color {
        Color(red: material.ink.red, green: material.ink.green, blue: material.ink.blue)
    }
    private var blinks: Bool { !reduceMotion && scenePhase == .active && !readout.isPlaying }

    var body: some View {
        GeometryReader { proxy in
            let geometry = OneTapeScreenLayoutGeometry(size: proxy.size)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color(red: material.background.red, green: material.background.green,
                                blue: material.background.blue))
                content(geometry: geometry)
            }
        }
        .foregroundStyle(ink)
        .clipped()
        .accessibilityHidden(true)
        .task(id: blinks) {
            bright = true
            guard blinks else { return }
            // The empty readout has a visual blink clock only. It never updates
            // media position, queue state, or a playback engine.
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(600))
                    guard !Task.isCancelled else { return }
                    bright.toggle()
                } catch {
                    return
                }
            }
        }
    }

    /// The outer turn supplies a continuously changing logical proposal.
    /// Interpolate anchors and line widths, retaining one set of glyph views;
    /// the common unit scales both axes equally and is 1 throughout a turn.
    private func content(geometry: OneTapeScreenLayoutGeometry) -> some View {
        let unit = geometry.unit
        let textWidth = geometry.mix(238.5, 140.63) * unit
        return ZStack(alignment: .topLeading) {
            OneTapeLCDHeaderLayout(geometry: geometry) {
                Text("曲 \(readout.trackLabel)")
                Text(readout.screenSideLabel)
            }
            .font(.custom("GeistMono-Regular", size: 12.5 * unit))

            OneTapePixelString(text: readout.positionLabel, cell: 4.2 * unit,
                               positions: timePositions(readout.positionLabel, cell: 4.2).map { $0 * unit },
                               color: ink.opacity(bright ? 0.95 : 0.12))
                .frame(width: geometry.mix(142, 141) * unit, height: 29 * unit, alignment: .leading)
                .offset(x: 12 * unit, y: geometry.mix(39.88, 59.3) * unit)

            HStack(alignment: .center, spacing: 13 * unit) {
                OneTapePausePixels(color: ink, playing: readout.isPlaying)
                    .frame(width: 10, height: 14)
                    .scaleEffect(unit, anchor: .topLeading)
                    .frame(width: 10 * unit, height: 14 * unit, alignment: .topLeading)
                OneTapePixelString(text: readout.remainingLabel, cell: 2.1 * unit,
                                   positions: timePositions(readout.remainingLabel, cell: 2.1).map { $0 * unit },
                                   color: ink)
                    .frame(width: geometry.mix(72, 100) * unit, height: 15 * unit, alignment: .leading)
            }
            .offset(x: geometry.mix(166.33, 12.5) * unit, y: geometry.mix(54.55, 95.7) * unit)

            Text(readout.hasTrack ? (readout.title.isEmpty ? "未命名歌曲" : readout.title) : "还没有磁带")
                .font(.system(size: 12.5 * unit))
                .lineLimit(1)
                .frame(width: textWidth, alignment: .leading)
                .offset(x: 12.5 * unit, y: geometry.mix(84, 142) * unit)
            Text(readout.isPreparing ? "正在准备播放" : (readout.hasTrack ? readout.artist : "在音乐库添加音乐"))
                .font(.system(size: 12.5 * unit))
                .lineLimit(1)
                .frame(width: textWidth, alignment: .leading)
                .offset(x: 12.5 * unit, y: geometry.mix(112, 189.3) * unit)

            OneTapeEmptyProgress(color: ink, fraction: readout.fraction)
                .frame(width: textWidth, height: 14 * unit)
                .offset(x: 12.5 * unit, y: geometry.mix(139, 237.7) * unit)
        }
        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
    }

    private func timePositions(_ text: String, cell: CGFloat) -> [CGFloat] {
        if text == "0:00" { return [0, 29.333, 50.333, 75.667] }
        if text == "-0:00" { return [0, 12.667, 27.333, 37.667, 50.333] }
        var next: CGFloat = 0
        return text.map { character in
            let anchor = next
            next += (character == ":" ? 5 : 6.1) * cell
            return anchor
        }
    }
}

/// Measure the real side-label glyphs, including CJK fallback, so the wide
/// left anchor and tall trailing anchor interpolate without replacing views.
private struct OneTapeLCDHeaderLayout: Layout {
    let geometry: OneTapeScreenLayoutGeometry

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: geometry.size.width, height: 30 * geometry.unit)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let unit = geometry.unit
        let sideWidth = subviews[1].sizeThatFits(.unspecified).width
        subviews[0].place(at: CGPoint(x: bounds.minX + geometry.mix(12.7, 12.5) * unit,
                                     y: bounds.minY + 12 * unit),
                          anchor: .topLeading, proposal: .unspecified)
        let sideX = geometry.mix(138, 153.13 - sideWidth / unit) * unit
        subviews[1].place(at: CGPoint(x: bounds.minX + sideX, y: bounds.minY + 12 * unit),
                          anchor: .topLeading, proposal: .unspecified)
    }
}

private struct OneTapePixelString: View {
    let text: String
    let cell: CGFloat
    let positions: [CGFloat]
    let color: Color

    var body: some View {
        Canvas { context, _ in
            // Character anchors and dot pitch are logical points measured on
            // the 393-point reference canvas, independent of display pixels.
            for (index, character) in text.enumerated() {
                let x = positions[index]
                let glyph = Self.glyph(character)
                for (row, bits) in glyph.rows.enumerated() {
                    for column in 0..<glyph.width where bits & (1 << (glyph.width - 1 - column)) != 0 {
                        let rectangle = CGRect(
                            x: x + CGFloat(column) * cell,
                            y: CGFloat(row) * cell,
                            width: cell * 0.87,
                            height: cell * 0.87
                        )
                        context.fill(Path(rectangle), with: .color(color))
                    }
                }
            }
        }
    }

    private static func glyph(_ character: Character) -> (width: Int, rows: [Int]) {
        switch character {
        case "0": return (5, [14, 17, 17, 17, 17, 17, 14])
        case "1": return (5, [4, 12, 4, 4, 4, 4, 14])
        case "2": return (5, [14, 17, 1, 2, 4, 8, 31])
        case "3": return (5, [30, 1, 1, 14, 1, 1, 30])
        case "4": return (5, [2, 6, 10, 18, 31, 2, 2])
        case "5": return (5, [31, 16, 16, 30, 1, 1, 30])
        case "6": return (5, [14, 16, 16, 30, 17, 17, 14])
        case "7": return (5, [31, 1, 2, 4, 8, 8, 8])
        case "8": return (5, [14, 17, 17, 14, 17, 17, 14])
        case "9": return (5, [14, 17, 17, 15, 1, 1, 14])
        case ":": return (2, [0, 3, 3, 0, 3, 3, 0])
        case "-": return (5, [0, 0, 0, 31, 0, 0, 0])
        default: return (1, [0, 0, 0, 0, 0, 0, 0])
        }
    }
}

private struct OneTapePausePixels: View {
    let color: Color
    var playing = false

    var body: some View {
        Canvas { context, size in
            if playing {
                var triangle = Path()
                triangle.move(to: .zero)
                triangle.addLines([CGPoint(x: size.width, y: size.height / 2),
                                   CGPoint(x: 0, y: size.height)])
                triangle.closeSubpath()
                context.fill(triangle, with: .color(color))
                return
            }
            for column in [0, 3] {
                for row in 0..<7 {
                    context.fill(
                        Path(CGRect(x: CGFloat(column) * 2, y: CGFloat(row) * 2,
                                    width: 3.5, height: 1.7)),
                        with: .color(color)
                    )
                }
            }
        }
    }
}

private struct OneTapeEmptyProgress: View {
    let color: Color
    var fraction = 0.0

    var body: some View {
        Canvas { context, size in
            guard size.width > 8, size.height > 6 else { return }
            let rows = 7
            let clamped = fraction.isFinite ? min(1, max(0, fraction)) : 0
            let unit = size.height / 14
            let targetDot = 1.36 * unit
            let stepY = max(0.5, (size.height - targetDot) / CGFloat(rows - 1))
            let cols = max(4, Int(((size.width - targetDot) / stepY).rounded()))
            let stepX = (size.width - targetDot) / CGFloat(cols)
            let dotWidth = min(targetDot, stepX * 0.68)
            let dotHeight = min(targetDot, stepY * 0.68)
            let insetX = (targetDot - dotWidth) * 0.5
            let insetY = (targetDot - dotHeight) * 0.5
            let dotColor = color.opacity(0.92)

            func fillDot(col: Int, row: Int) {
                let x = CGFloat(col) * stepX + insetX
                let y = CGFloat(row) * stepY + insetY
                context.fill(Path(CGRect(x: x, y: y, width: dotWidth, height: dotHeight)),
                             with: .color(dotColor))
            }

            for col in 0...cols {
                fillDot(col: col, row: 0)
                fillDot(col: col, row: rows - 1)
            }
            for row in 1..<(rows - 1) {
                fillDot(col: 0, row: row)
                fillDot(col: cols, row: row)
            }

            let innerColumns = max(0, cols - 3)
            let filledColumns: Int
            if clamped <= 0 || innerColumns == 0 {
                filledColumns = 0
            } else {
                filledColumns = min(innerColumns, max(1, Int((Double(innerColumns) * clamped).rounded())))
            }
            for offset in 0..<filledColumns {
                let col = 2 + offset
                for row in 2...4 {
                    fillDot(col: col, row: row)
                }
            }
        }
    }
}
