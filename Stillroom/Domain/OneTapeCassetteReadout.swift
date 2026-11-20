import Foundation

/// The complete loaded queue, shared by local and server tracks. A missing
/// duration stays unknown; adding only the known subset would understate it.
struct OneTapeCassetteReadout: Equatable, Sendable {
    let trackCount: Int
    let durationSeconds: TimeInterval?

    static let empty = Self(queueIDs: [], tracks: [])

    init(queueIDs: [String], tracks: [Track]) {
        trackCount = queueIDs.count
        let lookup = Dictionary(tracks.map { ($0.id, $0.duration) },
                                uniquingKeysWith: { _, last in last })
        var sum: Double = 0
        var complete = !queueIDs.isEmpty
        for id in queueIDs {
            guard let seconds = lookup[id], seconds.isFinite, seconds > 0 else {
                complete = false
                continue
            }
            sum += seconds
        }
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
