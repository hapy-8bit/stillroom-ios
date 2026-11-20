import SwiftUI

@MainActor
final class OneTapeStore: ObservableObject {
    @Published private(set) var presentation = OneTapePresentation()
    // Keep the selected category with navigation state so modal presentation
    // cannot reset it when its visual subtree is recreated.
    @Published var customizationTab: OneTapeCustomizationTab = .tape
    @Published var libraryLayout: OneTapeLibraryLayout = .shelf {
        didSet { behaviorDefaults.set(libraryLayout.rawValue, forKey: "oneTape.library-layout.v1") }
    }
    @Published var appearance = OneTapeAppearance() {
        didSet {
            do { try appearancePreferences.save(appearance) }
            catch { appearanceNotice = "外观已用于当前预览，但设置未能保存。原有设置记录已保留。" }
        }
    }
    @Published var appearanceNotice: String?
    @Published var keepAwake = true {
        didSet {
            behaviorDefaults.set(keepAwake, forKey: "oneTape.keepAwake.v1")
            screenAwake.update(enabled: keepAwake, active: isActive)
        }
    }
    private var idleTask: Task<Void, Never>?
    private let screenAwake = OneTapeScreenAwakeService()
    private var isActive = false
    private let appearancePreferences: OneTapeAppearancePreferences
    private let behaviorDefaults: UserDefaults

    init(appearancePreferences: OneTapeAppearancePreferences = .applicationPreferences(),
         behaviorDefaults: UserDefaults = .standard) {
        self.appearancePreferences = appearancePreferences
        self.behaviorDefaults = behaviorDefaults
        _libraryLayout = Published(initialValue: OneTapeLibraryLayout(
            rawValue: behaviorDefaults.string(forKey: "oneTape.library-layout.v1") ?? "") ?? .shelf)
        keepAwake = behaviorDefaults.object(forKey: "oneTape.keepAwake.v1") as? Bool ?? true
        // Initialize the wrapper directly: invoking its setter here triggers
        // didSet and re-encodes a record that should be read-only on restore.
        do { _appearance = Published(initialValue: try appearancePreferences.load()) }
        catch { appearanceNotice = "外观设置暂时无法读取，当前使用默认外观。原有设置记录已保留。" }
    }

    var panel: OneTapePanel? {
        get { presentation.panel }
        set {
            presentation.panel = newValue
            scheduleIdle()
        }
    }

    func toggleMenu() {
        presentation.toggleMenu()
        scheduleIdle()
    }

    func navigate(to destination: OneTapeDestination) {
        presentation.navigate(to: destination)
        scheduleIdle()
    }

    func toggleCustomization() {
        presentation.toggleCustomization()
        scheduleIdle()
    }

    func closeCustomization() {
        presentation.closeCustomization()
        scheduleIdle()
    }

    func present(_ panel: OneTapePanel) {
        presentation.present(panel)
        idleTask?.cancel()
    }

    func setGlassOpen(_ open: Bool) {
        guard appearance.glassOpen != open else { return }
        // Gesture samples stay in the leaf view. Commit/persist only the released
        // endpoint, sharing the same value with the customization glass picker.
        appearance.glassOpen = open
    }

    func cycleScreen() {
        appearance.screenStyle = OneTapeScreenAvailability.nextStyle(after: appearance.screenStyle)
    }

    func suspend() {
        isActive = false
        screenAwake.update(enabled: keepAwake, active: false)
        idleTask?.cancel()
        idleTask = nil
        presentation.suspend()
    }

    func activate() {
        isActive = true
        screenAwake.update(enabled: keepAwake, active: true)
    }

    private func scheduleIdle() {
        idleTask?.cancel()
        idleTask = nil
        guard presentation.menuVisible, presentation.destination == .player,
              presentation.panel == nil, !presentation.customizationVisible else { return }
        let generation = presentation.menuGeneration
        idleTask = Task { [weak self] in
            do {
                // USB reference capture places automatic dismissal about six
                // seconds after the tap; it is not tied to media playback.
                try await Task.sleep(for: .seconds(6))
                try Task.checkCancellation()
            } catch { return }
            // A stale timeout cannot dismiss a newer navigation gesture.
            self?.presentation.expireMenu(generation: generation)
        }
    }

    deinit { idleTask?.cancel() }
}
