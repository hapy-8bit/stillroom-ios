import Foundation

enum OneTapeTransportAction: CaseIterable {
    case previous, play, next
}

enum OneTapeDestination: Hashable {
    case player, library, insights
}

enum OneTapeCustomizationTab: String, CaseIterable, Identifiable {
    case tape, print, reel, body, screen
    var id: String { rawValue }
}

enum OneTapePanel: String, Identifiable {
    case settings, studio, sources, localImport

    var id: String { rawValue }
}

/// Navigation and overlays only. Playback and media time come from PlayerStore;
/// this value never caches another copy of the engine state.
struct OneTapePresentation {
    private(set) var destination: OneTapeDestination = .player
    private(set) var menuVisible = false
    private(set) var customizationVisible = false
    private(set) var menuGeneration = 0
    var panel: OneTapePanel?

    mutating func toggleMenu() {
        menuGeneration += 1
        customizationVisible = false
        menuVisible.toggle()
    }

    mutating func toggleCustomization() {
        menuGeneration += 1
        destination = .player
        menuVisible = true
        customizationVisible.toggle()
    }

    mutating func closeCustomization() {
        menuGeneration += 1
        customizationVisible = false
    }

    mutating func navigate(to destination: OneTapeDestination) {
        menuGeneration += 1
        self.destination = destination
        customizationVisible = false
        // Returning to the player keeps its contextual action reachable. The
        // existing generation-guarded idle timer dismisses only that page's HUD.
        menuVisible = true
    }

    mutating func present(_ panel: OneTapePanel) {
        menuGeneration += 1
        self.panel = panel
    }

    mutating func expireMenu(generation: Int) {
        guard generation == menuGeneration, destination == .player, panel == nil,
              !customizationVisible else { return }
        menuVisible = false
    }

    mutating func suspend() {
        menuGeneration += 1
        if destination == .player, !customizationVisible { menuVisible = false }
    }

}
