import Foundation

/// Button finish follows the selected shell. These are our coordinated finish
/// values, not recovered RGB values from every Cassette resource variant.
struct OneTapeTransportMaterial: Equatable, Sendable {
    struct RGB: Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double

        init(_ red: Double, _ green: Double, _ blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        var luminance: Double {
            func linear(_ component: Double) -> Double {
                component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }

        func mixed(with other: RGB, fraction: Double) -> RGB {
            let amount = min(1, max(0, fraction))
            return RGB(red + (other.red - red) * amount,
                       green + (other.green - green) * amount,
                       blue + (other.blue - blue) * amount)
        }
    }

    let face: RGB
    let symbol: RGB
    let usesOriginalArtwork: Bool

    static let graphitePlaySymbol = RGB(0.93, 0.32, 0.14)

    static let original = OneTapeTransportMaterial(
        face: RGB(0.13, 0.13, 0.13), symbol: RGB(0.47, 0.47, 0.47),
        usesOriginalArtwork: true)

    init(appearance: OneTapeAppearance, artworkColor: RGB? = nil) {
        if let material = appearance.bodyMaterial {
            let palette = material.palette(color: appearance.bodyColor)
            self.init(face: palette.key, symbol: palette.ink)
            return
        }
        // Graphite's satin gunmetal keys and warm orange play mark are part of
        // its hardware identity, matching Cassette 1.0.5 `BodyGraphite`.
        if appearance.bodyStyle == .graphite {
            self.init(face: RGB(0.20, 0.21, 0.22), symbol: RGB(0.84, 0.85, 0.86))
            return
        }
        if appearance.bodyColor == .black {
            switch appearance.bodyStyle {
            case .black: self = .original
            case .graphite: self = .original // Handled above.
            case .adaptive:
                let face = Self.adaptiveColor(artworkColor)
                self.init(face: face, symbol: Self.contrastingSymbol(for: face))
            case .cover:
                let face = (artworkColor ?? RGB(0.63, 0.65, 0.62))
                    .mixed(with: RGB(0.78, 0.79, 0.76), fraction: 0.65)
                self.init(face: face, symbol: Self.contrastingSymbol(for: face))
            }
            return
        }
        switch appearance.bodyColor {
        case .black: self = .original
        case .navy: self.init(face: RGB(0.20, 0.29, 0.36), symbol: RGB(0.84, 0.89, 0.91))
        case .green: self.init(face: RGB(0.21, 0.40, 0.33), symbol: RGB(0.87, 0.93, 0.87))
        case .slate: self.init(face: RGB(0.45, 0.53, 0.58), symbol: RGB(0.12, 0.16, 0.18))
        case .dove: self.init(face: RGB(0.64, 0.68, 0.66), symbol: RGB(0.15, 0.18, 0.16))
        case .cognac: self.init(face: RGB(0.59, 0.37, 0.26), symbol: RGB(0.97, 0.92, 0.85))
        case .white: self.init(face: RGB(0.86, 0.86, 0.82), symbol: RGB(0.24, 0.25, 0.22))
        case .garden: self.init(face: RGB(0.52, 0.63, 0.44), symbol: RGB(0.17, 0.22, 0.12))
        }
    }

    static func adaptiveColor(_ artwork: RGB?) -> RGB {
        guard let artwork else { return RGB(0.28, 0.49, 0.48) }
        // Keep the extracted hue while bounding very dark/white covers to a
        // usable machine finish. This value never changes the saved choice.
        if artwork.luminance < 0.08 {
            return artwork.mixed(with: RGB(1, 1, 1), fraction: 0.24)
        }
        if artwork.luminance > 0.65 {
            return artwork.mixed(with: RGB(0, 0, 0), fraction: 0.22)
        }
        return artwork
    }

    private static func contrastingSymbol(for face: RGB) -> RGB {
        face.luminance > 0.28 ? RGB(0.08, 0.10, 0.09) : RGB(0.94, 0.96, 0.94)
    }

    private init(face: RGB, symbol: RGB, usesOriginalArtwork: Bool = false) {
        self.face = face
        self.symbol = symbol
        self.usesOriginalArtwork = usesOriginalArtwork
    }
}
