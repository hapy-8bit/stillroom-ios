import Foundation

enum ListeningLedgerError: Error, Equatable {
    case corruptedArchive
}

enum ListeningTimeRange: String, CaseIterable, Identifiable, Sendable {
    case week, month, all
    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "7天"
        case .month: "30天"
        case .all: "全部"
        }
    }

    var lcdCode: String {
        switch self {
        case .week: "7D"
        case .month: "30D"
        case .all: "ALL"
        }
    }

    func startDate(relativeTo now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .week: return calendar.date(byAdding: .day, value: -6, to: today)
        case .month: return calendar.date(byAdding: .day, value: -29, to: today)
        case .all: return nil
        }
    }
}

enum ListeningSourceKind: String, Codable, Equatable, Sendable {
    case local, navidrome
}

/// One real listening session recorded by the single authoritative audio engine.
/// Holding a stable `id` lets an in-flight track upsert safely on periodic checkpoints,
/// pauses, and background transitions without ever double-counting plays or duration.
struct ListeningSessionEvent: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let trackID: String
    let title: String
    let artist: String
    let album: String
    let albumKey: String
    let trackDuration: Double
    let startedAt: Date
    var lastUpdatedAt: Date
    var listenedSeconds: Double
    var reachedEnd: Bool
    let source: ListeningSourceKind

    /// Standard cassette play threshold: 20s for normal tracks, or 40% (min 5s) for short pieces.
    static func playThreshold(for duration: Double) -> Double {
        guard duration.isFinite, duration > 0 else { return 20 }
        return min(20, max(5, duration * 0.40))
    }

    var isCountedPlay: Bool {
        listenedSeconds >= Self.playThreshold(for: trackDuration)
    }

    var isCompleted: Bool {
        reachedEnd || (trackDuration > 0 && listenedSeconds >= trackDuration * 0.80)
    }

    var isValid: Bool {
        !trackID.isEmpty
            && trackID.utf8.count <= 4_096
            && !trackID.contains("\0")
            && trackDuration.isFinite && trackDuration >= 0
            && listenedSeconds.isFinite && listenedSeconds >= 0 && listenedSeconds <= 86_400
    }
}

/// Durable local listening ledger. Strictly records real playback inside this app
/// across both local files and Navidrome streams without mixing server play counts.
struct ListeningLedger: Codable, Equatable, Sendable {
    /// Standard Compact Cassette linear tape speed: 1 7/8 ips = 4.7625 cm/s.
    static let tapeSpeedMetersPerSecond: Double = 0.047625
    /// One C60 cassette holds 60 minutes (3600 seconds, ~171.45 meters of tape).
    static let c60DurationSeconds: Double = 3_600.0
    static let maxEvents = 20_000

    private(set) var events: [ListeningSessionEvent] = []

    static func restored(_ events: [ListeningSessionEvent]) throws -> ListeningLedger {
        guard events.count <= maxEvents,
              events.allSatisfy(\.isValid),
              Set(events.map(\.id)).count == events.count else {
            throw ListeningLedgerError.corruptedArchive
        }
        return ListeningLedger(events: events)
    }

    @discardableResult
    mutating func upsert(_ event: ListeningSessionEvent) -> Bool {
        guard event.isValid, event.listenedSeconds >= 1 else { return false }
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
            if events.count > Self.maxEvents {
                events.removeFirst(events.count - Self.maxEvents)
            }
        }
        return true
    }

    /// Merges an in-flight live playback session with persisted history for real-time display.
    func mergedEvents(including liveEvent: ListeningSessionEvent?) -> [ListeningSessionEvent] {
        guard let liveEvent, liveEvent.isValid, liveEvent.listenedSeconds >= 1 else { return events }
        var combined = events
        if let index = combined.firstIndex(where: { $0.id == liveEvent.id }) {
            combined[index] = liveEvent
        } else {
            combined.append(liveEvent)
        }
        return combined
    }
}

struct DailyListeningPoint: Equatable, Identifiable, Sendable {
    let id: Date
    let dayStart: Date
    let weekdayLabel: String
    let dateLabel: String
    let minutes: Double
    let isToday: Bool
}

