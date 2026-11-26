import Foundation

/// Coordinates real-time playback observation with `ListeningSessionTracker` and
/// `ListeningLedgerStore` so Insights stays synchronized with the single audio engine.
extension PlayerStore {
    func observeListeningSnapshot(_ value: PlaybackSnapshot) {
        let track = (currentTrack != nil && loadedID == currentTrack?.id) ? currentTrack : nil
        let events = listeningTracker.observe(
            track: track,
            position: value.position,
            duration: value.duration,
            isPlaying: value.isPlaying,
            isWinding: windingController.isWinding || trackWindupController.isActive
        )
        persistListeningEvents(events)
        publishLiveListeningEventIfNeeded()
    }

    func completeListeningSession() {
        if let finished = listeningTracker.markTrackFinished() {
            persistListeningEvents([finished])
        }
        liveListeningEvent = nil
        lastPublishedLiveSecond = -1
    }

    func flushListeningLedger() {
        if let flushed = listeningTracker.flushPreservingSession() {
            persistListeningEvents([flushed])
        }
        publishLiveListeningEventIfNeeded(force: true)
    }

    func noteListeningSeek() {
        listeningTracker.noteSeek()
    }

    private func persistListeningEvents(_ events: [ListeningSessionEvent]) {
        guard !events.isEmpty else { return }
        for event in events {
            do {
                listeningLedger = try listeningLedgerStore.upsert(event)
            } catch {
                if !listeningLedgerFailureNotified {
                    listeningLedgerFailureNotified = true
                    notice("聆听记录未能保存，原记录文件已保留，不影响正常播放。")
                }
            }
        }
    }

    private func publishLiveListeningEventIfNeeded(force: Bool = false) {
        let current = listeningTracker.liveEventForDisplay
        guard let current else {
            if liveListeningEvent != nil {
                liveListeningEvent = nil
                lastPublishedLiveSecond = -1
            }
            return
        }
        let wholeSecond = Int(current.listenedSeconds)
        if force || liveListeningEvent?.id != current.id || wholeSecond != lastPublishedLiveSecond {
            lastPublishedLiveSecond = wholeSecond
            liveListeningEvent = current
        }
    }
}
