import AudioToolbox
import UIKit

@MainActor
protocol OneTapeOpeningFeedbackProviding: AnyObject {
    func prepare() throws
    func latch()
    func stop()
}

/// System UI audio respects the silent switch and does not activate or
/// reconfigure the authoritative music engine's AVAudioSession.
@MainActor
final class OneTapeOpeningFeedbackService: OneTapeOpeningFeedbackProviding {
    private var sound: SystemSoundID = 0
    private let haptic = UIImpactFeedbackGenerator(style: .rigid)

    func prepare() throws {
        haptic.prepare()
        guard sound == 0 else { return }
        guard let url = Bundle.main.url(forResource: "OneTapePlayLatch", withExtension: "wav") else {
            throw OneTapeTransportSoundError.missingResource
        }
        guard AudioServicesCreateSystemSoundID(url as CFURL, &sound) == kAudioServicesNoError else {
            throw OneTapeTransportSoundError.cannotStart
        }
    }

    func latch() {
        haptic.impactOccurred(intensity: 0.75)
        if sound != 0 { AudioServicesPlaySystemSound(sound) }
    }

    func stop() {
        if sound != 0 { AudioServicesDisposeSystemSoundID(sound); sound = 0 }
    }

    deinit { if sound != 0 { AudioServicesDisposeSystemSoundID(sound) } }
}
