import Foundation

enum OrbitHomeMode: String, Codable, CaseIterable, Identifiable {
    case wheel, grid, turntable
    var id: String { rawValue }
    var title: String { self == .wheel ? "滚轮" : self == .grid ? "唱片列表" : "黑胶唱盘" }
    var symbol: String { self == .wheel ? "circle.lefthalf.filled" : self == .grid ? "circle.grid.2x2" : "opticaldisc" }
}

enum OrbitRecordMaterial: String, Codable, CaseIterable, Identifiable {
    case resinGreen, black, artwork, split, smoke, silver, radial
    var id: String { rawValue }
    var title: String {
        switch self {
        case .resinGreen: return "树脂"
        case .black: return "黑胶"
        case .artwork: return "封面"
        case .split: return "双色"
        case .smoke: return "烟纹"
        case .silver: return "银色"
        case .radial: return "放射纹"
        }
    }
}

enum OrbitBackground: String, Codable, CaseIterable, Identifiable {
    case atmosphere, silver, sage, white, black, lavender, blue, spectrum, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .atmosphere: return "封面氛围"
        case .silver: return "银灰"
        case .sage: return "草绿"
        case .white: return "白色"
        case .black: return "黑色"
        case .lavender: return "淡紫"
        case .blue: return "浅蓝"
        case .spectrum: return "彩色"
        case .custom: return "自定义"
        }
    }
    var hex: UInt32 {
        switch self {
        case .atmosphere, .custom: return 0x0B1420
        case .silver: return 0xB4B5B7
        case .sage: return 0xC4C9B1
        case .white: return 0xF6F6F1
        case .black: return 0x121315
        case .lavender: return 0xCBC3E3
        case .blue: return 0xC0DDEA
        case .spectrum: return 0x383153
        }
    }
    var usesLightContent: Bool {
        self == .atmosphere || self == .black || self == .spectrum || self == .custom
    }
}

enum OrbitStickerKind: String, Codable, CaseIterable, Identifiable {
    case star, heart, cassette, vinyl
    var id: String { rawValue }
    var title: String { self == .star ? "银色星星" : self == .heart ? "红心" : self == .cassette ? "小磁带" : "迷你唱片" }
}

/// The reference's arm-light button cycles these four states globally; it does not
/// change the selected background, media position or system display brightness.
enum OrbitArmLight: String, Codable, CaseIterable {
    case off, red, blue, purple
    var next: Self {
        switch self {
        case .off: return .red
        case .red: return .blue
        case .blue: return .purple
        case .purple: return .off
        }
    }
    var title: String {
        switch self {
        case .off: return "关闭"
        case .red: return "红色"
        case .blue: return "蓝色"
        case .purple: return "紫色"
        }
    }
    var hex: String {
        switch self {
        case .off: return "FFFFFF"
        case .red: return "FF3A4A"
        case .blue: return "3488FF"
        case .purple: return "C25CFF"
        }
    }
}

struct OrbitRecordSticker: Codable, Equatable, Identifiable {
    var id: String
    var kind: OrbitStickerKind
    /// Center and diameter are fractions of the record's bounding square; rotation is degrees.
    var x: Double = 0.5
    var y: Double = 0.5
    var size: Double = 0.18
    var rotation: Double = 0

    func normalized() -> Self {
        var value = self
        value.size = size.isFinite ? min(0.34, max(0.1, size)) : 0.18
        let dx = (x.isFinite ? min(1, max(0, x)) : 0.5) - 0.5
        let dy = (y.isFinite ? min(1, max(0, y)) : 0.5) - 0.5
        let distance = hypot(dx, dy), limit = 0.5 - value.size / 2
        let ratio = distance > limit ? limit / distance : 1
        value.x = 0.5 + dx * ratio; value.y = 0.5 + dy * ratio
        value.rotation = rotation.isFinite ? (rotation.truncatingRemainder(dividingBy: 360) + 540).truncatingRemainder(dividingBy: 360) - 180 : 0
        return value
    }
}

