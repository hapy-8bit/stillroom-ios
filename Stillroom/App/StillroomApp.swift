import SwiftUI

@main
struct StillroomApp: App {
    @UIApplicationDelegateAdaptor(OneTapeApplicationDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
            if Self.usesLegacyPresentation {
                LegacyStillroomHost()
            } else {
                OneTapeRoot()
            }
        }
    }

    static var usesLegacyPresentation: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--legacy-stillroom") ||
            arguments.contains("--original-demo-fixture") ||
            arguments.contains("--record-opening-preview")
    }
}

private struct LegacyStillroomHost: View {
    @StateObject private var player = PlayerStore()

    var body: some View {
        RoomRoot().environmentObject(player)
            .task { await player.restore() }
    }
}

