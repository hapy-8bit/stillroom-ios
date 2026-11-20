import Foundation

/// Stored identities remain decodable even when their artwork is not offered.
/// Resolve only at presentation boundaries; unrelated appearance saves must keep
/// the user's legacy screen value until they explicitly choose another screen.
enum OneTapeScreenAvailability {
    static let selectableStyles: [OneTapeAppearance.ScreenStyle] = [
        .lcd, .fluid, .rain, .trails, .name, .meters, .fox
    ]

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
