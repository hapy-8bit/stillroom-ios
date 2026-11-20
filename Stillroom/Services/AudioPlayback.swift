import AVFoundation
import UIKit

struct PlaybackSnapshot: Equatable {
    var position: TimeInterval = 0
    var duration: TimeInterval = 0
    var isPlaying = false
    var isPreparing = false
}

/// One AVPlayer owns both local files and HTTP streams. UI samples this engine;
/// visual reel phases remain independent of its media clock.
@MainActor
final class AudioPlayback {
    var onSnapshot: (PlaybackSnapshot) -> Void = { _ in }
    var onFinish: () -> Void = {}
    var onError: (String) -> Void = { _ in }
    var onExternalPause: () -> Void = {}
    var onSeekCompleted: () -> Void = {}
    var onAnalysis: (AudioVisualizationFrame) -> Void = { _ in }
    private let player = AVPlayer()
    private var ticker: Any?
    private var itemObservation: NSKeyValueObservation?
    private var controlObservation: NSKeyValueObservation?
    private var observations: [NSObjectProtocol] = []
    private var itemNotifications: [NSObjectProtocol] = []
    private var activationTask: Task<Void, Never>?
    private var generation = 0
    private var seekGeneration = 0
    private var playWanted = false
    private var sessionReady = false
    private var seeking = false
    private var pendingSeek: TimeInterval?
    private var durationHint: TimeInterval = 0
    private var resumeAfterInterruption = false
    private var processingTap: AudioPCMProcessingTap?
    private var analysisTask: Task<Void, Never>?
    private var analysisGeneration = 0
    private var allowsAnalysis = true
    private var diagnosticState: (playing: Bool, preparing: Bool)?

