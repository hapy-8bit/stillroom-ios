import UIKit

@MainActor
protocol OneTapeLibraryHapticProviding {
    func prepare()
    func selectionChanged()
}

extension UISelectionFeedbackGenerator: OneTapeLibraryHapticProviding {}

/// The shelf owns one short, quiet effect voice and one selection haptic.
/// It neither configures the music session nor touches the authoritative player.
@MainActor
final class OneTapeLibraryFeedbackService {
    var onFailure: ((OneTapeTransportSoundError) -> Void)?
    private let sound: OneTapeTransportSoundService
    private let haptic: any OneTapeLibraryHapticProviding
    private var policy = OneTapeLibraryBrowseFeedbackPolicy()
    private var failureReported = false

    init(sound: OneTapeTransportSoundService? = nil,
         haptic: (any OneTapeLibraryHapticProviding)? = nil) {
        self.sound = sound ?? OneTapeTransportSoundService(makePlayer: { cue in
            try OneTapeTransportSoundService.bundledPlayer(cue, volume: 0.23)
        })
        self.haptic = haptic ?? UISelectionFeedbackGenerator()
        self.sound.onFailure = { [weak self] error in self?.report(error) }
    }

    func handle(_ event: OneTapeLibraryBrowseEvent,
                now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        let pulse = policy.handle(event, now: now)
        switch event {
        case .began:
            failureReported = false
            haptic.prepare()
        case .ended:
            sound.stop()
        case .crossed:
            break
        }
        guard pulse else { return }
        haptic.selectionChanged()
        haptic.prepare()
        do { try sound.play(.trackStep) }
        catch { report((error as? OneTapeTransportSoundError) ?? .cannotStart) }
    }

    func stop() { handle(.ended) }

    private func report(_ error: OneTapeTransportSoundError) {
        guard !failureReported else { return }
        failureReported = true
        onFailure?(error)
    }
}
