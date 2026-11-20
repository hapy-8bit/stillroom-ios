import UIKit

/// Scene rotation is a window responsibility. Views request it through their action
/// callback; no media state or system-wide orientation-lock setting is changed.
@MainActor enum RoomOrientationAdapter {
    static func toggle(onFailure: @escaping (String) -> Void) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive && $0.windows.contains(where: \.isKeyWindow) }) else {
            onFailure("当前窗口尚未准备好，请稍后再切换横竖屏。")
            return
        }
        // Recovered reference masks: landscape -> portrait (2), otherwise landscapeRight (8).
        let target: UIInterfaceOrientationMask = scene.interfaceOrientation.isLandscape ? .portrait : .landscapeRight
        scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: target)) { error in
            Task { @MainActor in onFailure("横竖屏切换失败：" + error.localizedDescription) }
        }
    }
}
