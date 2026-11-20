import Foundation

struct LyricLine: Identifiable, Equatable, Sendable {
    let id: Int
    let time: TimeInterval
    let text: String
}

enum Lyrics {
    /// Older saved strings used offset addition. New imports serialize to zero-offset LRC before reaching this bridge.
    static func parse(_ text: String) -> [LyricLine] {
        guard let document = try? LyricDocument.parse(text, offsetPolicy: .legacyAdd), document.kind == .timed else { return [] }
        return document.cues.enumerated().map { LyricLine(id: $0.offset, time: $0.element.time, text: $0.element.text) }
    }

    static func activeIndex(in lines: [LyricLine], at time: TimeInterval) -> Int? {
        guard time.isFinite, time >= 0 else { return nil }
        return lines.lastIndex { $0.time <= time }
    }
}

