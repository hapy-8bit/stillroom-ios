import Foundation

/// Optical drawing choices only. They never hold player, file or sensor state.
enum OneTapeBodyMaterial: String, Codable, CaseIterable, Identifiable, Sendable {
    case frostedGlass, smokedGlass, brushedAluminum, darkTitanium
    var id: String { rawValue }

    var isGlass: Bool { self == .frostedGlass || self == .smokedGlass }

    var title: String {
        switch self {
        case .frostedGlass: "雾面玻璃"
        case .smokedGlass: "烟晶玻璃"
        case .brushedAluminum: "拉丝铝"
        case .darkTitanium: "深色钛金属"
        }
    }

    var engraving: String {
        switch self {
        case .frostedGlass: "FROSTED  /  GLASS"
        case .smokedGlass: "SMOKED  /  GLASS"
        case .brushedAluminum: "ALUMINUM  /  6061"
        case .darkTitanium: "TITANIUM  /  SATIN"
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
        }
        let shell = color == .black ? base : base.mixed(with: color.materialRGB, fraction: 0.72)
        let key = shell.mixed(with: RGB(1, 1, 1), fraction: isGlass ? 0.10 : 0.04)
        let light = RGB(0.94, 0.97, 0.97)
        let dark = RGB(0.065, 0.085, 0.095)
        let lightContrast = (light.luminance + 0.05) / (key.luminance + 0.05)
        let darkContrast = (key.luminance + 0.05) / (dark.luminance + 0.05)
        return OneTapeBodyMaterialPalette(shell: shell, key: key,
            ink: lightContrast > darkContrast ? light : dark,
            lcd: shell.mixed(with: RGB(0.88, 0.92, 0.91), fraction: isGlass ? 0.75 : 0.86))
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
