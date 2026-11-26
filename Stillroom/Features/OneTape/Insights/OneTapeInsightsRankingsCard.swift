import SwiftUI

/// Top-5 rankings card (`专辑 / 单曲 / 艺人`) with album artwork, proportional horizontal
/// gauge meters, and direct tap-to-play integration with the shared cassette player.
struct OneTapeInsightsRankingsCard: View {
    enum Category: String, CaseIterable, Identifiable {
        case albums, tracks, artists
        var id: String { rawValue }
        var title: String {
            switch self {
            case .albums: "专辑"
            case .tracks: "单曲"
            case .artists: "艺人"
            }
        }
    }

    let snapshot: ListeningInsightsSnapshot
    let albums: [MusicCollection]
    let tracks: [Track]
    let artworks: [String: UIImage]
    let revealTrigger: Int
    let onLoadArtwork: (MusicCollection) -> Void
    let onPlayAlbum: (String) -> Void
    let onPlayTrack: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var category: Category = .albums
    @State private var barProgress: CGFloat = 0

    private let accent = Color(red: 0.87, green: 0.55, blue: 0.25)

    private var albumByKey: [String: MusicCollection] {
        var map: [String: MusicCollection] = [:]
        let tracksByID = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for album in albums {
            if let firstID = album.trackIDs.first, let track = tracksByID[firstID] {
                map[track.albumKey] = album
            }
            let fallbackKey = album.title + "\u{001F}" + album.subtitle
            if map[fallbackKey] == nil { map[fallbackKey] = album }
        }
        return map
    }

