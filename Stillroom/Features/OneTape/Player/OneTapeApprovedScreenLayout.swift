import SwiftUI
import UIKit

/// Continuous logical geometry between the two screen orientations. Recovering
/// the fraction from aspect ratio also supports uniformly scaled renderers.
struct OneTapeScreenLayoutGeometry {
    static let wideSize = CGSize(width: 264.39, height: 165.63)
    static let tallSize = CGSize(width: 165.63, height: 264.39)
    let size: CGSize

    init(size: CGSize) { self.size = size }

    init(fraction: Double) {
        let value = min(1, max(0, fraction.isFinite ? fraction : 0))
        size = CGSize(width: Self.wideSize.width + (Self.tallSize.width - Self.wideSize.width) * value,
                      height: Self.wideSize.height + (Self.tallSize.height - Self.wideSize.height) * value)
    }

    var tallFraction: CGFloat {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return 0 }
        let ratio = size.height / size.width
        let value = (ratio * Self.wideSize.width - Self.wideSize.height)
            / ((Self.tallSize.height - Self.wideSize.height)
                - ratio * (Self.tallSize.width - Self.wideSize.width))
        if value < 0.000001 { return 0 }
        if value > 0.999999 { return 1 }
        return min(1, max(0, value))
    }

    var unit: CGFloat {
        guard size.width.isFinite, size.width > 0 else { return 1 }
        return size.width / mix(Self.wideSize.width, Self.tallSize.width)
    }

    func mix(_ wide: CGFloat, _ tall: CGFloat) -> CGFloat {
        wide + (tall - wide) * tallFraction
    }
}

struct OneTapeApprovedScreenTextLayout {
    let lines: [String]
    let fontSize: CGFloat
    let linePitch: CGFloat
    let firstBaseline: CGFloat
    let artistBaseline: CGFloat

    var lastBaseline: CGFloat { firstBaseline + CGFloat(max(0, lines.count - 1)) * linePitch }
}

/// One contract for the frame, glyph masks and PCM plots. Values are logical
/// points in the already exchanged LCD proposal, before its quarter-turn.
enum OneTapeApprovedScreenLayout {
    static func isTall(_ size: CGSize) -> Bool { size.height > size.width }

    static func artworkRect(style: OneTapeAppearance.ScreenStyle, size: CGSize) -> CGRect {
        let w = max(0, size.width), h = max(0, size.height)
        let geometry = OneTapeScreenLayoutGeometry(size: size)
        switch style {
        case .name:
            return CGRect(x: w * 0.08, y: h * geometry.mix(0.20, 0.15),
                          width: w * 0.84, height: h * geometry.mix(0.50, 0.54))
        case .meters:
            return CGRect(x: w * geometry.mix(0.20, 0.09), y: h * geometry.mix(0.44, 0.405),
                          width: w * geometry.mix(0.71, 0.82), height: h * geometry.mix(0.34, 0.365))
        default:
            return CGRect(origin: .zero, size: size)
        }
    }

    static func headerBaseline(size: CGSize) -> CGFloat {
        size.height * OneTapeScreenLayoutGeometry(size: size).mix(0.14, 0.09)
    }

    static func readoutBaseline(size: CGSize) -> CGFloat { size.height * 0.922 }

    static func symbolRect(size: CGSize) -> CGRect {
        let unit = OneTapeApprovedScreenTypeface.unit(size: size)
        let side = 11.5 * unit
        return CGRect(x: size.width * 0.50 - side / 2,
                      y: readoutBaseline(size: size) - 4.6 * unit - side / 2,
                      width: side, height: side)
    }

    static func elapsedRect(size: CGSize) -> CGRect { timeRect(size: size, right: false) }
    static func remainingRect(size: CGSize) -> CGRect { timeRect(size: size, right: true) }

    private static func timeRect(size: CGSize, right: Bool) -> CGRect {
        let unit = OneTapeApprovedScreenTypeface.unit(size: size)
        return CGRect(x: size.width * (right ? 0.625 : 0.085),
                      y: readoutBaseline(size: size) - 21 * unit,
                      width: size.width * 0.29, height: 25 * unit)
    }

    static func metadataRect(size: CGSize) -> CGRect {
        CGRect(x: size.width * 0.085, y: 0, width: size.width * 0.83, height: size.height)
    }

    static func titleLastBaseline(style: OneTapeAppearance.ScreenStyle, size: CGSize) -> CGFloat {
        let wide: CGFloat = style == .meters ? 0.31 : style == .trails ? 0.52 : 0.70
        let tall: CGFloat = style == .meters ? 0.255 : 0.754
        return size.height * OneTapeScreenLayoutGeometry(size: size).mix(wide, tall)
    }

    static func metadataTextLayout(style: OneTapeAppearance.ScreenStyle, title: String,
                                   size: CGSize) -> OneTapeApprovedScreenTextLayout {
        let fontSize = OneTapeApprovedScreenTypeface.titleSize(size: size)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        let lines = wrapped(title, font: font, width: size.width * 0.83,
                            maxLines: isTall(size) ? 2 : 1)
        let pitch = fontSize * 1.04
        let last = titleLastBaseline(style: style, size: size)
        let unit = OneTapeApprovedScreenTypeface.unit(size: size)
        let geometry = OneTapeScreenLayoutGeometry(size: size)
        let tallArtist = style == .meters ? last + 15 * unit : size.height * 0.81
        let artist = geometry.mix(last + 16 * unit, tallArtist)
        return .init(lines: lines, fontSize: fontSize, linePitch: pitch,
                     firstBaseline: last - CGFloat(lines.count - 1) * pitch, artistBaseline: artist)
    }