struct OrbitRecordStyle: Codable, Equatable {
    var material: OrbitRecordMaterial = .resinGreen
    var primaryHex = "A7BCE8"
    var secondaryHex = "F1F4FB"
    var stickers: [OrbitRecordSticker] = []

    @discardableResult mutating func addSticker(_ kind: OrbitStickerKind) -> String? {
        guard stickers.count < 12 else { return nil }
        let id = UUID().uuidString
        let slot = stickers.count
        let angle = -.pi / 4 + Double(slot % 4) * .pi / 2 + Double(slot / 4) * .pi / 15
        stickers.append(OrbitRecordSticker(id: id, kind: kind, x: 0.5 + cos(angle) * 0.28, y: 0.5 + sin(angle) * 0.28))
        return id
    }
}

struct OrbitVisualPreferences: Codable, Equatable {
    var selectedHome: OrbitHomeMode = .turntable
    var background: OrbitBackground = .atmosphere
    var customBackgroundHex = "0B1420"
    var armLight: OrbitArmLight = .off
    // Only new preferences use the reference's atmospheric scene. A decoded legacy color
    // remains explicit, so installing a visual update does not discard an earlier choice.
    var globalStyle = OrbitRecordStyle(material: .smoke)
    var albumStyles: [String: OrbitRecordStyle] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case selectedHome, background, customBackgroundHex, armLight, globalStyle, albumStyles
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        selectedHome = try values.decodeIfPresent(OrbitHomeMode.self, forKey: .selectedHome) ?? .turntable
        background = try values.decodeIfPresent(OrbitBackground.self, forKey: .background) ?? .atmosphere
        armLight = try values.decodeIfPresent(OrbitArmLight.self, forKey: .armLight) ?? .off
        globalStyle = try values.decodeIfPresent(OrbitRecordStyle.self, forKey: .globalStyle) ?? OrbitRecordStyle(material: .smoke)
        albumStyles = try values.decodeIfPresent([String: OrbitRecordStyle].self, forKey: .albumStyles) ?? [:]
        let savedHex = try values.decodeIfPresent(String.self, forKey: .customBackgroundHex) ?? "0B1420"
        customBackgroundHex = Self.normalizedBackgroundHex(savedHex) ?? "0B1420"
    }

    var usesLightContent: Bool {
        guard background == .custom else { return background.usesLightContent }
        let hex = UInt32(Self.normalizedBackgroundHex(customBackgroundHex) ?? "0B1420", radix: 16) ?? 0x0B1420
        let red = Double((hex >> 16) & 255) / 255
        let green = Double((hex >> 8) & 255) / 255
        let blue = Double(hex & 255) / 255
        // Relative sRGB luminance selects a legible foreground; this never changes device brightness.
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = linear(red) * 0.2126 + linear(green) * 0.7152 + linear(blue) * 0.0722
        let contrastCrossover = sqrt(1.05 * 0.05) - 0.05
        return luminance < contrastCrossover
    }

    /// Accept a six-digit RGB value, optionally prefixed by #. Invalid picker data must not
    /// silently replace a valid saved color or select the custom background.
    @discardableResult mutating func setCustomBackgroundHex(_ candidate: String) -> Bool {
        guard let normalized = Self.normalizedBackgroundHex(candidate) else { return false }
        customBackgroundHex = normalized
        background = .custom
        return true
    }

    static func normalizedBackgroundHex(_ candidate: String) -> String? {
        var value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, value.unicodeScalars.allSatisfy({
            (48...57).contains($0.value) || (65...70).contains($0.value) || (97...102).contains($0.value)
        }) else { return nil }
        return value.uppercased()
    }

    func style(for albumKey: String) -> OrbitRecordStyle { albumStyles[albumKey] ?? globalStyle }

    /// A complete album override makes later global changes predictable; songs retain shared album style.
    mutating func setStyle(_ style: OrbitRecordStyle, albumKey: String?) {
        if let albumKey, !albumKey.isEmpty { albumStyles[albumKey] = style }
        else { globalStyle = style }
    }
}

enum OrbitRecordTransition: String {
    case initial, follow, continuous, relocate, replace
}
