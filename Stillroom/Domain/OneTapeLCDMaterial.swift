import Foundation

/// Only the default readout shares the shell material. Art screens retain
/// their designed palettes and all readouts keep the same real media state.
struct OneTapeLCDMaterial: Equatable, Sendable {
    typealias RGB = OneTapeTransportMaterial.RGB
    let background: RGB
    let ink: RGB

    static let original = OneTapeLCDMaterial(
        background: RGB(218 / 255, 223 / 255, 224 / 255), ink: RGB(17 / 255, 22 / 255, 18 / 255))

    init(appearance: OneTapeAppearance, artworkColor: RGB? = nil) {
        ink = Self.original.ink
        if let material = appearance.bodyMaterial {
            background = material.palette(color: appearance.bodyColor).lcd
            return
        }
        switch appearance.bodyStyle {
        case .black: background = Self.original.background
        case .graphite: background = RGB(0.83, 0.84, 0.85)
        case .adaptive:
            let finish = OneTapeTransportMaterial(appearance: appearance, artworkColor: artworkColor)
            background = finish.face.mixed(with: RGB(0.86, 0.90, 0.88), fraction: 0.58)
        case .cover:
            let finish = OneTapeTransportMaterial(appearance: appearance, artworkColor: artworkColor)
            background = finish.face.mixed(with: RGB(0.88, 0.89, 0.86), fraction: 0.62)
        }
    }

    private init(background: RGB, ink: RGB) {
        self.background = background
        self.ink = ink
    }
}
