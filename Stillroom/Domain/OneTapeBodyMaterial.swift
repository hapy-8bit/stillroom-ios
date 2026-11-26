import Foundation

/// Optical drawing choices only. They never hold player, file or sensor state.
enum OneTapeBodyMaterial: String, Codable, CaseIterable, Identifiable, Sendable {
    case frostedGlass, smokedGlass, brushedAluminum, darkTitanium
    case holoFoil, silverFoil, circuitGlow, linen, disco
    case seeThrough, camoDigital, camoStealth, stickerBomb, greyTracks, cleanPlates

    var id: String { rawValue }

    static let cassetteOriginals: [Self] = [
        .holoFoil, .silverFoil, .circuitGlow, .linen, .disco,
        .seeThrough, .camoDigital, .camoStealth, .stickerBomb, .greyTracks, .cleanPlates
    ]

    static let glassAndMetal: [Self] = [
        .frostedGlass, .smokedGlass, .brushedAluminum, .darkTitanium
    ]

    var isGlass: Bool { self == .frostedGlass || self == .smokedGlass || self == .seeThrough }
    var isFoil: Bool { self == .holoFoil || self == .silverFoil }
    var usesTilt: Bool { self == .holoFoil || self == .silverFoil || self == .disco || self == .circuitGlow }

    var title: String {
        switch self {
        case .frostedGlass: "雾面玻璃"
        case .smokedGlass: "烟晶玻璃"
        case .brushedAluminum: "拉丝铝"
        case .darkTitanium: "深色钛金属"
        case .holoFoil: "全息箔"
        case .silverFoil: "金属箔"
        case .circuitGlow: "荧光电路"
        case .linen: "亚麻织布"
        case .disco: "迪斯科镜球"
        case .seeThrough: "透明机械"
        case .camoDigital: "数码迷彩"
        case .camoStealth: "暗夜迷彩"
        case .stickerBomb: "贴纸拼贴"
        case .greyTracks: "灰轨纹理"
        case .cleanPlates: "极简面板"
        }
    }

    var engraving: String {
        switch self {
        case .frostedGlass: "FROSTED  /  GLASS"
        case .smokedGlass: "SMOKED  /  GLASS"
        case .brushedAluminum: "ALUMINUM  /  6061"
        case .darkTitanium: "TITANIUM  /  SATIN"
        case .holoFoil: "HOLO  /  FOIL"
        case .silverFoil: "SILVER  /  FOIL"
        case .circuitGlow: "SIGNAL  /  CIRCUIT"
        case .linen: "WOVEN  /  LINEN"
        case .disco: "MIRROR  /  DISCO"
        case .seeThrough: "CLEAR  /  CHASSIS"
        case .camoDigital: "DIGITAL  /  CAMO"
        case .camoStealth: "STEALTH  /  CAMO"
        case .stickerBomb: "TAPE  /  ARCHIVE"
        case .greyTracks: "TRACKS  /  MILLED"
        case .cleanPlates: "CLEAN  /  PLATES"
        }
    }

    func palette(color: OneTapeAppearance.BodyColor = .black) -> OneTapeBodyMaterialPalette {
        typealias RGB = OneTapeTransportMaterial.RGB
        let base: RGB
        switch self {
        case .frostedGlass: base = RGB(0.69, 0.81, 0.83)
        case .smokedGlass: base = RGB(0.13, 0.20, 0.24)
        case .brushedAluminum: base = RGB(0.71, 0.75, 0.78)
        case .darkTitanium: base = RGB(0.28, 0.30, 0.34)
        case .holoFoil: base = RGB(0.78, 0.81, 0.88)
        case .silverFoil: base = RGB(0.79, 0.81, 0.83)
        case .circuitGlow: base = RGB(0.085, 0.115, 0.110)
        case .linen: base = RGB(0.80, 0.76, 0.68)
        case .disco: base = RGB(0.22, 0.23, 0.27)
        case .seeThrough: base = RGB(0.16, 0.18, 0.20)
        case .camoDigital: base = RGB(0.32, 0.36, 0.29)
        case .camoStealth: base = RGB(0.14, 0.15, 0.16)
        case .stickerBomb: base = RGB(0.13, 0.135, 0.145)
        case .greyTracks: base = RGB(0.46, 0.48, 0.49)
        case .cleanPlates: base = RGB(0.86, 0.85, 0.81)
        }
        let tintWeight: Double = switch self {
        case .holoFoil, .disco, .stickerBomb, .seeThrough: 0.42
        case .circuitGlow: 0.35
        default: 0.72
        }
        let shell = color == .black ? base : base.mixed(with: color.materialRGB, fraction: tintWeight)
        let keyLift: Double = switch self {
        case .frostedGlass, .smokedGlass, .seeThrough: 0.10
        case .holoFoil, .silverFoil, .disco: 0.14
        case .circuitGlow: 0.08
        default: 0.04
        }
        let key = shell.mixed(with: RGB(1, 1, 1), fraction: keyLift)
        let light = RGB(0.94, 0.97, 0.97)
        let dark = RGB(0.065, 0.085, 0.095)
        let lightContrast = (light.luminance + 0.05) / (key.luminance + 0.05)
        let darkContrast = (key.luminance + 0.05) / (dark.luminance + 0.05)
        let lcdBase = self == .circuitGlow ? RGB(0.76, 0.88, 0.80) : RGB(0.88, 0.92, 0.91)
        return OneTapeBodyMaterialPalette(shell: shell, key: key,
            ink: lightContrast > darkContrast ? light : dark,
            lcd: shell.mixed(with: lcdBase, fraction: isGlass ? 0.75 : 0.86))
    }
}

struct OneTapeBodyMaterialPalette: Equatable, Sendable {
    typealias RGB = OneTapeTransportMaterial.RGB
    let shell: RGB
    let key: RGB
    let ink: RGB
    let lcd: RGB
}

extension OneTapeAppearance.BodyColor {
    var materialRGB: OneTapeTransportMaterial.RGB {
        switch self {
        case .black: .init(0.09, 0.10, 0.10)
        case .navy: .init(0.16, 0.24, 0.31)
        case .green: .init(0.17, 0.35, 0.29)
        case .slate: .init(0.40, 0.47, 0.52)
        case .dove: .init(0.69, 0.72, 0.71)
        case .cognac: .init(0.57, 0.34, 0.23)
        case .white: .init(0.91, 0.91, 0.87)
        case .garden: .init(0.48, 0.59, 0.40)
        }
    }
}
