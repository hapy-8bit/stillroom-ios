import SwiftUI

private struct RoomMotionVisibilityKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Visibility of decorative animation, independent of authoritative audio playback.
    var roomMotionVisible: Bool {
        get { self[RoomMotionVisibilityKey.self] }
        set { self[RoomMotionVisibilityKey.self] = newValue }
    }
}
