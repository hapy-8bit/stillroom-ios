import Foundation

/// Unified Cassette-aligned body category taxonomy shared across customization UI
/// and rendering layers. Domain owns classification only; views own drawing.
enum OneTapeBodyCategory: String, CaseIterable, Identifiable, Sendable {
    case classic
    case foil
    case tech
    case industrial
    case tactile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "经典涂装"
        case .foil: "光学箔面"
        case .tech: "机能电路"
        case .industrial: "工业精工"
        case .tactile: "质感纹理"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: "经典壳体、随曲与喷漆"
        case .foil: "拉丝薄膜干涉与镜球光效"
        case .tech: "暗黑电路与透明机械结构"
        case .industrial: "铣槽导轨与 CNC 精工面板"
        case .tactile: "哑光迷彩、织布与贴纸拼贴"
        }
    }

    /// Signature material categories (excluding the classic painted chassis group).
    static let materialCategories: [Self] = [.foil, .tech, .industrial, .tactile]

    /// Complete ordered list of signature materials in each category.
    var materials: [OneTapeBodyMaterial] {
        switch self {
        case .classic: []
        case .foil: [.holoFoil, .silverFoil, .disco]
        case .tech: [.circuitGlow, .seeThrough]
        case .industrial: [.greyTracks, .cleanPlates]
        case .tactile: [.camoStealth, .camoDigital, .linen, .stickerBomb]
        }
    }
}

/// Hardware key finish decoupled from body surface artwork so complex bodies
/// retain grounded, high-contrast physical keys like Cassette 1.0.5.
enum OneTapeBodyKeyFinish: Equatable, Sendable {
    case blackHardware
    case graphiteHardware
    case cleanPlateHardware
    case seeThroughHardware
    case paintedHardware
}

/// Optical drawing choices only. They never hold player, file or sensor state.
/// Legacy cases (`frostedGlass`, `smokedGlass`, `brushedAluminum`, `darkTitanium`)
/// remain decodable for persistence compatibility and migrate cleanly on load.
enum OneTapeBodyMaterial: String, Codable, CaseIterable, Identifiable, Sendable {
    case frostedGlass, smokedGlass, brushedAluminum, darkTitanium
    case holoFoil, silverFoil, circuitGlow, linen, disco
    case seeThrough, camoDigital, camoStealth, stickerBomb, greyTracks, cleanPlates

    var id: String { rawValue }

    static let cassetteOriginals: [Self] = [
        .holoFoil, .silverFoil, .disco,
        .circuitGlow, .seeThrough,
        .greyTracks, .cleanPlates,
        .camoStealth, .camoDigital, .linen, .stickerBomb
    ]

    var isRetiredLegacy: Bool {
        switch self {
        case .frostedGlass, .smokedGlass, .brushedAluminum, .darkTitanium: true
        default: false
        }
    }

    var category: OneTapeBodyCategory {
        switch self {
        case .holoFoil, .silverFoil, .disco:
            return .foil
        case .circuitGlow, .seeThrough:
            return .tech
        case .greyTracks, .cleanPlates:
            return .industrial
        case .camoStealth, .camoDigital, .linen, .stickerBomb:
            return .tactile
        case .frostedGlass, .smokedGlass, .brushedAluminum, .darkTitanium:
            return .classic
        }
    }

    var keyFinish: OneTapeBodyKeyFinish {
        switch self {
        case .cleanPlates: .cleanPlateHardware
        case .seeThrough: .seeThroughHardware
        default: .blackHardware
        }
    }

    var isDarkShell: Bool {
        switch self {
        case .circuitGlow, .camoStealth, .seeThrough, .disco, .stickerBomb, .smokedGlass, .darkTitanium:
            return true
        case .holoFoil, .silverFoil, .greyTracks, .cleanPlates, .camoDigital, .linen, .frostedGlass, .brushedAluminum:
            return false
        }
    }

    var isGlass: Bool { self == .frostedGlass || self == .smokedGlass || self == .seeThrough }
    var isFoil: Bool { self == .holoFoil || self == .silverFoil }
    var usesTilt: Bool { !isRetiredLegacy }
    var usesAudio: Bool { self == .circuitGlow || self == .disco }
    var usesLiveAnimation: Bool { self == .circuitGlow || self == .disco || self == .seeThrough }

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

    func palette(color: OneTapeAppearance.BodyColor = .black) -> OneTapeBodyMaterialPalette {
        typealias RGB = OneTapeTransportMaterial.RGB
        let base: RGB
        switch self {
        case .frostedGlass: base = RGB(0.69, 0.81, 0.83)
        case .smokedGlass: base = RGB(0.13, 0.20, 0.24)
        case .brushedAluminum: base = RGB(0.71, 0.75, 0.78)
        case .darkTitanium: base = RGB(0.28, 0.30, 0.34)
        case .holoFoil: base = RGB(0.78, 0.80, 0.85)
        case .silverFoil: base = RGB(0.80, 0.82, 0.85)
        case .circuitGlow: base = RGB(0.065, 0.066, 0.072)
        case .linen: base = RGB(0.78, 0.71, 0.60)
        case .disco: base = RGB(0.18, 0.19, 0.22)
        case .seeThrough: base = RGB(0.18, 0.195, 0.21)
        case .camoDigital: base = RGB(0.45, 0.49, 0.53)
        case .camoStealth: base = RGB(0.115, 0.118, 0.124)
        case .stickerBomb: base = RGB(0.16, 0.165, 0.175)
        case .greyTracks: base = RGB(0.87, 0.86, 0.82)
        case .cleanPlates: base = RGB(0.42, 0.43, 0.445)
        }

        // Grounded hardware key tones matching Cassette 1.0.5's physical contrast.
        let key: RGB
        let ink: RGB
        switch keyFinish {
        case .blackHardware:
            key = RGB(0.125, 0.128, 0.134)
            ink = RGB(0.78, 0.80, 0.82)
        case .graphiteHardware:
            key = RGB(0.20, 0.21, 0.22)
            ink = RGB(0.85, 0.86, 0.87)
        case .cleanPlateHardware:
            key = RGB(0.54, 0.555, 0.57)
            ink = RGB(0.10, 0.11, 0.12)
        case .seeThroughHardware:
            key = RGB(0.15, 0.16, 0.17)
            ink = RGB(0.80, 0.82, 0.84)
        case .paintedHardware:
            let shell = color == .black ? base : base.mixed(with: color.materialRGB, fraction: 0.72)
            key = shell.mixed(with: RGB(1, 1, 1), fraction: 0.06)
            ink = key.luminance > 0.28 ? RGB(0.08, 0.10, 0.09) : RGB(0.94, 0.96, 0.94)
        }

        let lcd: RGB
        switch self {
        case .holoFoil, .silverFoil, .disco:
            lcd = RGB(0.86, 0.88, 0.90)
        case .circuitGlow, .seeThrough:
            lcd = RGB(0.82, 0.83, 0.80)
        case .greyTracks, .linen:
            lcd = RGB(0.86, 0.85, 0.81)
        case .cleanPlates, .camoDigital:
            lcd = RGB(0.83, 0.85, 0.87)
        case .camoStealth, .stickerBomb:
            lcd = RGB(0.80, 0.82, 0.82)
        default:
            lcd = RGB(0.85, 0.87, 0.86)
        }

        return OneTapeBodyMaterialPalette(shell: base, key: key, ink: ink, lcd: lcd)
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