    init() {
        player.automaticallyWaitsToMinimizeStalling = true
        allowsAnalysis = UIApplication.shared.applicationState != .background
        controlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.emit() }
        }
        let center = NotificationCenter.default
        observations.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) {
            [weak self] note in Task { @MainActor in self?.handleInterruption(note) }
        })
        observations.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) {
            [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.onExternalPause(); self?.pause() }
        })
        observations.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) {
            [weak self] _ in
            Task { @MainActor in
                self?.stop()
                self?.onError("系统音频服务已重置，请重新点播放。")
            }
        })
        observations.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) {
            [weak self] _ in
            Task { @MainActor in
                self?.allowsAnalysis = false
                self?.releaseAnalysis()
            }
        })
        observations.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) {
            [weak self] _ in
            Task { @MainActor in
                self?.allowsAnalysis = true
                self?.startAnalysis()
            }
        })
    }

    deinit {
        activationTask?.cancel()
        analysisTask?.cancel()
        if let ticker { player.removeTimeObserver(ticker) }
        itemObservation?.invalidate()
        controlObservation?.invalidate()
        (observations + itemNotifications).forEach(NotificationCenter.default.removeObserver)
    }

    func load(_ url: URL, durationHint: TimeInterval = 0) throws {
        PlaybackDiagnostics.shared.record(.load)
        guard url.isFileURL || ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
            throw LibraryError.missingAudio
        }
        var localDuration: TimeInterval = 0
        if url.isFileURL {
            // Header validation preserves synchronous import-file errors without
            // allocating a second playback engine or reading the whole recording.
            let file = try AVAudioFile(forReading: url)
            if file.processingFormat.sampleRate > 0 {
                localDuration = Double(file.length) / file.processingFormat.sampleRate
            }
        }
        stop()
        self.durationHint = localDuration > 0 ? localDuration :
            (durationHint.isFinite ? max(0, durationHint) : 0)
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] _, _ in
            Task { @MainActor in
                guard let self, let item, self.player.currentItem === item else { return }
                self.itemChanged(item)
            }
        }
        let center = NotificationCenter.default
        itemNotifications.append(center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) {
            [weak self, weak item] _ in
            Task { @MainActor in
                guard let self, let item, self.player.currentItem === item else { return }
                self.playWanted = false
                self.releaseAnalysis()
                self.removeTicker()
                self.emit()
                self.onFinish()
            }
        })
        itemNotifications.append(center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) {
            [weak self, weak item] _ in
            Task { @MainActor in
                guard let self, let item, self.player.currentItem === item else { return }
                self.failPlayback()
            }
        })
        emit()
    }

    func play() throws {
        PlaybackDiagnostics.shared.record(.play)
        guard let item = player.currentItem, item.status != .failed else { throw LibraryError.missingAudio }
        activationTask?.cancel()
        generation += 1
        let request = generation
        playWanted = true
        startAnalysis()
        emit()
        activationTask = Task { [weak self, weak item] in
            do {
                try await AudioSessionActivation.shared.activate()
                guard !Task.isCancelled, let self, let item, self.generation == request,
                      self.player.currentItem === item, self.playWanted else { return }
                self.sessionReady = true
                self.attemptPlayback()
            } catch {
                guard !Task.isCancelled, let self, self.generation == request else { return }
                self.failPlayback(error)
            }
        }
    }

    func pause() {
        PlaybackDiagnostics.shared.record(.pause, position: player.currentTime().seconds)
        generation += 1
        activationTask?.cancel()
        playWanted = false
        sessionReady = false
        resumeAfterInterruption = false
        player.pause()
        releaseAnalysis()
        removeTicker()
        emit()
    }

    func seek(_ seconds: TimeInterval) {
        PlaybackDiagnostics.shared.record(.seek, position: seconds)
        guard let item = player.currentItem, seconds.isFinite else { return }
        pendingSeek = mediaDuration > 0 ? MediaTime.clamped(seconds, duration: mediaDuration) : max(0, seconds)
        if item.status == .readyToPlay, !seeking { performPendingSeek(item) }
    }

    func stop() {
        PlaybackDiagnostics.shared.record(.stop)
        pause()
        seekGeneration += 1
        pendingSeek = nil
        seeking = false
        durationHint = 0
        itemObservation?.invalidate()
        itemObservation = nil
        itemNotifications.forEach(NotificationCenter.default.removeObserver)
        itemNotifications = []
        player.replaceCurrentItem(with: nil)
        emit()
    }

    private var mediaDuration: TimeInterval {
        let seconds = player.currentItem?.duration.seconds ?? 0
        return seconds.isFinite && seconds > 0 ? seconds : durationHint
    }

    private func itemChanged(_ item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            if pendingSeek != nil { performPendingSeek(item) } else { attemptPlayback() }
        case .failed: failPlayback(item.error)
        default: emit()
        }
    }

    private func attemptPlayback() {
        guard playWanted, sessionReady, !seeking,
              let item = player.currentItem, item.status == .readyToPlay else { emit(); return }
        if pendingSeek != nil { performPendingSeek(item); return }
        if mediaDuration > 0, player.currentTime().seconds >= mediaDuration - 0.001 {
            pendingSeek = 0
            performPendingSeek(item)
            return
        }
        player.play()
        startTicker()
        emit()
    }

    private func performPendingSeek(_ item: AVPlayerItem) {
        guard !seeking, let target = pendingSeek else { return }
        pendingSeek = nil
        seeking = true
        seekGeneration += 1
        let request = seekGeneration
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak item] _ in
            Task { @MainActor in
                guard let self, let item, self.seekGeneration == request,
                      self.player.currentItem === item else { return }
                self.seeking = false
                self.emit()
                // Keep at most one physical seek and the newest pending target.
                // Repeated wind intents must not keep canceling a slow HTTP seek.
                if self.pendingSeek != nil { self.performPendingSeek(item) }
                else { self.onSeekCompleted(); self.attemptPlayback() }
            }
        }
    }

    private func startTicker() {
        guard ticker == nil else { return }
        ticker = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                                                queue: .main) { [weak self] _ in
            Task { @MainActor in self?.emit() }
        }
    }

    private func removeTicker() {
        if let ticker { player.removeTimeObserver(ticker); self.ticker = nil }
    }

    private func emit() {
        let seconds = player.currentTime().seconds
        let playing = player.timeControlStatus == .playing && player.rate > 0
        let preparing = playWanted && !playing
        if diagnosticState?.playing != playing || diagnosticState?.preparing != preparing {
            diagnosticState = (playing, preparing)
            PlaybackDiagnostics.shared.record(.state, position: seconds,
                playing: playing, preparing: preparing)
        }
        if playing { processingTap?.markPlaybackStarted() }
        else if allowsAnalysis, playWanted, processingTap != nil { onAnalysis(.preparing) }
        onSnapshot(PlaybackSnapshot(position: seconds.isFinite ? max(0, seconds) : 0,
            duration: mediaDuration, isPlaying: playing, isPreparing: playWanted && !playing))
    }

    private func failPlayback(_ error: Error? = nil) {
        PlaybackDiagnostics.shared.record(.failure, error: (error ?? player.currentItem?.error) as NSError?)
        pause()
        // NSError can contain the authenticated streaming URL. Keep failures
        // actionable without allowing credentials into UI, logs or diagnostics.
        onError("音乐暂时无法播放，请检查服务器连接或音频格式后重试。")
    }

    private func startAnalysis() {
        guard allowsAnalysis, playWanted, processingTap == nil, analysisTask == nil,
              let item = player.currentItem else { return }
        analysisGeneration += 1
        let request = analysisGeneration
        onAnalysis(.preparing)
        analysisTask = Task { [weak self, weak item] in
            guard let item else { return }
            do {
                let tracks = try await item.asset.loadTracks(withMediaType: .audio)
                guard !Task.isCancelled, let self, self.analysisGeneration == request,
                      self.player.currentItem === item, self.playWanted, self.allowsAnalysis else { return }
                guard let track = tracks.first else { throw PCMAnalysisError.unavailable }
                let pipeline = try AudioPCMProcessingTap { [weak self, weak item] frame in
                    Task { @MainActor in
                        guard let self, let item, self.analysisGeneration == request,
                              self.player.currentItem === item, self.playWanted, self.allowsAnalysis,
                              self.player.timeControlStatus == .playing else { return }
                        self.onAnalysis(frame)
                    }
                }
                let parameters = AVMutableAudioMixInputParameters(track: track)
                parameters.audioTapProcessor = pipeline.tap
                let mix = AVMutableAudioMix()
                mix.inputParameters = [parameters]
                item.audioMix = mix
                self.processingTap = pipeline
                if self.player.timeControlStatus == .playing { pipeline.markPlaybackStarted() }
                self.analysisTask = nil
            } catch {
                guard !Task.isCancelled, let self, self.analysisGeneration == request else { return }
                self.analysisTask = nil
                PlaybackDiagnostics.shared.record(.analysisUnavailable, error: error as NSError)
                self.onAnalysis(.unsupported)
            }
        }
    }

    private func releaseAnalysis() {
        // Detach before dropping our tap owner. CoreMedia keeps its callback
        // context alive until finalize; queued worker frames fail generation checks.
        analysisGeneration += 1
        analysisTask?.cancel(); analysisTask = nil
        player.currentItem?.audioMix = nil
        processingTap = nil
        onAnalysis(.idle)
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
            let wasPlaying = playWanted || player.rate > 0
            onExternalPause()
            pause()
            resumeAfterInterruption = wasPlaying
        } else {
            let rawOptions = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = resumeAfterInterruption &&
                AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
            resumeAfterInterruption = false
            if shouldResume {
                do { try play() } catch { onError("音频中断后未能恢复，请点播放重试。") }
            }
        }
    }
}

