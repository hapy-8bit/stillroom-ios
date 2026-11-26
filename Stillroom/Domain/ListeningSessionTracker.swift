import Foundation

/// Pure state machine that turns engine media-clock snapshots (in seconds) into durable
/// `ListeningSessionEvent` checkpoints. Seeking, pausing, and fast-winding never inflate
/// listening duration; pause/resume on the same track reuses one stable session UUID.
struct ListeningSessionTracker: Sendable {
    private(set) var activeEvent: ListeningSessionEvent?
    private var lastPosition: Double?
    private var lastClockAt: Date?
    private var lastPersistedSeconds: Double = 0
    private var wasCountedPlay = false
    private var wasCompleted = false

    private static let minPersistableSeconds: Double = 5.0
    private static let checkpointIntervalSeconds: Double = 10.0
    private static let maxContinuousMediaDelta: Double = 3.0
    private static let maxWallClockDelta: Double = 4.0
    private static let sessionResumeGapSeconds: Double = 1_800.0

    var liveEventForDisplay: ListeningSessionEvent? {
        guard let event = activeEvent, event.listenedSeconds >= 1 else { return nil }
        return event
    }

    /// Consumes a periodic media-clock update and returns any events that should be persisted now.
    mutating func observe(
        track: Track?,
        position: Double,
        duration: Double,
        isPlaying: Bool,
        isWinding: Bool,
        at now: Date = Date()
    ) -> [ListeningSessionEvent] {
        var toPersist: [ListeningSessionEvent] = []

        guard let track, !track.id.isEmpty else {
            if let flushed = flushActiveIfNeeded() { toPersist.append(flushed) }
            resetActive()
            return toPersist
        }

        // Switching to a different track seals the previous session cleanly.
        if let current = activeEvent, current.trackID != track.id {
            if let flushed = flushActiveIfNeeded() { toPersist.append(flushed) }
            resetActive()
        }

        // Start a fresh session if the same track resumes after a long idle gap (>30 min).
        if isPlaying, !isWinding, let current = activeEvent,
           now.timeIntervalSince(current.lastUpdatedAt) > Self.sessionResumeGapSeconds {
            if let flushed = flushActiveIfNeeded() { toPersist.append(flushed) }
            resetActive()
        }

        guard isPlaying, !isWinding else {
            lastPosition = nil
            lastClockAt = nil
            if let flushed = flushActiveIfNeeded() { toPersist.append(flushed) }
            return toPersist
        }

        let resolvedDuration = duration.isFinite && duration > 0 ? duration : max(0, track.duration)
        if activeEvent == nil {
            activeEvent = ListeningSessionEvent(
                id: UUID(),
                trackID: track.id,
                title: track.title,
                artist: track.artist,
                album: track.album,
                albumKey: track.albumKey,
                trackDuration: resolvedDuration,
                startedAt: now,
                lastUpdatedAt: now,
                listenedSeconds: 0,
                reachedEnd: false,
                source: track.remote == nil ? .local : .navidrome
            )
            lastPersistedSeconds = 0
            wasCountedPlay = false
            wasCompleted = false
            lastPosition = position
            lastClockAt = now
            return toPersist
        }

        if let prevPos = lastPosition, let prevClock = lastClockAt, position.isFinite {
            let mediaDelta = position - prevPos
            let wallDelta = now.timeIntervalSince(prevClock)
            // Only accumulate forward continuous playback; seeks and stalls are ignored.
            if mediaDelta > 0, mediaDelta <= Self.maxContinuousMediaDelta,
               wallDelta > 0, wallDelta <= Self.maxWallClockDelta {
                let credit = min(mediaDelta, wallDelta + 0.35)
                activeEvent?.listenedSeconds += credit
                activeEvent?.lastUpdatedAt = now
            }
        }
        lastPosition = position
        lastClockAt = now

        if let event = activeEvent, shouldCheckpoint(event) {
            markPersisted(event)
            toPersist.append(event)
        }
        return toPersist
    }

    /// Seals the current track session when playback naturally reaches the end of the track
    /// so a subsequent repeat/loop starts a distinct listening session.
    mutating func markTrackFinished(at now: Date = Date()) -> ListeningSessionEvent? {
        guard var event = activeEvent else { return nil }
        event.reachedEnd = true
        event.lastUpdatedAt = now
        let result = event.listenedSeconds >= 1 ? event : nil
        resetActive()
        return result
    }

    /// Flushes any newly accumulated seconds when pausing or backgrounding while preserving
    /// the session UUID so resuming the same track continues without double-counting.
    mutating func flushPreservingSession() -> ListeningSessionEvent? {
        lastPosition = nil
        lastClockAt = nil
        return flushActiveIfNeeded()
    }

    /// Drops the continuous clock anchor when the user manually seeks so the jump is never credited.
    mutating func noteSeek() {
        lastPosition = nil
        lastClockAt = nil
    }

    private func shouldCheckpoint(_ event: ListeningSessionEvent) -> Bool {
        guard event.listenedSeconds >= Self.minPersistableSeconds else { return false }
        if event.isCountedPlay && !wasCountedPlay { return true }
        if event.isCompleted && !wasCompleted { return true }
        return (event.listenedSeconds - lastPersistedSeconds) >= Self.checkpointIntervalSeconds
    }

    private mutating func flushActiveIfNeeded() -> ListeningSessionEvent? {
        guard let event = activeEvent,
              event.listenedSeconds >= Self.minPersistableSeconds,
              (event.listenedSeconds - lastPersistedSeconds) >= 1.0 else {
            return nil
        }
        markPersisted(event)
        return event
    }

    private mutating func markPersisted(_ event: ListeningSessionEvent) {
        lastPersistedSeconds = event.listenedSeconds
        wasCountedPlay = wasCountedPlay || event.isCountedPlay
        wasCompleted = wasCompleted || event.isCompleted
    }

    private mutating func resetActive() {
        activeEvent = nil
        lastPosition = nil
        lastClockAt = nil
        lastPersistedSeconds = 0
        wasCountedPlay = false
        wasCompleted = false
    }
}
