import Foundation

struct Track: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var title: String
    var artist: String
    var album: String
    /// Basenames only. Imported files are resolved inside this app's Library directory.
    var audioFile: String
    var artworkFile: String?
    var palette: CoverPalette
    var duration: TimeInterval
    var lyrics: String
    var isDemo: Bool
    var isLyricDemo: Bool
    /// Optional so libraries from earlier versions remain decodable.
    var contentHash: String? = nil
    /// Local import time or the server's reported creation time. Older indexes
    /// retain nil rather than inventing a date during restoration.
    var addedAt: Date? = nil
    var automaticMedia: AutomaticMediaSnapshot? = nil
    var albumArtworkFile: String? = nil
    var albumArtist: String? = nil
    var trackNumber: Int? = nil
    var discNumber: Int? = nil
    /// Remote identity is durable; authenticated stream URLs are generated only
    /// when loading audio and are never written into the local library index.
    var remote: RemoteTrackReference? = nil

    var albumKey: String { album + "\u{001F}" + (albumArtist?.isEmpty == false ? albumArtist! : artist) }

    static let demos: [Track] = [
        Track(id: "sea", title: "海边慢信", artist: "Stillroom Sessions", album: "潮汐来信",
              audioFile: "sea.wav", palette: .sea, duration: 56,
              lyrics: "[00:00]把时间留在海边\n[00:07]让风慢慢翻开这一页\n[00:14]远处的潮声，近处的光\n[00:21]都不必急着抵达\n[00:28]一张唱片，一封慢信\n[00:35]把今天轻轻收藏\n[00:42]等最后一阵浪退去\n[00:49]我们再听一遍",
              isDemo: true, isLyricDemo: true),
        Track(id: "window", title: "窗边余响", artist: "Stillroom Sessions", album: "午后的房间",
              audioFile: "window.wav", palette: .window, duration: 48, lyrics: "", isDemo: true, isLyricDemo: false),
        Track(id: "night", title: "夜色之中", artist: "Stillroom Sessions", album: "月亮留声",
              audioFile: "night.wav", palette: .night, duration: 40, lyrics: "", isDemo: true, isLyricDemo: false)
    ]
}

enum CoverPalette: String, Codable, Sendable {
    case sea, window, night, local
}

enum MediaTime {
    static func label(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let value = Int(max(0, min(seconds, 359_999)))
        return "\(value / 60):\(String(format: "%02d", value % 60))"
    }

    static func clamped(_ seconds: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard seconds.isFinite, duration.isFinite else { return 0 }
        return min(max(0, seconds), max(0, duration))
    }
}

