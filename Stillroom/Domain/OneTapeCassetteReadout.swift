import Foundation

/// The complete loaded queue, shared by local and server tracks. A missing
/// duration stays unknown; adding only the known subset would understate it.
struct OneTapeCassetteReadout: Equatable, Sendable {
    struct TrackEntry: Equatable, Sendable {
        let number: Int
        let title: String
        let artist: String
        let durationSeconds: TimeInterval
        let isCurrent: Bool
    }

    let trackCount: Int
    let durationSeconds: TimeInterval?
    let entries: [TrackEntry]
    let albumTitle: String
    let artistName: String

    static let empty = Self(queueIDs: [], tracks: [])

    init(queueIDs: [String], tracks: [Track], currentTrackID: String? = nil) {
        trackCount = queueIDs.count
        let lookup = Dictionary(tracks.map { ($0.id, $0) },
                                uniquingKeysWith: { _, last in last })
        var sum: Double = 0
        var complete = !queueIDs.isEmpty
        var collected: [TrackEntry] = []
        collected.reserveCapacity(queueIDs.count)
        var resolvedAlbum = ""
        var resolvedArtist = ""

        for (index, id) in queueIDs.enumerated() {
            guard let track = lookup[id] else {
                complete = false
                continue
            }
            if resolvedAlbum.isEmpty, !track.album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resolvedAlbum = track.album
            }
            if resolvedArtist.isEmpty, !track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resolvedArtist = track.artist
            }
            collected.append(TrackEntry(
                number: index + 1,
                title: track.title,
                artist: track.artist,
                durationSeconds: track.duration,
                isCurrent: currentTrackID != nil && track.id == currentTrackID
            ))
            let seconds = track.duration
            guard seconds.isFinite, seconds > 0 else {
                complete = false
                continue
            }
            sum += seconds
        }
        entries = collected
        albumTitle = resolvedAlbum
        artistName = resolvedArtist
        durationSeconds = complete && sum.isFinite && sum < Double(Int.max / 4) ? sum : nil
    }

    var durationLabel: String {
        guard let durationSeconds else { return "--:--" }
        let value = Int(min(floor(durationSeconds), Double(Int.max / 4)))
        if value >= 3600 {
            return "\(value / 3600):" + String(format: "%02d:%02d", value / 60 % 60, value % 60)
        }
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    var accessibilitySummary: String {
        guard trackCount > 0 else { return "空白磁带" }
        guard durationSeconds != nil else { return "\(trackCount) 首，歌单总时长未知" }
        return "\(trackCount) 首，歌单总时长 \(durationLabel)"
    }
}
