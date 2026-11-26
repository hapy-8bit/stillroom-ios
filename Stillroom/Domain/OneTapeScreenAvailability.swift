import Foundation

/// Unified 5-family screen taxonomy aligned with Cassette 1.0.5's reflective
/// monochrome LCD displays. Domain owns classification and availability only.
enum OneTapeScreenCategory: String, CaseIterable, Identifiable, Sendable {
    case instrument
    case fluid
    case physics
    case sandArt
    case character

    var id: String { rawValue }

    var title: String {
        switch self {
        case .instrument: "读数仪表"
        case .fluid: "流体波纹"
        case .physics: "物理粒子"
        case .sandArt: "曲目沙画"
        case .character: "角色"
        }
    }

    var subtitle: String {
        switch self {
        case .instrument: "像素读数与真实音频波形"
        case .fluid: "单色黑液与波纹介质"
        case .physics: "声学驻波与物理场图案"
        case .sandArt: "歌名与封面的细沙重构"
        case .character: "随音乐律动与打盹的角色"
        }
    }

    /// Complete planned catalog per family (all unified on the reflective LCD substrate).
    var allStyles: [OneTapeAppearance.ScreenStyle] {
        switch self {
        case .instrument: [.lcd, .oscilloscope, .meters, .waterfall]
        case .fluid: [.fluid, .water, .ink, .smoke]
        case .physics: [.sand, .dunes, .iron, .growth, .harmonograph]
        case .sandArt: [.name, .cover]
        case .character: [.fox]
        }
    }

    /// Active GPU-accelerated reflective LCD catalog across all 5 screen families.
    var activeStyles: [OneTapeAppearance.ScreenStyle] {
        switch self {
        case .instrument: [.lcd, .oscilloscope]
        case .fluid: [.fluid, .water]
        case .physics: [.sand, .dunes, .iron]
        case .sandArt: [.name]
        case .character: [.fox]
        }
    }
}

/// Stored identities remain decodable even when retired (`rain`, `trails`) or not yet active.
/// Resolve only at presentation boundaries so saved preferences never break on upgrade.
enum OneTapeScreenAvailability {
    static let selectableStyles: [OneTapeAppearance.ScreenStyle] =
        OneTapeScreenCategory.allCases.flatMap(\.activeStyles)

    static func resolvedStyle(_ stored: OneTapeAppearance.ScreenStyle) -> OneTapeAppearance.ScreenStyle {
        selectableStyles.contains(stored) ? stored : .lcd
    }

    static func nextStyle(after stored: OneTapeAppearance.ScreenStyle) -> OneTapeAppearance.ScreenStyle {
        guard let index = selectableStyles.firstIndex(of: stored) else { return .lcd }
        return selectableStyles[(index + 1) % selectableStyles.count]
    }
}

extension OneTapeAppearance.ScreenStyle {
    var isSelectable: Bool { OneTapeScreenAvailability.selectableStyles.contains(self) }
    var resolvedStyle: Self { OneTapeScreenAvailability.resolvedStyle(self) }
}
