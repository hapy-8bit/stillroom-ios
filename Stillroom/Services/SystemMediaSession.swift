import MediaPlayer
import UIKit

/// Installs remote commands once and removes the exact handlers when the session is released.
@MainActor
final class SystemMediaSession {
    var onPlay: () -> Void = {}
    var onPause: () -> Void = {}
    var onNext: () -> Void = {}
    var onPrevious: () -> Void = {}
    var onSeek: (Double) -> Void = { _ in }
    private var targets: [(MPRemoteCommand, Any)] = []
    private var currentKey: [String] = []
    private var info: [String: Any] = [:]
    private weak var currentArtwork: UIImage?

    init() {
        let center = MPRemoteCommandCenter.shared()
        register(center.playCommand) { [weak self] in self?.onPlay() }
        register(center.pauseCommand) { [weak self] in self?.onPause() }
        register(center.nextTrackCommand) { [weak self] in self?.onNext() }
        register(center.previousTrackCommand) { [weak self] in self?.onPrevious() }
        let seek = center.changePlaybackPositionCommand
        seek.isEnabled = true
        let token = seek.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.onSeek(event.positionTime) }
            return .success
        }
        targets.append((seek, token))
    }

    deinit { targets.forEach { $0.0.removeTarget($0.1) } }

    private func register(_ command: MPRemoteCommand, action: @escaping @MainActor () -> Void) {
        command.isEnabled = true
        let token = command.addTarget { _ in
            Task { @MainActor in action() }
            return .success
        }
        targets.append((command, token))
    }

    func update(track: Track, snapshot: PlaybackSnapshot, artwork: UIImage?) {
        let key = [track.id, track.title, track.artist, track.album, track.artworkFile ?? ""]
        if currentKey != key || currentArtwork !== artwork {
            currentKey = key
            currentArtwork = artwork
            info = [MPMediaItemPropertyTitle: track.title, MPMediaItemPropertyArtist: track.artist,
                    MPMediaItemPropertyAlbumTitle: track.album, MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue]
            if let artwork {
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            }
        }
        info[MPMediaItemPropertyPlaybackDuration] = snapshot.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = snapshot.position
        info[MPNowPlayingInfoPropertyPlaybackRate] = snapshot.isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        currentKey = []; currentArtwork = nil; info = [:]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}

