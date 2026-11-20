import Foundation

enum LyricInputFormat: Sendable { case auto, lrc, plain }
enum LyricOffsetPolicy: Sendable { case advance, legacyAdd }

enum LyricImportError: Error, LocalizedError, Equatable {
    case empty, tooLarge, tooManyLines, tooManyCues, invalidText, invalidFormat, invalidOffset
    case invalidEncoding, unsupportedEncoding, encodingConflict

    var errorDescription: String? {
        switch self {
        case .empty: return "歌词内容为空。"
        case .tooLarge: return "歌词文件不能超过 1 MB。"
        case .tooManyLines, .tooManyCues: return "歌词行数或时间标记过多，请缩小后重试。"
        case .invalidText: return "歌词包含非文本内容，请检查文件。"
        case .invalidFormat: return "没有可用的同步歌词，请检查时间标记或改用纯文本。"
        case .invalidOffset: return "歌词偏移量不是有效的整数毫秒。"
        case .invalidEncoding: return "歌词编码无法完整读取，请转换为 UTF-8 或带 BOM 的 UTF-16。"
        case .unsupportedEncoding: return "暂不支持这种歌词编码，请转换为 UTF-8 或带 BOM 的 UTF-16。"
        case .encodingConflict: return "所选编码与文件标记不同，请按文件编码重新预览。"
        }
    }
}

struct LyricWarning: Equatable, Sendable {
    enum Code: String, Sendable { case invalidTime, untimedText, duplicateOffset, colonFraction, negativePreroll }
    let code: Code
    /// One-based source line; zero denotes a document-wide warning.
    let line: Int
    var message: String {
        switch code {
        case .invalidTime: return "部分时间标记无效，请核对预览；原文保留。"
        case .untimedText: return "存在无时间标记的行，请核对多行歌词预览。"
        case .duplicateOffset: return "存在多个偏移设置，使用最后一个有效值。"
        case .colonFraction: return "冒号小数按秒的小数部分读取，保存时规范为小数点。"
        case .negativePreroll: return "部分歌词早于音频起点；原文保留，同步版仅保留起点应显示的最后一句。"
        }
    }
}

struct LyricCue: Equatable, Sendable {
    /// Integer milliseconds exist only at the LRC boundary to avoid fraction/offset rounding; playback consumes seconds.
    fileprivate let milliseconds: Int64
    let lines: [String]
    var time: TimeInterval { Double(milliseconds) / 1_000 }
    var text: String { lines.joined(separator: "\n") }
}

struct LyricDocument: Equatable, Sendable {
    enum Kind: Sendable { case timed, plain }
    static let maximumTextUnits = 1_048_576
    static let maximumLines = 10_000
    static let maximumCues = 10_000

    let kind: Kind
    /// The decoded source is retained separately, including offset/metadata and original line endings.
    let originalText: String
    let cues: [LyricCue]
    let offsetMilliseconds: Int64
    let warnings: [LyricWarning]

    /// New imports use positive-offset advance. legacyAdd exists only for strings saved by older app versions.
    static func parse(_ text: String, format: LyricInputFormat = .auto,
                      offsetPolicy: LyricOffsetPolicy = .advance) throws -> LyricDocument {
        try LyricDocumentParser.parse(text, format: format, offsetPolicy: offsetPolicy)
    }

