import CoreGraphics
import Foundation

enum OneTapeWidgetConstants {
    static let appGroupID = "group.com.liuhang.stillroom"
    static let widgetKind = "OneTapeCassetteWidget"
    static let snapshotFileName = "one-tape-widget-snapshot.json"
    static let artworkFileName = "widget-cover.jpg"
    static let deepLinkScheme = "onecassette"
    static let deepLinkURL = URL(string: "onecassette://player")!
}

enum OneTapeWidgetSize: String, CaseIterable, Sendable {
    case small
    case medium
    case large

    var title: String {
        switch self {
        case .small: "小"
        case .medium: "中"
        case .large: "大"
        }
    }

    /// Canonical design canvas dimensions used by the widget renderer before
    /// uniform aspect-fit scaling into the actual system or preview bounds.
    var designSize: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .large: CGSize(width: 364, height: 382)
        }
    }
}

/// Real Home Screen widget dimensions per iPhone screen width, mirrored in
/// Settings previews so the cards match the user's actual device proportions.
struct OneTapeWidgetMetrics: Equatable, Sendable {
    let small: CGSize
    let medium: CGSize
    let large: CGSize
    let cornerRadius: CGFloat

    func size(for family: OneTapeWidgetSize) -> CGSize {
        switch family {
        case .small: small
        case .medium: medium
        case .large: large
        }
    }

    static func forScreen(width: CGFloat, height: CGFloat) -> OneTapeWidgetMetrics {
        let shortSide = min(width, height)
        let longSide = max(width, height)
        if shortSide >= 430 {
            return OneTapeWidgetMetrics(
                small: CGSize(width: 170, height: 170),
                medium: CGSize(width: 364, height: 170),
                large: CGSize(width: 364, height: 382),
                cornerRadius: 22
            )
        }
        if shortSide >= 414 {
            return OneTapeWidgetMetrics(
                small: CGSize(width: 169, height: 169),
                medium: CGSize(width: 360, height: 169),
                large: CGSize(width: 360, height: 379),
                cornerRadius: 22
            )
        }
        if shortSide >= 390 {
            return OneTapeWidgetMetrics(
                small: CGSize(width: 158, height: 158),
                medium: CGSize(width: 338, height: 158),
                large: CGSize(width: 338, height: 354),
                cornerRadius: 22
            )
        }
        if shortSide >= 375 {
            if longSide >= 812 {
                return OneTapeWidgetMetrics(
                    small: CGSize(width: 155, height: 155),
                    medium: CGSize(width: 329, height: 155),
                    large: CGSize(width: 329, height: 345),
                    cornerRadius: 20
                )
            }
            return OneTapeWidgetMetrics(
                small: CGSize(width: 148, height: 148),
                medium: CGSize(width: 321, height: 148),
                large: CGSize(width: 321, height: 324),
                cornerRadius: 20
            )
        }
        return OneTapeWidgetMetrics(
            small: CGSize(width: 141, height: 141),
            medium: CGSize(width: 292, height: 141),
            large: CGSize(width: 292, height: 311),
            cornerRadius: 20
        )
    }
}

struct OneTapeWidgetTint: Codable, Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    private static func clamp(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0
    }
}

/// Authoritative snapshot written by the main player and read by both the
/// WidgetKit extension and Settings previews. Media durations stay in seconds.
struct OneTapeWidgetSnapshot: Codable, Equatable, Sendable {
    let title: String
    let artist: String
    let album: String
    let trackNumber: Int
    let isPlaying: Bool
    let progress: Double
    let tint: OneTapeWidgetTint?
    let updated: Date
    let artworkID: String
    let albumDuration: TimeInterval
    let playbackRemaining: TimeInterval

    static let empty = OneTapeWidgetSnapshot(
        title: "",
        artist: "",
        album: "",
        trackNumber: 1,
        isPlaying: false,
        progress: 0,
        tint: nil,
        updated: Date(timeIntervalSince1970: 0),
        artworkID: "",
        albumDuration: 0,
        playbackRemaining: 0
    )

