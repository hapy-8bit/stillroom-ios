import AudioToolbox
import UIKit

@MainActor
protocol OneTapeOpeningFeedbackProviding: AnyObject {
    func prepare() throws
    func tickPerforation()
    func snapStrip()
    func latch()
    func stop()
}

/// System UI audio respects the silent switch and never activates or
/// reconfigures the authoritative music engine's AVAudioSession.
@MainActor
final class OneTapeOpeningFeedbackService: OneTapeOpeningFeedbackProviding {
    private var tickSound: SystemSoundID = 0
    private var snapSound: SystemSoundID = 0
    private var latchSound: SystemSoundID = 0
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let snapHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let latchHaptic = UIImpactFeedbackGenerator(style: .rigid)

    func prepare() throws {
        lightHaptic.prepare()
        snapHaptic.prepare()
        latchHaptic.prepare()
        if latchSound == 0 {
            latchSound = try loadSystemSound(named: "OneTapePlayLatch")
        }
        if snapSound == 0 {
            snapSound = (try? loadSystemSound(named: "OneTapePauseRelease")) ?? latchSound
        }
        if tickSound == 0 {
            tickSound = (try? loadSystemSound(named: "OneTapeTrackStep")) ?? 0
        }
    }

    func tickPerforation() {
        lightHaptic.impactOccurred(intensity: 0.55)
        lightHaptic.prepare()
    }

    func snapStrip() {
        snapHaptic.impactOccurred(intensity: 0.85)
        if snapSound != 0 { AudioServicesPlaySystemSound(snapSound) }
    }

    func latch() {
        latchHaptic.impactOccurred(intensity: 0.72)
        if latchSound != 0 { AudioServicesPlaySystemSound(latchSound) }
    }

    func stop() {
        if tickSound != 0 {
            AudioServicesDisposeSystemSoundID(tickSound)
            tickSound = 0
        }
        if snapSound != 0 && snapSound != latchSound {
            AudioServicesDisposeSystemSoundID(snapSound)
        }
        snapSound = 0
        if latchSound != 0 {
            AudioServicesDisposeSystemSoundID(latchSound)
            latchSound = 0
        }
    }

    private func loadSystemSound(named resource: String) throws -> SystemSoundID {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "wav") else {
            throw OneTapeTransportSoundError.missingResource
        }
        var soundID: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &soundID) == kAudioServicesNoError else {
            throw OneTapeTransportSoundError.cannotStart
        }
        return soundID
    }

    deinit {
        let tick = tickSound
        let snap = snapSound
        let latch = latchSound
        if tick != 0 { AudioServicesDisposeSystemSoundID(tick) }
        if snap != 0 {
            if snap != latch { AudioServicesDisposeSystemSoundID(snap) }
        }
        if latch != 0 { AudioServicesDisposeSystemSoundID(latch) }
    }
}