    /// Zero-offset bridge for the existing player. Do not clamp every negative event onto the same timestamp:
    /// only the last preroll event effective at zero survives; an actual zero cue supersedes it.
    var canonicalText: String {
        get throws {
            guard kind == .timed else { return originalText }
            var visible = cues.filter { $0.milliseconds >= 0 }
            if let preroll = cues.last(where: { $0.milliseconds < 0 }),
               visible.first.map({ $0.milliseconds > 0 }) ?? true {
                visible.insert(LyricCue(milliseconds: 0, lines: preroll.lines), at: 0)
            }
            guard visible.contains(where: { $0.lines.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) })
            else { throw LyricImportError.invalidFormat }
            return visible.flatMap { cue -> [String] in
                let stamp = Self.stamp(cue.milliseconds)
                return cue.lines.isEmpty ? [stamp] : cue.lines.map { stamp + $0 }
            }.joined(separator: "\n")
        }
    }

    /// -1 before the first cue, for plain text or invalid media positions. Input/output media time is seconds.
    func activeIndex(at position: TimeInterval) -> Int {
        guard position.isFinite, position >= 0, !cues.isEmpty else { return -1 }
        var low = 0, high = cues.count - 1, active = -1
        while low <= high {
            let middle = (low + high) / 2
            if cues[middle].time <= position { active = middle; low = middle + 1 }
            else { high = middle - 1 }
        }
        return active
    }

    private static func stamp(_ milliseconds: Int64) -> String {
        let minutes = milliseconds / 60_000
        let seconds = milliseconds % 60_000 / 1_000
        let fraction = milliseconds % 1_000
        return String(format: "[%02lld:%02lld.%03lld]", minutes, seconds, fraction)
    }
}

private struct PendingLyricCue {
    let milliseconds: Int64
    var lines: [String]
    let ordinal: Int
}