    private var availableTrackIDs: Set<String> {
        Set(tracks.map(\.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("常听排行")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer(minLength: 8)
                categoryPicker
            }

            switch category {
            case .albums:
                albumsContent
            case .tracks:
                tracksContent
            case .artists:
                artistsContent
            }
        }
        .padding(18)
        .background(.white.opacity(0.036), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.075), lineWidth: 0.6)
        }
        .accessibilityIdentifier("insights.rankingsCard")
        .onAppear { animateBars() }
        .onChange(of: category) { _, _ in animateBars() }
        .onChange(of: snapshot.range) { _, _ in animateBars() }
        .onChange(of: revealTrigger) { _, _ in animateBars() }
    }

    private var categoryPicker: some View {
        HStack(spacing: 2) {
            ForEach(Category.allCases) { item in
                let selected = category == item
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        category = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                        .foregroundStyle(.white.opacity(selected ? 0.94 : 0.48))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background {
                            if selected {
                                Capsule().fill(.white.opacity(0.14))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("insights.rank.\(item.rawValue)")
            }
        }
        .padding(3)
        .background(.white.opacity(0.05), in: Capsule())
    }

    @ViewBuilder
    private var albumsContent: some View {
        if snapshot.topAlbums.isEmpty {
            emptyState
        } else {
            let maxSec = max(snapshot.topAlbums.first?.totalSeconds ?? 1, 1)
            let lookup = albumByKey
            VStack(spacing: 12) {
                ForEach(Array(snapshot.topAlbums.enumerated()), id: \.element.id) { index, item in
                    let collection = lookup[item.albumKey]
                    let canPlay = collection != nil || availableTrackIDs.contains(item.representativeTrackID)
                    Button {
                        guard canPlay else { return }
                        onPlayAlbum(item.albumKey)
                    } label: {
                        rankingRow(
                            rank: index + 1,
                            title: item.title,
                            subtitle: item.artist,
                            stat: formatStat(plays: item.playCount, seconds: item.totalSeconds),
                            fraction: item.totalSeconds / maxSec,
                            artwork: collection.flatMap { artworks[$0.id] },
                            showsArtwork: true,
                            playable: canPlay
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canPlay)
                    .task(id: collection?.id) {
                        if let collection, artworks[collection.id] == nil {
                            onLoadArtwork(collection)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tracksContent: some View {
        if snapshot.topTracks.isEmpty {
            emptyState
        } else {
            let maxSec = max(snapshot.topTracks.first?.totalSeconds ?? 1, 1)
            let lookup = albumByKey
            VStack(spacing: 12) {
                ForEach(Array(snapshot.topTracks.enumerated()), id: \.element.id) { index, item in
                    let collection = lookup[item.albumKey]
                    let canPlay = availableTrackIDs.contains(item.trackID)
                    Button {
                        guard canPlay else { return }
                        onPlayTrack(item.trackID)
                    } label: {
                        rankingRow(
                            rank: index + 1,
                            title: item.title,
                            subtitle: "\(item.artist) · \(item.album)",
                            stat: formatStat(plays: item.playCount, seconds: item.totalSeconds),
                            fraction: item.totalSeconds / maxSec,
                            artwork: collection.flatMap { artworks[$0.id] },
                            showsArtwork: true,
                            playable: canPlay
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canPlay)
                    .task(id: collection?.id) {
                        if let collection, artworks[collection.id] == nil {
                            onLoadArtwork(collection)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var artistsContent: some View {
        if snapshot.topArtists.isEmpty {
            emptyState
        } else {
            let maxSec = max(snapshot.topArtists.first?.totalSeconds ?? 1, 1)
            VStack(spacing: 12) {
                ForEach(Array(snapshot.topArtists.enumerated()), id: \.element.id) { index, item in
                    rankingRow(
                        rank: index + 1,
                        title: item.artist,
                        subtitle: "\(item.uniqueTracks) 首不同曲目",
                        stat: formatStat(plays: item.playCount, seconds: item.totalSeconds),
                        fraction: item.totalSeconds / maxSec,
                        artwork: nil,
                        showsArtwork: false,
                        playable: false
                    )
                }
            }
        }
    }

    private func rankingRow(
        rank: Int,
        title: String,
        subtitle: String,
        stat: String,
        fraction: Double,
        artwork: UIImage?,
        showsArtwork: Bool,
        playable: Bool
    ) -> some View {
        let isTop = rank == 1
        return HStack(spacing: 11) {
            Text(String(format: "%02d", rank))
                .font(.custom("GeistMono-Regular", size: 12))
                .foregroundStyle(isTop ? accent : .white.opacity(0.38))
                .frame(width: 20, alignment: .leading)

            if showsArtwork {
                artworkThumb(artwork)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(stat)
                        .font(.custom("GeistMono-Regular", size: 11))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if playable {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8.5))
                            .foregroundStyle(.white.opacity(0.28))
                    }
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.06))
                        Capsule()
                            .fill(isTop ? accent : .white.opacity(0.48))
                            .frame(width: max(4, proxy.size.width * CGFloat(max(0, min(1, fraction))) * barProgress))
                    }
                }
                .frame(height: 3)
            }
        }
        .contentShape(Rectangle())
    }

    private func artworkThumb(_ image: UIImage?) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(white: 0.11)
                    Image(systemName: "recordingtape")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.white.opacity(0.30))
                }
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.6)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "recordingtape")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white.opacity(0.28))
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("暂无聆听榜单")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
                Text("完整收听几首音乐后，常听专辑与曲目会按真实时长排列。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.42))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }

    private func animateBars() {
        if reduceMotion {
            barProgress = 1
            return
        }
        barProgress = 0.04
        withAnimation(.spring(duration: 0.44, bounce: 0.06)) {
            barProgress = 1
        }
    }

    private func formatStat(plays: Int, seconds: Double) -> String {
        let durationText: String
        if seconds >= 3600 {
            durationText = String(format: "%.1fh", seconds / 3600.0)
        } else if seconds >= 60 {
            durationText = "\(Int((seconds / 60.0).rounded()))m"
        } else {
            durationText = "\(Int(seconds.rounded()))s"
        }
        return plays > 0 ? "\(plays) 次 · \(durationText)" : durationText
    }
}

/// Library archive overview card showing total catalog capacity in C60 equivalents,
/// local vs Navidrome balance, favorites, and a vintage decade distribution ruler.
struct OneTapeInsightsLibraryCard: View {
    let library: LibraryArchiveInsight
    let revealTrigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scaleProgress: CGFloat = 0

    private let accent = Color(red: 0.87, green: 0.55, blue: 0.25)

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Text("曲库档案")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text(String(format: "折合 %.1f 盘 C60", library.c60Count))
                    .font(.custom("GeistMono-Regular", size: 11))
                    .foregroundStyle(.white.opacity(0.48))
            }

            HStack(spacing: 12) {
                archiveCell(value: "\(library.albumCount)", label: "专辑")
                archiveCell(value: "\(library.trackCount)", label: "曲目")
                archiveCell(value: "\(library.favoriteCount)", label: "收藏")
            }

            if library.trackCount > 0 {
                sourceSplitBar
            }

            if !library.decades.isEmpty {
                decadeRuler
            }
        }
        .padding(18)
        .background(.white.opacity(0.036), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.075), lineWidth: 0.6)
        }
        .accessibilityIdentifier("insights.libraryCard")
        .onAppear { animateScale() }
        .onChange(of: revealTrigger) { _, _ in animateScale() }
    }

    private func archiveCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.custom("GeistMono-Regular", size: 19))
                .foregroundStyle(.white.opacity(0.92))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.44))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var sourceSplitBar: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { proxy in
                let totalWidth = max(1, proxy.size.width)
                let localW = totalWidth * CGFloat(library.localFraction) * scaleProgress
                let remoteW = totalWidth * CGFloat(1 - library.localFraction) * scaleProgress

                HStack(spacing: library.localTrackCount > 0 && library.navidromeTrackCount > 0 ? 3 : 0) {
                    if library.localTrackCount > 0 {
                        Capsule()
                            .fill(.white.opacity(0.70))
                            .frame(width: max(4, localW))
                    }
                    if library.navidromeTrackCount > 0 {
                        Capsule()
                            .fill(accent)
                            .frame(width: max(4, remoteW))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 5)
            .background(.white.opacity(0.06), in: Capsule())

            HStack(spacing: 14) {
                legendDot(color: .white.opacity(0.70), label: "本地 \(library.localTrackCount)")
                legendDot(color: accent, label: "Navidrome \(library.navidromeTrackCount)")
                Spacer()
                Text(totalDurationLabel)
                    .font(.custom("GeistMono-Regular", size: 10.5))
                    .foregroundStyle(.white.opacity(0.40))
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.56))
        }
    }

    private var decadeRuler: some View {
        let maxCount = max(library.decades.map(\.albumCount).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text("发行年代分布")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(library.decades) { bucket in
                    let ratio = Double(bucket.albumCount) / Double(maxCount)
                    let isPeak = bucket.albumCount == maxCount
                    VStack(spacing: 5) {
                        Text("\(bucket.albumCount)")
                            .font(.custom("GeistMono-Regular", size: 10))
                            .foregroundStyle(.white.opacity(isPeak ? 0.80 : 0.42))
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .fill(.white.opacity(0.05))
                                .frame(height: 44)
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .fill(isPeak ? accent.opacity(0.88) : .white.opacity(0.42))
                                .frame(height: max(5, 44 * CGFloat(ratio) * scaleProgress))
                        }
                        Text(bucket.label)
                            .font(.custom("GeistMono-Regular", size: 10.5))
                            .foregroundStyle(.white.opacity(isPeak ? 0.88 : 0.48))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 2)
    }

    private var totalDurationLabel: String {
        let hours = Int(library.totalSeconds) / 3600
        let mins = (Int(library.totalSeconds) % 3600) / 60
        if hours > 0 { return "总时长 \(hours)h \(mins)m" }
        return "总时长 \(mins)m"
    }

    private func animateScale() {
        if reduceMotion {
            scaleProgress = 1
            return
        }
        scaleProgress = 0.05
        withAnimation(.spring(duration: 0.44, bounce: 0.06)) {
            scaleProgress = 1
        }
    }
}
