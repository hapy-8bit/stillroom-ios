import SwiftUI

/// Prints the loaded tape's track list directly onto the cassette shell in two
/// horizontal label bands that avoid the reels, center window and bottom latch.
/// Coordinates are authored in landscape 576×376.33 space, then rotated +90°
/// onto the 376.33×576 portrait canvas and clipped by `OneTapeShellPrintMask`.
struct OneTapeTrackListPrint: View {
    let appearance: OneTapeAppearance
    let readout: OneTapeCassetteReadout

    private var ink: Color {
        appearance.tapeStyle.usesLightInk
            ? Color(red: 0.93, green: 0.91, blue: 0.87)
            : Color(red: 0.12, green: 0.12, blue: 0.13)
    }

    private var invertedInk: Color {
        appearance.tapeStyle.usesLightInk
            ? Color(red: 0.10, green: 0.10, blue: 0.11)
            : Color(red: 0.94, green: 0.92, blue: 0.88)
    }

    private var softInk: Color { ink.opacity(0.46) }
    private var ruleInk: Color { ink.opacity(0.24) }

    var body: some View {
        landscapeSheet
            .frame(width: 576, height: 376.33)
            .rotationEffect(.degrees(90))
            .frame(width: 376.33, height: 576)
            .compositingGroup()
            .mask {
                OneTapeShellPrintMask(tapeStyle: appearance.tapeStyle)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var landscapeSheet: some View {
        ZStack(alignment: .topLeading) {
            // Top label band above spindle hubs (y: 28...118 in landscape shell).
            VStack(alignment: .leading, spacing: 5) {
                headerRow
                Rectangle().fill(ruleInk).frame(height: 0.75)
                if readout.entries.isEmpty {
                    emptyTrackRows
                } else {
                    trackLines(upperTracks, maxLines: 4)
                }
            }
            .frame(width: 484, height: 88, alignment: .topLeading)
            .position(x: 288, y: 74)

            // Side micro-spec stamps flanking the left and right reels.
            VStack(alignment: .leading, spacing: 4) {
                Text("A")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundStyle(ink.opacity(0.88))
                Text("STEREO")
                    .font(.custom("GeistMono-Regular", fixedSize: 6.5))
                    .tracking(1.1)
                    .foregroundStyle(softInk)
                Text("120µs")
                    .font(.custom("GeistMono-Regular", fixedSize: 6.5))
                    .tracking(0.8)
                    .foregroundStyle(softInk)
            }
            .frame(width: 68, alignment: .leading)
            .position(x: 78, y: 172)

            VStack(alignment: .trailing, spacing: 4) {
                Text(currentIndexStamp)
                    .font(.custom("DMMono-Regular", fixedSize: 10))
                    .foregroundStyle(ink.opacity(0.84))
                Text(readout.durationLabel)
                    .font(.custom("GeistMono-Regular", fixedSize: 7))
                    .tracking(0.8)
                    .foregroundStyle(softInk)
                Text("TRACK LIST")
                    .font(.custom("GeistMono-Regular", fixedSize: 6))
                    .tracking(1.0)
                    .foregroundStyle(softInk)
            }
            .frame(width: 68, alignment: .trailing)
            .position(x: 498, y: 172)

            // Lower label band below reels and above the bottom trapezoidal latch.
            VStack(alignment: .leading, spacing: 4) {
                if !lowerTracks.isEmpty {
                    trackLines(lowerTracks, maxLines: 2)
                } else {
                    editorialFooterLines
                }
                Rectangle().fill(ruleInk).frame(height: 0.65)
                footerStrip
            }
            .frame(width: 484, height: 48, alignment: .bottomLeading)
            .position(x: 288, y: 254)
        }
        .foregroundStyle(ink)
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("SIDE A")
                .font(.custom("GeistMono-Regular", fixedSize: 8.5))
                .tracking(1.2)
                .foregroundStyle(ink.opacity(0.92))
            Text("·")
                .font(.custom("GeistMono-Regular", fixedSize: 8.5))
                .foregroundStyle(softInk)
            Text(headerTitle)
                .font(.custom("DMSans-Medium", fixedSize: 9.5))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(ink.opacity(0.92))
            Spacer(minLength: 6)
            Text(headerMeta)
                .font(.custom("GeistMono-Regular", fixedSize: 7.5))
                .tracking(0.8)
                .foregroundStyle(softInk)
                .lineLimit(1)
        }
    }

    private var headerTitle: String {
        if !readout.albumTitle.isEmpty {
            return readout.albumTitle.uppercased()
        }
        if !readout.artistName.isEmpty {
            return readout.artistName.uppercased()
        }
        return "ONE CASSETTE"
    }

    private var headerMeta: String {
        guard readout.trackCount > 0 else { return "BLANK TAPE · C60" }
        return "\(String(format: "%02d", readout.trackCount)) TRACKS · \(readout.durationLabel)"
    }

    private var currentIndexStamp: String {
        guard readout.trackCount > 0 else { return "00/00" }
        if let active = readout.entries.first(where: \.isCurrent) {
            return String(format: "%02d/%02d", active.number, readout.trackCount)
        }
        return String(format: "01/%02d", readout.trackCount)
    }

    private var upperTracks: [OneTapeCassetteReadout.TrackEntry] {
        Array(readout.entries.prefix(12))
    }

    private var lowerTracks: [OneTapeCassetteReadout.TrackEntry] {
        guard readout.entries.count > 12 else { return [] }
        return Array(readout.entries.dropFirst(12).prefix(8))
    }

    private func trackLines(_ items: [OneTapeCassetteReadout.TrackEntry], maxLines: Int) -> some View {
        let rows = packRows(items: items, maxLines: maxLines, maxCharsPerRow: 54)
        return VStack(alignment: .leading, spacing: 3.5) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.number) { entry in
                        trackToken(entry)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func trackToken(_ entry: OneTapeCassetteReadout.TrackEntry) -> some View {
        let num = String(format: "%02d", entry.number)
        let title = truncatedTitle(entry.title, limit: 22)
        return HStack(spacing: 4) {
            Text(num)
                .font(.custom("DMMono-Regular", fixedSize: 8.0))
                .foregroundStyle(entry.isCurrent ? invertedInk.opacity(0.85) : softInk)
            Text(title)
                .font(.custom("DMSans-Medium", fixedSize: 9.0))
                .foregroundStyle(entry.isCurrent ? invertedInk : ink.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.horizontal, entry.isCurrent ? 4.5 : 0)
        .padding(.vertical, entry.isCurrent ? 1.0 : 0)
        .background {
            if entry.isCurrent {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(ink)
            }
        }
    }

    private var emptyTrackRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("01  NO TAPE LOADED   ·   02  SELECT AN ALBUM OR PLAYLIST")
                .font(.custom("GeistMono-Regular", fixedSize: 8.0))
                .tracking(0.5)
                .foregroundStyle(ink.opacity(0.58))
                .lineLimit(1)
            Text("03  LOCAL FILES & NAVIDROME   ·   04  PLAYING TRACK HIGHLIGHTS HERE")
                .font(.custom("GeistMono-Regular", fixedSize: 7.5))
                .tracking(0.4)
                .foregroundStyle(softInk)
                .lineLimit(1)
        }
        .padding(.top, 3)
    }

    private var editorialFooterLines: some View {
        let artistLine = readout.artistName.isEmpty ? "ONE CASSETTE STUDIO ARCHIVE" : readout.artistName.uppercased()
        let detail = readout.entries.first(where: \.isCurrent).map {
            "NOW PLAYING \(String(format: "%02d", $0.number)) · \($0.title.uppercased())"
        } ?? "HIGH-RESOLUTION PRINTED TRACK INDEX · NORMAL BIAS 120µs"
        return VStack(alignment: .leading, spacing: 2.5) {
            Text(artistLine)
                .font(.custom("InstrumentSerif-Regular", fixedSize: 12.5))
                .foregroundStyle(ink.opacity(0.84))
                .lineLimit(1)
            Text(detail)
                .font(.custom("GeistMono-Regular", fixedSize: 7.2))
                .tracking(0.6)
                .foregroundStyle(softInk)
                .lineLimit(1)
        }
    }

    private var footerStrip: some View {
        HStack {
            Text("ONE CASSETTE · PRINTED TRACK INDEX")
                .font(.custom("GeistMono-Regular", fixedSize: 6.5))
                .tracking(0.9)
                .foregroundStyle(softInk)
            Spacer()
            Text(readout.entries.count > 20 ? "+\(readout.entries.count - 20) MORE" : "C60 · STEREO")
                .font(.custom("GeistMono-Regular", fixedSize: 6.5))
                .tracking(0.9)
                .foregroundStyle(softInk)
        }
    }

    private func truncatedTitle(_ raw: String, limit: Int) -> String {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > limit else { return cleaned }
        return String(cleaned.prefix(limit - 1)) + "…"
    }

    private func packRows(
        items: [OneTapeCassetteReadout.TrackEntry],
        maxLines: Int,
        maxCharsPerRow: Int
    ) -> [[OneTapeCassetteReadout.TrackEntry]] {
        var rows: [[OneTapeCassetteReadout.TrackEntry]] = []
        var current: [OneTapeCassetteReadout.TrackEntry] = []
        var used = 0
        for item in items {
            let tokenLen = min(item.title.count, 22) + 5
            if !current.isEmpty && used + tokenLen > maxCharsPerRow {
                rows.append(current)
                if rows.count >= maxLines { return rows }
                current = [item]
                used = tokenLen
            } else {
                current.append(item)
                used += tokenLen + 2
            }
        }
        if !current.isEmpty && rows.count < maxLines {
            rows.append(current)
        }
        return rows
    }
}