    static func nameTextLayout(title: String, size: CGSize) -> OneTapeApprovedScreenTextLayout {
        let tall = isTall(size)
        let fontSize = OneTapeApprovedScreenTypeface.particleTitleSize(size: size)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        let lines = wrapped(title, font: font, width: size.width * 0.80,
                            maxLines: tall ? 3 : 1, balanced: tall)
        let pitch = fontSize * 1.10
        // The approved preview defines the center of the baseline group, not
        // the center of its glyph bounding box. Both mask and artist use it.
        let first = size.height * OneTapeScreenLayoutGeometry(size: size).mix(0.51, 0.465)
            - CGFloat(lines.count - 1) * pitch / 2
        let artist = min(size.height * 0.785,
                         first + CGFloat(lines.count - 1) * pitch + 23 * OneTapeApprovedScreenTypeface.unit(size: size))
        return .init(lines: lines, fontSize: fontSize, linePitch: pitch,
                     firstBaseline: first, artistBaseline: artist)
    }

    /// Swift Character boundaries retain joined emoji. Prefer a nearby space,
    /// then tail-truncate the final line; no font shrinking hides a long title.
    private static func wrapped(_ text: String, font: UIFont, width: CGFloat,
                                maxLines: Int, balanced: Bool = false) -> [String] {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return ["未命名歌曲"] }
        let glyphs = Array(value)
        var output: [String] = []
        var cursor = 0
        func measure(_ value: String) -> CGFloat {
            (value as NSString).size(withAttributes: [.font: font]).width
        }
        while cursor < glyphs.count && output.count < maxLines {
            let remaining = String(glyphs[cursor...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if measure(remaining) <= width { output.append(remaining); break }
            if output.count == maxLines - 1 {
                var tail = Array(remaining)
                while !tail.isEmpty && measure(String(tail) + "…") > width { tail.removeLast() }
                output.append(String(tail) + "…")
                break
            }
            var end = cursor + 1
            while end <= glyphs.count && measure(String(glyphs[cursor..<end])) <= width { end += 1 }
            end = max(cursor + 1, end - 1)
            var boundary = end
            let minimum = cursor + Int(Double(end - cursor) * 0.40)
            if end - 1 > minimum {
                for index in stride(from: end - 1, through: minimum + 1, by: -1) {
                    if glyphs[index].isWhitespace { boundary = index; break }
                }
            }
            output.append(String(glyphs[cursor..<boundary]).trimmingCharacters(in: .whitespacesAndNewlines))
            cursor = boundary
            while cursor < glyphs.count && glyphs[cursor].isWhitespace { cursor += 1 }
        }
        if balanced && output.count == 1 && measure(value) > width * 0.60 {
            let words = value.split(whereSeparator: \.isWhitespace).map(String.init)
            var best: (CGFloat, [String])?
            if words.count > 1 {
                for split in 1..<words.count {
                    let a = words[..<split].joined(separator: " ")
                    let b = words[split...].joined(separator: " ")
                    let aw = measure(a), bw = measure(b), cost = abs(aw - bw)
                    if aw <= width && bw <= width && (best == nil || cost < best!.0) { best = (cost, [a, b]) }
                }
            }
            if let best { return best.1 }
        }
        return output.isEmpty ? [value] : output
    }
}

enum OneTapeApprovedScreenTypeface {
    static func unit(size: CGSize) -> CGFloat {
        OneTapeScreenLayoutGeometry(size: size).unit
    }

    static func titleSize(size: CGSize) -> CGFloat {
        OneTapeScreenLayoutGeometry(size: size).mix(22, 20) * unit(size: size)
    }

    static func particleTitleSize(size: CGSize) -> CGFloat {
        OneTapeScreenLayoutGeometry(size: size).mix(32, 27) * unit(size: size)
    }

    static func titleFont(size: CGSize) -> Font {
        .system(size: titleSize(size: size), weight: .regular, design: .default)
    }

    static func headerFont(size: CGSize) -> Font {
        .system(size: 9.1 * unit(size: size), weight: .regular, design: .default)
    }

    static func artistFont(size: CGSize) -> Font {
        .system(size: 9 * unit(size: size), weight: .regular, design: .default)
    }

    static func timeFace(style: OneTapeAppearance.ScreenStyle) -> String {
        switch style {
        case .fluid: "InstrumentSerif-Italic"
        case .trails: "CormorantGaramond-MediumItalic"
        case .meters: "SpaceGrotesk-Medium"
        default: "InstrumentSerif-Regular"
        }
    }

    static func timeSize(style: OneTapeAppearance.ScreenStyle, size: CGSize,
                         text: String, remaining: Bool = false) -> CGFloat {
        let nominal: CGFloat = switch style {
        case .fluid: 17
        case .trails: 18
        case .meters: 14.5
        default: 16
        }
        let pointSize = nominal * unit(size: size) * (remaining ? 0.80 : 1)
        let font = UIFont(name: timeFace(style: style), size: pointSize) ?? .systemFont(ofSize: pointSize)
        let measured = (text as NSString).size(withAttributes: [.font: font]).width
        return pointSize * min(1, size.width * 0.29 / max(1, measured))
    }
}