struct RankedAlbumInsight: Equatable, Identifiable, Sendable {
    var id: String { albumKey }
    let albumKey: String
    let title: String
    let artist: String
    let playCount: Int
    let totalSeconds: Double
    let representativeTrackID: String
}

struct RankedTrackInsight: Equatable, Identifiable, Sendable {
    var id: String { trackID }
    let trackID: String
    let title: String
    let artist: String
    let album: String
    let albumKey: String
    let playCount: Int
    let totalSeconds: Double
}

struct RankedArtistInsight: Equatable, Identifiable, Sendable {
    var id: String { artist }
    let artist: String
    let playCount: Int
    let totalSeconds: Double
    let uniqueTracks: Int
}

struct DecadeBucket: Equatable, Identifiable, Sendable {
    var id: Int { decade }
    let decade: Int
    let label: String
    let albumCount: Int
}

struct LibraryArchiveInsight: Equatable, Sendable {
    let albumCount: Int
    let trackCount: Int
    let favoriteCount: Int
    let totalSeconds: Double
    let c60Count: Double
    let localTrackCount: Int
    let navidromeTrackCount: Int
    let decades: [DecadeBucket]

    var localFraction: Double {
        guard trackCount > 0 else { return 0 }
        return Double(localTrackCount) / Double(trackCount)
    }
}

/// Complete immutable snapshot consumed by the Insights UI views.
struct ListeningInsightsSnapshot: Equatable, Sendable {
    let range: ListeningTimeRange
    let totalSeconds: Double
    let c60TapeCount: Double
    let tapeMeters: Double
    let countedPlays: Int
    let completedPlays: Int
    let completionRate: Double?
    let activeDays: Int
    let currentStreakDays: Int
    let hourlyMinutes: [Double]
    let peakHour: Int?
    let peakWindowLabel: String
    let rhythmSummary: String
    let dailySeries: [DailyListeningPoint]
    let topAlbums: [RankedAlbumInsight]
    let topTracks: [RankedTrackInsight]
    let topArtists: [RankedArtistInsight]
    let library: LibraryArchiveInsight

    var hasListeningData: Bool { totalSeconds >= 1 }

