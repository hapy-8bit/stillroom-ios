import UIKit

/// One Tape rotates controls inside its portrait machine. The retained legacy
/// presentation continues to support its existing full-scene landscape layouts.
@MainActor final class OneTapeApplicationDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        PlaybackDiagnostics.shared.start()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        PlaybackDiagnostics.shared.record(.willTerminate)
        PlaybackDiagnostics.shared.stop()
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        StillroomApp.usesLegacyPresentation ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait
    }
}
