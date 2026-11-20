import SwiftUI
import CoreText

/// The original description names artist/song letters formed from grains. This
/// draft uses runtime system glyphs; its exact layout and motion are our design.
struct OneTapeNameSand: View {
    let readout: OneTapePlaybackReadout
    var response: OneTapeScreenResponse = .silent
    @State private var targets: [CGPoint] = []

    private var text: (title: String, artist: String) {
        Self.normalizedText(title: readout.title, artist: readout.artist, hasTrack: readout.hasTrack)
    }
    private var title: String { text.title }
    private var artist: String { text.artist }
    private var textKey: String { title + "\u{0}" + artist }

    var body: some View {
        // Read State while building the view, not only inside Canvas's deferred
        // drawing closure. Otherwise a silent/empty player has no audio update
        // to incidentally redraw after glyph layout populates the cache.
        let letters = targets
        GeometryReader { geometry in
        Canvas { context, size in
            let scatter = min(1, response.transient * 2) * 7
            for (index, target) in letters.enumerated() {
                let seed = Double(index)
                let x = target.x + (noise(seed * 7.17 + response.motionTime * 0.03) - 0.5) * scatter
                let y = target.y + (noise(seed * 3.31 + response.motionTime * 0.03) - 0.5) * scatter
                let radius = 0.43 + noise(seed * 1.37) * 0.16
                let rect = CGRect(x: x, y: y,
                                  width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.67 + noise(seed) * 0.3)))
            }
            for index in 0..<210 {
                let seed = Double(index)
                let rect = CGRect(x: noise(seed * 1.73) * size.width,
                                  y: noise(seed * 3.17) * size.height, width: 0.7, height: 0.7)
                context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.17)))
            }
        }
        .onChange(of: textKey + "\(geometry.size.width),\(geometry.size.height)", initial: true) { _, _ in
            // This bounded CPU layout needs no asynchronous resource lifetime.
            // Cache on text/size changes; Canvas animation reuses these points.
            targets = Self.grainTargets(title: title, artist: artist, size: geometry.size)
        }
        }
    }

    nonisolated static func normalizedText(title: String, artist: String, hasTrack: Bool) -> (title: String, artist: String) {
        guard hasTrack else { return ("还没有磁带", "在音乐库添加音乐") }
        let visibleTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return (visibleTitle.isEmpty ? "未命名歌曲" : visibleTitle,
                visibleArtist.isEmpty ? "未知艺人" : visibleArtist)
    }

    nonisolated static func grainTargets(title: String, artist: String, size: CGSize) -> [CGPoint] {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 28.39, size.height > 12 else { return [] }
        let outline = CGMutablePath()
        // The artwork now shares the panel with time/progress rails. Position
        // glyphs inside its own available logical size, including tall layouts.
        let titleSize = min(24, max(16, size.height * 0.22))
        let artistSize = min(14, max(10, size.height * 0.13))
        addLine(artist, pointSize: artistSize, centerY: size.height * 0.34,
                canvasWidth: size.width, to: outline)
        addLine(title.isEmpty ? "未命名歌曲" : title, pointSize: titleSize,
                centerY: size.height * 0.66, canvasWidth: size.width, to: outline)
        var result: [CGPoint] = []
        for y in stride(from: 6.0, through: max(6, size.height - 6), by: 1.25) {
            for x in stride(from: 12.0, through: max(12, size.width - 12), by: 1.25) {
                if outline.contains(CGPoint(x: x, y: y)) { result.append(CGPoint(x: x, y: y)) }
            }
        }
        return result
    }

    nonisolated private static func addLine(_ value: String, pointSize: CGFloat,
                                centerY: CGFloat, canvasWidth: CGFloat, to output: CGMutablePath) {
        guard !value.isEmpty else { return }
        let font = CTFontCreateWithName("HelveticaNeue" as CFString, pointSize, nil)
        let text = NSAttributedString(string: value, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font
        ])
        let fullLine = CTLineCreateWithAttributedString(text)
        let availableWidth = canvasWidth - 28.39
        guard availableWidth > 0 else { return }
        let line: CTLine
        if CTLineGetTypographicBounds(fullLine, nil, nil, nil) > Double(availableWidth) {
            let token = NSAttributedString(string: "…", attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font
            ])
            let tokenLine = CTLineCreateWithAttributedString(token)
            // Keep the grain lettering at a readable point size. Scaling an
            // unbounded metadata string would collapse it below the sampling
            // pitch, leaving only a few dots in the narrow artwork viewport.
            line = CTLineCreateTruncatedLine(fullLine, Double(availableWidth), .end, tokenLine) ?? tokenLine
        } else {
            line = fullLine
        }
        let path = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            let attributes = CTRunGetAttributes(run) as NSDictionary
            // CoreText may choose a different font for CJK or emoji. Glyph IDs
            // belong to this run's font; using the requested Latin font here
            // would draw unrelated glyphs. Bitmap-only emoji have no outline.
            let runFont = attributes[kCTFontAttributeName] as! CTFont
            for index in 0..<count {
                if let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) {
                    path.addPath(glyph, transform: CGAffineTransform(
                        translationX: positions[index].x, y: positions[index].y))
                }
            }
        }
        let bounds = path.boundingBoxOfPath
        guard !bounds.isEmpty, bounds.width > 0 else { return }
        let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1,
                                         tx: (canvasWidth - bounds.width) / 2 - bounds.minX,
                                         ty: centerY + bounds.midY)
        output.addPath(path, transform: transform)
    }

    private func noise(_ seed: Double) -> Double {
        let value = sin(seed * 12.9898 + 78.233) * 43_758.5453
        return value - floor(value)
    }
}
