import AVFoundation
import Foundation

enum OneTapeTransportSoundError: Error, Equatable, LocalizedError {
    case missingResource
    case cannotStart
    case decoding

    var errorDescription: String? {
        "操作音效暂时无法播放，音乐播放不受影响。"
    }
}

@MainActor
protocol OneTapeTransportCuePlaying: AnyObject {
    var onFinish: (() -> Void)? { get set }
    var onFailure: (() -> Void)? { get set }
    // true accepts the request; deferred native preparation failures use onFailure.
    func play() -> Bool
    func stop()
}

/// A bounded UI effect voice. The music engine has already activated its audio
/// session before the policy acknowledges playback; this adapter never changes
/// category, activation, routing, system metadata, or the music analysis tap.
@MainActor
final class OneTapeTransportSoundService {
    typealias Factory = @MainActor (OneTapeTransportCue) throws -> any OneTapeTransportCuePlaying

    var onFailure: ((OneTapeTransportSoundError) -> Void)?
    private let makePlayer: Factory
    private var player: (any OneTapeTransportCuePlaying)?
    private var generation = 0

    init(onFailure: ((OneTapeTransportSoundError) -> Void)? = nil,
         makePlayer: @escaping Factory = OneTapeTransportSoundService.bundledPlayer) {
        self.onFailure = onFailure
        self.makePlayer = makePlayer
    }

    func play(_ cue: OneTapeTransportCue) throws {
        stop()
        let request = generation
        let voice: any OneTapeTransportCuePlaying
        do { voice = try makePlayer(cue) }
        catch let error as OneTapeTransportSoundError { throw error }
        catch { throw OneTapeTransportSoundError.decoding }
        player = voice
        voice.onFinish = { [weak self] in self?.finish(request: request) }
        voice.onFailure = { [weak self] in
            guard let self, request == self.generation else { return }
            self.stop()
            self.onFailure?(.decoding)
        }
        guard voice.play() else {
            stop()
            throw OneTapeTransportSoundError.cannotStart
        }
    }

    func stop() {
        generation += 1
        player?.onFinish = nil
        player?.onFailure = nil
        player?.stop()
        player = nil
    }

    private func finish(request: Int) {
        guard request == generation else { return }
        stop()
    }

    static func bundledPlayer(_ cue: OneTapeTransportCue) throws -> any OneTapeTransportCuePlaying {
        try bundledPlayer(cue, volume: 0.65)
    }

    static func bundledPlayer(_ cue: OneTapeTransportCue, volume: Float) throws -> any OneTapeTransportCuePlaying {
        guard let url = Bundle.main.url(forResource: cue.resourceName, withExtension: "wav") else {
            throw OneTapeTransportSoundError.missingResource
        }
        return OneTapeNativeCuePlayer(url: url, volume: volume)
    }
}

/// AVAudioPlayer.play() implicitly prepares an unprepared voice, which can
/// synchronously activate the existing route. Serial preparation keeps that
/// system work off the UI actor without reconfiguring the music session.
private actor OneTapeCuePreparation {
    static let shared = OneTapeCuePreparation()

    func prepare(url: URL, volume: Float) throws -> AVAudioPlayer {
        try Task.checkCancellation()
        let audio = try AVAudioPlayer(contentsOf: url)
        audio.numberOfLoops = 0
        audio.volume = min(1, max(0, volume))
        guard audio.prepareToPlay() else { throw OneTapeTransportSoundError.cannotStart }
        do { try Task.checkCancellation() }
        catch {
            audio.stop()
            throw error
        }
        // This is an ownership handoff: the actor never retains or touches the
        // prepared player again; its native delegate/play/stop now belong to UI.
        return audio
    }
}

@MainActor
private final class OneTapeNativeCuePlayer: NSObject, OneTapeTransportCuePlaying, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?
    var onFailure: (() -> Void)?
    private let url: URL
    private let volume: Float
    private var audio: AVAudioPlayer?
    private var preparationTask: Task<Void, Never>?
    private var generation = 0

    init(url: URL, volume: Float) {
        self.url = url
        self.volume = volume
        super.init()
    }

    deinit { preparationTask?.cancel() }

    func play() -> Bool {
        stop()
        let request = generation
        let url = self.url
        let volume = self.volume
        preparationTask = Task { [weak self] in
            do {
                let prepared = try await OneTapeCuePreparation.shared.prepare(url: url, volume: volume)
                try Task.checkCancellation()
                guard let self, request == self.generation else { return }
                self.preparationTask = nil
                self.audio = prepared
                prepared.delegate = self
                guard prepared.play() else {
                    self.stop()
                    self.onFailure?()
                    return
                }
            } catch is CancellationError {
                // A newer tap or scene suspension owns the next voice. A late
                // completion must neither sound nor report a stale failure.
            } catch {
                guard let self, request == self.generation else { return }
                PlaybackDiagnostics.shared.record(.cueFailure, error: error as NSError)
                self.stop()
                self.onFailure?()
            }
        }
        return true
    }

    func stop() {
        generation += 1
        preparationTask?.cancel()
        preparationTask = nil
        audio?.delegate = nil
        audio?.stop()
        audio = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.audio === player else { return }
            if flag { self.onFinish?() } else { self.onFailure?() }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.audio === player else { return }
            self.onFailure?()
        }
    }
}