    static func build(
        ledger: ListeningLedger,
        liveEvent: ListeningSessionEvent?,
        range: ListeningTimeRange,
        tracks: [Track],
        albums: [MusicCollection],
        favorites: Set<String>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ListeningInsightsSnapshot {
        let allEvents = ledger.mergedEvents(including: liveEvent)
        let startBoundary = range.startDate(relativeTo: now, calendar: calendar)
        let scoped = allEvents.filter { event in
            guard let startBoundary else { return true }
            return event.startedAt >= startBoundary
        }

        let totalSeconds = scoped.reduce(0) { $0 + $1.listenedSeconds }
        let countedEvents = scoped.filter(\.isCountedPlay)
        let countedPlays = countedEvents.count
        let completedPlays = countedEvents.filter(\.isCompleted).count
        let completionRate: Double? = countedPlays > 0 ? Double(completedPlays) / Double(countedPlays) : nil

        let scopedDayStarts = Set(scoped.map { calendar.startOfDay(for: $0.startedAt) })
        let allDayStarts = Set(allEvents.map { calendar.startOfDay(for: $0.startedAt) })
        let streak = computeStreak(activeDays: allDayStarts, now: now, calendar: calendar)

        var hourly = [Double](repeating: 0, count: 24)
        for event in scoped {
            let hour = calendar.component(.hour, from: event.startedAt)
            if (0..<24).contains(hour) {
                hourly[hour] += event.listenedSeconds / 60.0
            }
        }
        let maxHourValue = hourly.max() ?? 0
        let peakHour: Int? = maxHourValue > 0 ? hourly.firstIndex(of: maxHourValue) : nil
        let peakWindow = formatPeakWindow(peakHour: peakHour)
        let summary = buildRhythmSummary(peakHour: peakHour, totalSeconds: totalSeconds, range: range)

        let seriesDays = range == .week ? 7 : (range == .month ? 28 : 35)
        let dailySeries = buildDailySeries(events: scoped, days: seriesDays, now: now, calendar: calendar)

        let (topAlbums, topTracks, topArtists) = buildRankings(events: scoped)
        let library = buildLibraryArchive(tracks: tracks, albums: albums, favorites: favorites)

        return ListeningInsightsSnapshot(
            range: range,
            totalSeconds: totalSeconds,
            c60TapeCount: totalSeconds / ListeningLedger.c60DurationSeconds,
            tapeMeters: totalSeconds * ListeningLedger.tapeSpeedMetersPerSecond,
            countedPlays: countedPlays,
            completedPlays: completedPlays,
            completionRate: completionRate,
            activeDays: scopedDayStarts.count,
            currentStreakDays: streak,
            hourlyMinutes: hourly,
            peakHour: peakHour,
            peakWindowLabel: peakWindow,
            rhythmSummary: summary,
            dailySeries: dailySeries,
            topAlbums: topAlbums,
            topTracks: topTracks,
            topArtists: topArtists,
            library: library
        )
    }

    private static func computeStreak(activeDays: Set<Date>, now: Date, calendar: Calendar) -> Int {
        guard !activeDays.isEmpty else { return 0 }
        let today = calendar.startOfDay(for: now)
        let anchor: Date
        if activeDays.contains(today) {
            anchor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  activeDays.contains(yesterday) {
            anchor = yesterday
        } else {
            return 0
        }
        var count = 0
        var cursor = anchor
        while activeDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private static func formatPeakWindow(peakHour: Int?) -> String {
        guard let hour = peakHour else { return "--:--" }
        let endHour = (hour + 2) % 24
        return String(format: "%02d:00–%02d:00", hour, endHour)
    }

    private static func buildRhythmSummary(
        peakHour: Int?,
        totalSeconds: Double,
        range: ListeningTimeRange
    ) -> String {
        guard totalSeconds >= 1, let hour = peakHour else {
            return "装入一盘磁带，你的真实聆听轨迹会从这里开始记录。"
        }
        let period: String
        switch hour {
        case 5..<9: period = "清晨"
        case 9..<12: period = "上午"
        case 12..<14: period = "午间"
        case 14..<18: period = "午后"
        case 18..<22: period = "傍晚"
        default: period = "深夜"
        }
        let window = formatPeakWindow(peakHour: hour)
        let prefix = range == .all ? "一直以来" : "最近 \(range.title) 里"
        return "\(prefix)，\(period) \(window) 是你最常打开磁带机的时段。"
    }

    private static func buildDailySeries(
        events: [ListeningSessionEvent],
        days: Int,
        now: Date,
        calendar: Calendar
    ) -> [DailyListeningPoint] {
        let today = calendar.startOfDay(for: now)
        var minutesByDay: [Date: Double] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.startedAt)
            minutesByDay[day, default: 0] += event.listenedSeconds / 60.0
        }
        let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return (0..<days).compactMap { offset -> DailyListeningPoint? in
            let delta = -(days - 1 - offset)
            guard let day = calendar.date(byAdding: .day, value: delta, to: today) else { return nil }
            let isToday = day == today
            let weekdayIndex = max(0, min(6, calendar.component(.weekday, from: day) - 1))
            let month = calendar.component(.month, from: day)
            let dayNum = calendar.component(.day, from: day)
            return DailyListeningPoint(
                id: day,
                dayStart: day,
                weekdayLabel: isToday ? "今天" : weekdayNames[weekdayIndex],
                dateLabel: "\(month)/\(dayNum)",
                minutes: minutesByDay[day] ?? 0,
                isToday: isToday
            )
        }
    }

    private static func buildRankings(
        events: [ListeningSessionEvent]
    ) -> ([RankedAlbumInsight], [RankedTrackInsight], [RankedArtistInsight]) {
        struct AlbumAccum {
            var title: String
            var artist: String
            var plays: Int
            var seconds: Double
            var trackID: String
        }
        struct TrackAccum {
            var title: String
            var artist: String
            var album: String
            var albumKey: String
            var plays: Int
            var seconds: Double
        }
        struct ArtistAccum {
            var plays: Int
            var seconds: Double
            var trackIDs: Set<String>
        }

        var albumMap: [String: AlbumAccum] = [:]
        var trackMap: [String: TrackAccum] = [:]
        var artistMap: [String: ArtistAccum] = [:]

        for event in events {
            let playDelta = event.isCountedPlay ? 1 : 0
            let albumKey = event.albumKey.isEmpty ? event.album + "\u{001F}" + event.artist : event.albumKey
            let albumTitle = event.album.isEmpty ? "未命名专辑" : event.album
            let artistName = event.artist.isEmpty ? "未知艺人" : event.artist
            let trackTitle = event.title.isEmpty ? "未命名歌曲" : event.title

            if var entry = albumMap[albumKey] {
                entry.plays += playDelta
                entry.seconds += event.listenedSeconds
                albumMap[albumKey] = entry
            } else {
                albumMap[albumKey] = AlbumAccum(
                    title: albumTitle, artist: artistName, plays: playDelta,
                    seconds: event.listenedSeconds, trackID: event.trackID
                )
            }

            if var entry = trackMap[event.trackID] {
                entry.plays += playDelta
                entry.seconds += event.listenedSeconds
                trackMap[event.trackID] = entry
            } else {
                trackMap[event.trackID] = TrackAccum(
                    title: trackTitle, artist: artistName, album: albumTitle,
                    albumKey: albumKey, plays: playDelta, seconds: event.listenedSeconds
                )
            }

            if var entry = artistMap[artistName] {
                entry.plays += playDelta
                entry.seconds += event.listenedSeconds
                entry.trackIDs.insert(event.trackID)
                artistMap[artistName] = entry
            } else {
                artistMap[artistName] = ArtistAccum(
                    plays: playDelta, seconds: event.listenedSeconds, trackIDs: [event.trackID]
                )
            }
        }

        let topAlbums = albumMap
            .map { RankedAlbumInsight(albumKey: $0.key, title: $0.value.title, artist: $0.value.artist,
                                      playCount: $0.value.plays, totalSeconds: $0.value.seconds,
                                      representativeTrackID: $0.value.trackID) }
            .sorted { $0.totalSeconds != $1.totalSeconds ? $0.totalSeconds > $1.totalSeconds : $0.playCount > $1.playCount }
            .prefix(5)

        let topTracks = trackMap
            .map { RankedTrackInsight(trackID: $0.key, title: $0.value.title, artist: $0.value.artist,
                                      album: $0.value.album, albumKey: $0.value.albumKey,
                                      playCount: $0.value.plays, totalSeconds: $0.value.seconds) }
            .sorted { $0.totalSeconds != $1.totalSeconds ? $0.totalSeconds > $1.totalSeconds : $0.playCount > $1.playCount }
            .prefix(5)

        let topArtists = artistMap
            .map { RankedArtistInsight(artist: $0.key, playCount: $0.value.plays,
                                       totalSeconds: $0.value.seconds, uniqueTracks: $0.value.trackIDs.count) }
            .sorted { $0.totalSeconds != $1.totalSeconds ? $0.totalSeconds > $1.totalSeconds : $0.playCount > $1.playCount }
            .prefix(5)

        return (Array(topAlbums), Array(topTracks), Array(topArtists))
    }

    private static func buildLibraryArchive(
        tracks: [Track],
        albums: [MusicCollection],
        favorites: Set<String>
    ) -> LibraryArchiveInsight {
        let totalSeconds = tracks.reduce(0) { $0 + max(0, $1.duration) }
        let localCount = tracks.filter { $0.remote == nil }.count
        let remoteCount = tracks.count - localCount
        let availableIDs = Set(tracks.map(\.id))
        let activeFavorites = favorites.intersection(availableIDs).count

        var decadeCounts: [Int: Int] = [:]
        for album in albums {
            guard let year = album.year, (1920...2099).contains(year) else { continue }
            let decade = (year / 10) * 10
            decadeCounts[decade, default: 0] += 1
        }
        let decades = decadeCounts.keys.sorted().map { decade in
            DecadeBucket(decade: decade, label: "\(String(format: "%02d", decade % 100))s",
                         albumCount: decadeCounts[decade] ?? 0)
        }

        return LibraryArchiveInsight(
            albumCount: albums.count,
            trackCount: tracks.count,
            favoriteCount: activeFavorites,
            totalSeconds: totalSeconds,
            c60Count: totalSeconds / ListeningLedger.c60DurationSeconds,
            localTrackCount: localCount,
            navidromeTrackCount: remoteCount,
            decades: decades
        )
    }
}
