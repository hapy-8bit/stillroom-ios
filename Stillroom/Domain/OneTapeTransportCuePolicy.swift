import Foundation

enum OneTapeTransportCue: String, CaseIterable, Sendable {
    case playLatch
    case pauseRelease
    case trackStep

    var resourceName: String {
        switch self {
        case .playLatch: return "OneTapePlayLatch"
        case .pauseRelease: return "OneTapePauseRelease"
        case .trackStep: return "OneTapeTrackStep"
        }
    }
}

/// Feedback is an acknowledgement of a recent foreground command, never a
/// second playback state or a side effect of restoring an engine snapshot.
struct OneTapeTransportCuePolicy: Sendable {
    private struct Pending: Sendable {
        let trackID: String
        let cue: OneTapeTransportCue
        let expiresAt: TimeInterval
        var sawPreparing = false
    }

    private var pending: Pending?
    private let intentLifetime: TimeInterval

    init(intentLifetime: TimeInterval = 8) {
        self.intentLifetime = intentLifetime.isFinite ? max(0, intentLifetime) : 8
    }

    mutating func userToggleRequested(
        trackID: String?, isPlaying: Bool, isPreparing: Bool,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        pending = nil
        guard let trackID, !trackID.isEmpty, now.isFinite else { return }
        // Canceling a still-buffering request has no running mechanism to stop.
        guard isPlaying || !isPreparing else { return }
        pending = Pending(trackID: trackID, cue: isPlaying ? .pauseRelease : .playLatch,
                          expiresAt: now + intentLifetime)
    }

    mutating func userPlayRequested(
        trackID: String?, isPlaying: Bool,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        pending = nil
        guard !isPlaying, let trackID, !trackID.isEmpty, now.isFinite else { return }
        pending = Pending(trackID: trackID, cue: .playLatch, expiresAt: now + intentLifetime)
    }

    mutating func reconcile(
        trackID: String?, isPlaying: Bool, isPreparing: Bool,
        hasError: Bool = false, isForeground: Bool,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> OneTapeTransportCue? {
        guard var request = pending else { return nil }
        guard isForeground, !hasError, now.isFinite, now <= request.expiresAt,
              trackID == request.trackID else {
            pending = nil
            return nil
        }
        switch request.cue {
        case .playLatch:
            if isPlaying {
                pending = nil
                return .playLatch
            }
            // load() emits an idle snapshot before play() starts preparation.
            // Only a later return from preparing to idle cancels the intent.
            if isPreparing { request.sawPreparing = true }
            else if request.sawPreparing { pending = nil; return nil }
            pending = request
        case .pauseRelease:
            if !isPlaying, !isPreparing {
                pending = nil
                return .pauseRelease
            }
        case .trackStep:
            // Track keys acknowledge a synchronous accepted queue/seek command
            // in MusicStore; a media snapshot must never invent another click.
            pending = nil
        }
        return nil
    }

    mutating func cancel() { pending = nil }
}