private enum LyricDocumentParser {
    private static let stamp = try! NSRegularExpression(pattern: #"^\[(\d+):(\d{2})(?:[.:](\d{1,3}))?\]$"#)
    private static let leadingTag = try! NSRegularExpression(pattern: #"^\[[^\]]*\]"#)
    private static let offset = try! NSRegularExpression(pattern: #"^\[offset:([^\]]*)\]$"#, options: .caseInsensitive)
    private static let metadata = try! NSRegularExpression(pattern: #"^\[(?:ar|ti|al|by|re|ve|length|offset|lang|la):[^\]]*\]$"#,
                                                           options: .caseInsensitive)

    static func parse(_ text: String, format: LyricInputFormat, offsetPolicy: LyricOffsetPolicy) throws -> LyricDocument {
        guard text.utf16.count <= LyricDocument.maximumTextUnits else { throw LyricImportError.tooLarge }
        let original = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let normalized = original.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LyricImportError.empty }
        guard !normalized.unicodeScalars.contains(where: { (0...8).contains($0.value) || (11...12).contains($0.value) ||
            (14...31).contains($0.value) }) else { throw LyricImportError.invalidText }
        let lines = normalized.components(separatedBy: "\n")
        guard lines.count <= LyricDocument.maximumLines else { throw LyricImportError.tooManyLines }
        if format == .plain { return LyricDocument(kind: .plain, originalText: original, cues: [], offsetMilliseconds: 0, warnings: []) }
        var warnings: [LyricWarning] = []
        let offset = try sourceOffset(lines, warnings: &warnings)
        var pending: [PendingLyricCue] = [], previous: [Int] = []
        for (index, line) in lines.enumerated() {
            var content = line.trimmingCharacters(in: .whitespaces)
            if content.isEmpty || matches(metadata, content) { continue }
            var times: [Int64] = [], hadTiming = false
            while content.range(of: #"^\[\d"#, options: .regularExpression) != nil {
                hadTiming = true
                guard let token = first(leadingTag, content) else {
                    warnings.append(LyricWarning(code: .invalidTime, line: index + 1)); break
                }
                if let time = timestamp(token), let shifted = shifted(time, by: offset, policy: offsetPolicy) {
                    times.append(shifted)
                    if token.range(of: #"^\[\d+:\d{2}:"#, options: .regularExpression) != nil {
                        warnings.append(LyricWarning(code: .colonFraction, line: index + 1))
                    }
                } else { warnings.append(LyricWarning(code: .invalidTime, line: index + 1)) }
                content = String(content.dropFirst(token.count)).trimmingCharacters(in: .whitespaces)
            }
            if hadTiming {
                previous = []
                for time in times {
                    guard pending.count < LyricDocument.maximumCues else { throw LyricImportError.tooManyCues }
                    previous.append(pending.count)
                    pending.append(PendingLyricCue(milliseconds: time, lines: content.isEmpty ? [] : [content], ordinal: pending.count))
                }
            } else {
                warnings.append(LyricWarning(code: .untimedText, line: index + 1))
                for index in previous { pending[index].lines.append(content) }
            }
        }
        if !pending.contains(where: { !$0.lines.isEmpty }) {
            if format == .lrc || lines.contains(where: { $0.trimmingCharacters(in: .whitespaces).range(of: #"^\[\d"#, options: .regularExpression) != nil }) {
                throw LyricImportError.invalidFormat
            }
            guard lines.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty &&
                $0.range(of: #"^\s*\[[A-Za-z]+:[^\]]*\]\s*$"#, options: .regularExpression) == nil }) else { throw LyricImportError.empty }
            return LyricDocument(kind: .plain, originalText: original, cues: [], offsetMilliseconds: 0, warnings: [])
        }
        pending.sort { $0.milliseconds == $1.milliseconds ? $0.ordinal < $1.ordinal : $0.milliseconds < $1.milliseconds }
        var cues: [LyricCue] = []
        for cue in pending {
            if let last = cues.last, last.milliseconds == cue.milliseconds {
                var merged = last.lines
                for line in cue.lines where !merged.contains(line) { merged.append(line) }
                cues[cues.count - 1] = LyricCue(milliseconds: cue.milliseconds, lines: merged)
            } else { cues.append(LyricCue(milliseconds: cue.milliseconds, lines: cue.lines)) }
        }
        if cues.first.map({ $0.milliseconds < 0 }) == true { warnings.append(LyricWarning(code: .negativePreroll, line: 0)) }
        return LyricDocument(kind: .timed, originalText: original, cues: cues, offsetMilliseconds: offset, warnings: warnings)
    }

    private static func sourceOffset(_ lines: [String], warnings: inout [LyricWarning]) throws -> Int64 {
        var value: Int64 = 0, found = false
        for (index, line) in lines.enumerated() {
            let text = line.trimmingCharacters(in: .whitespaces), source = text as NSString
            guard let match = offset.firstMatch(in: text, range: NSRange(location: 0, length: source.length)) else { continue }
            let raw = source.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            guard raw.range(of: #"^[+-]?\d+$"#, options: .regularExpression) != nil, let integer = Int64(raw) else { throw LyricImportError.invalidOffset }
            if found { warnings.append(LyricWarning(code: .duplicateOffset, line: index + 1)) }
            value = integer; found = true
        }
        return value
    }

    private static func timestamp(_ token: String) -> Int64? {
        let source = token as NSString
        guard let match = stamp.firstMatch(in: token, range: NSRange(location: 0, length: source.length)),
              let minutes = Int64(source.substring(with: match.range(at: 1))),
              let seconds = Int64(source.substring(with: match.range(at: 2))), seconds < 60 else { return nil }
        let fractionRange = match.range(at: 3)
        let raw = fractionRange.location == NSNotFound ? "" : source.substring(with: fractionRange)
        let fraction = Int64(raw.padding(toLength: 3, withPad: "0", startingAt: 0)) ?? 0
        let product = minutes.multipliedReportingOverflow(by: 60_000)
        let total = product.partialValue.addingReportingOverflow(seconds * 1_000 + fraction)
        return product.overflow || total.overflow ? nil : total.partialValue
    }

    private static func shifted(_ time: Int64, by offset: Int64, policy: LyricOffsetPolicy) -> Int64? {
        let result = policy == .advance ? time.subtractingReportingOverflow(offset) : time.addingReportingOverflow(offset)
        return result.overflow ? nil : result.partialValue
    }

    private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool { first(regex, text) != nil }
    private static func first(_ regex: NSRegularExpression, _ text: String) -> String? {
        let source = text as NSString
        return regex.firstMatch(in: text, range: NSRange(location: 0, length: source.length)).map { source.substring(with: $0.range) }
    }
}
