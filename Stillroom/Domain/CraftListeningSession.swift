import Foundation

enum CraftListeningPhase: String, Codable, Sendable {
    case listening, awaitingFlip, finished
}

enum CraftedAdvance: Equatable {
    case track(String, CraftedSide)
    case flip, finished
}

/// This is a frozen edition and its side boundary, not a second audio state. Paused/playing and
/// media seconds always come from AudioPlayback. Editing a sleeve cannot rewrite a live edition.
struct CraftListeningSession: Codable, Equatable, Sendable {
    var record: CraftedRecord
    var side: CraftedSide = .a
    var phase: CraftListeningPhase = .listening
    var reachedEndIDs: Set<String> = []

    var sideIDs: [String] { record.trackIDs(on: side) }
    var allReachedEnd: Bool { !record.allTrackIDs.isEmpty && Set(record.allTrackIDs).isSubset(of: reachedEndIDs) }

    /// A side's needle position is derived from known media seconds, never from animation angle.
    /// Unknown source durations keep a non-quantitative parked/playing presentation.
    func fraction(currentID: String, position: Double, duration: Double, tracks: [Track]) -> Double? {
        guard let index = sideIDs.firstIndex(of: currentID) else { return nil }
        let durations = sideIDs.map { id in
            id == currentID && duration.isFinite && duration > 0 ? duration : tracks.first(where: { $0.id == id })?.duration ?? 0
        }
        guard durations.allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
        let total = durations.reduce(0, +)
        guard total.isFinite && total > 0 else { return nil }
        return (durations.prefix(index).reduce(0, +) + MediaTime.clamped(position, duration: durations[index])) / total
    }

    func isRestorable(available: Set<String>, currentID: String) -> Bool {
        let ids = record.allTrackIDs
        return (try? record.validate()) != nil && !record.isDraft && !record.sideA.isEmpty && Set(ids).count == ids.count &&
            Set(ids).isSubset(of: available) && sideIDs.contains(currentID) &&
            reachedEndIDs.isSubset(of: Set(ids)) &&
            (phase != .awaitingFlip || side == .a && !record.sideB.isEmpty && currentID == record.sideA.last)
    }

    /// Only a real decoder completion marks a track end. Manual skip can reach the queue boundary
    /// but does not manufacture a completed-listen date or a listening statistic.
    mutating func advance(from currentID: String, delta: Int, automatic: Bool) -> CraftedAdvance {
        guard phase == .listening else { return phase == .awaitingFlip ? .flip : .finished }
        guard let index = sideIDs.firstIndex(of: currentID) else { return .finished }
        if automatic { reachedEndIDs.insert(currentID) }
        let next = index + (delta < 0 ? -1 : 1)
        if sideIDs.indices.contains(next) {
            phase = .listening
            return .track(sideIDs[next], side)
        }
        if delta < 0 {
            phase = .listening
            if side == .b, let previous = record.sideA.last { side = .a; return .track(previous, .a) }
            return .track(sideIDs[0], side)
        }
        if side == .a && !record.sideB.isEmpty {
            if record.manualFlip { phase = .awaitingFlip; return .flip }
            side = .b; phase = .listening
            return .track(record.sideB[0], .b)
        }
        phase = .finished
        return .finished
    }

    mutating func flip() -> String? {
        guard phase == .awaitingFlip, side == .a, !record.sideB.isEmpty else { return nil }
        side = .b; phase = .listening
        return record.sideB.first
    }
}