    init(
        title: String,
        artist: String,
        album: String,
        trackNumber: Int = 1,
        isPlaying: Bool,
        progress: Double,
        tint: OneTapeWidgetTint?,
        updated: Date,
        artworkID: String,
        albumDuration: TimeInterval,
        playbackRemaining: TimeInterval
    ) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        self.album = album.trimmingCharacters(in: .whitespacesAndNewlines)
        self.trackNumber = max(1, min(99, trackNumber))
        self.isPlaying = isPlaying
        self.progress = progress.isFinite ? min(1, max(0, progress)) : 0
        self.tint = tint
        self.updated = updated
        self.artworkID = artworkID
        self.albumDuration = albumDuration.isFinite ? max(0, albumDuration) : 0
        self.playbackRemaining = playbackRemaining.isFinite ? max(0, playbackRemaining) : 0
    }

    var hasTape: Bool {
        !title.isEmpty || !album.isEmpty || !artist.isEmpty
    }

    var clampedProgress: Double {
        progress.isFinite ? min(1, max(0, progress)) : 0
    }

    var cardTitle: String {
        if !title.isEmpty { return title }
        if !album.isEmpty { return album }
        return "还没有磁带"
    }

    var labelTitle: String {
        if !album.isEmpty { return album }
        if !title.isEmpty { return title }
        return "无磁带"
    }

    var sideIndexLabel: String {
        String(format: "%02d", max(1, min(99, trackNumber)))
    }

    /// 000...999 mechanical tape counter derived from album progress.
    var counterValue: Int {
        Int(clampedProgress * 999.0)
    }

    var counterText: String {
        String(format: "%03d", counterValue)
    }

    var counterDigits: [String] {
        counterText.map(String.init)
    }

    var percent: Int {
        Int((clampedProgress * 100.0).rounded())
    }

    /// Discrete 3-position hub step across 60-degree 6-tooth hub symmetry
    /// (0°, 20°, 40°) synced to 36 revolutions across a full tape side.
    var hubStepIndex: Int {
        guard hasTape else { return 0 }
        let turns = Int((clampedProgress * 36.0).rounded(.down))
        return ((turns % 3) + 3) % 3
    }

    /// Continuous hub rotation angle in degrees (36 steps × 20° per step).
    var hubAngleDegrees: Double {
        guard hasTape else { return 0 }
        return (clampedProgress * 36.0 * 20.0).truncatingRemainder(dividingBy: 360.0)
    }

    var smallStatusLabel: String {
        isPlaying ? "正在播放" : "已装入"
    }

    var deckStatusLabel: String {
        isPlaying ? "磁带转动中" : "已装入"
    }

    var smallAccessibilitySummary: String {
        let playbackLabel = isPlaying ? "播放中" : "已暂停"
        return "\(labelTitle)，\(artist)。\(playbackLabel)。已播放百分之 \(percent)。"
    }

    func previewAccessibilityLabel(size: OneTapeWidgetSize) -> String {
        "\(size.title)小组件预览，\(cardTitle)，\(artist)"
    }

    /// Projects album progress forward for WidgetKit timeline entries while
    /// audio plays in the background, stopping cleanly at `playbackRemaining`.
    func projected(at date: Date) -> OneTapeWidgetSnapshot {
        guard isPlaying, albumDuration > 0 else { return self }
        let rawElapsed = max(0, date.timeIntervalSince(updated))
        guard rawElapsed > 0 else { return self }
        let limit = playbackRemaining > 0 ? playbackRemaining : albumDuration * (1 - clampedProgress)
        let effectiveElapsed = min(rawElapsed, max(0, limit))
        let nextProgress = min(1, max(0, clampedProgress + effectiveElapsed / albumDuration))
        let reachedEnd = limit > 0 && rawElapsed >= limit - 0.5
        return OneTapeWidgetSnapshot(
            title: title,
            artist: artist,
            album: album,
            trackNumber: trackNumber,
            isPlaying: reachedEnd ? false : isPlaying,
            progress: nextProgress,
            tint: tint,
            updated: date,
            artworkID: artworkID,
            albumDuration: albumDuration,
            playbackRemaining: max(0, limit - effectiveElapsed)
        )
    }

    /// Generates bounded WidgetKit timeline dates so the counter and hub wind
    /// forward on the Home Screen without exceeding WidgetKit entry budgets.
    func timelineDates(from start: Date, maxEntries: Int = 24) -> [Date] {
        let cappedMax = max(1, maxEntries)
        guard isPlaying, albumDuration > 0 else { return [start] }
        let remaining = playbackRemaining > 0 ? playbackRemaining : albumDuration * (1 - clampedProgress)
        guard remaining > 1 else { return [start] }

        // Advance at most every 15 seconds so timeline stays light while keeping
        // the 000–999 counter visibly alive during background playback.
        let desiredStep = max(15.0, albumDuration / 120.0)
        let minStepForBudget = remaining / Double(max(1, cappedMax - 1))
        let step = max(desiredStep, minStepForBudget)

        var dates: [Date] = [start]
        var offset = step
        while offset < remaining - 1, dates.count < cappedMax - 1 {
            dates.append(start.addingTimeInterval(offset))
            offset += step
        }
        dates.append(start.addingTimeInterval(remaining))
        return dates
    }
}
