import SwiftUI

/// First product draft of a shared playback-information frame, not a verified
/// reconstruction of the reference app's paid screens. Artwork gets a separate
/// clipped region; its blur, blending and visual clock cannot paint over text.
struct OneTapeScreenFrame<Artwork: View>: View {
    let style: OneTapeAppearance.ScreenStyle
    let readout: OneTapePlaybackReadout
    private let artwork: Artwork

    init(style: OneTapeAppearance.ScreenStyle, readout: OneTapePlaybackReadout,
         @ViewBuilder artwork: () -> Artwork) {
        self.style = style
        self.readout = readout
        self.artwork = artwork()
    }

    var body: some View {
        GeometryReader { geometry in
            // The caller exchanges logical width/height before rotating the
            // screen. Size this layout from that proposal, never device pixels.
            let tall = geometry.size.height > geometry.size.width
            let inset = min(10, max(7, geometry.size.width * 0.04))
            VStack(spacing: 0) {
                header(tall: tall)
                    .padding(.bottom, tall ? 6 : 4)
                    .fixedSize(horizontal: false, vertical: true)
                artwork
                    .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .background(background)
                    .clipped()
                    .layoutPriority(-1)
                    .accessibilityHidden(true)
                footer
                    .padding(.top, tall ? 6 : 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, inset)
            .padding(.vertical, tall ? 8 : 6)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .foregroundStyle(ink)
            .background(background)
            .clipped()
        }
    }

    private func header(tall: Bool) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 5) {
                Text("曲 \(readout.trackLabel)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("screen.readout.track")
                Spacer(minLength: 3)
                Text("面 A")
                    .fixedSize()
                Spacer(minLength: 3)
                Text(status)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityIdentifier("screen.readout.status")
            }
            .font(.system(size: tall ? 8 : 8.5, weight: .medium, design: .monospaced))
            .foregroundStyle(ink.opacity(0.74))
            .frame(height: 12)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(readout.positionLabel)
                    .font(.system(size: tall ? 20 : 18, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .accessibilityLabel("已播放 \(readout.positionLabel)")
                    .accessibilityIdentifier("screen.readout.elapsed")
                Spacer(minLength: 2)
                Text(readout.remainingLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(ink.opacity(0.76))
                    .accessibilityLabel("剩余 \(readout.remainingLabel.dropFirst())")
                    .accessibilityIdentifier("screen.readout.remaining")
            }
            .monospacedDigit()
            .frame(height: tall ? 25 : 23, alignment: .center)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            if style != .name {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("screen.readout.title")
                Text(artist)
                    .font(.system(size: 10))
                    .foregroundStyle(ink.opacity(0.73))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("screen.readout.artist")
            } else if !readout.hasTrack || readout.isPreparing {
                // The name artwork already renders title/artist as grains.
                // Keep just actionable empty/loading feedback beneath it.
                Text(readout.isPreparing ? "正在准备播放" : "在音乐库添加音乐")
                    .font(.system(size: 10))
                    .foregroundStyle(ink.opacity(0.73))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("screen.readout.notice")
            }
            OneTapeScreenFrameProgress(fraction: readout.fraction, ink: ink)
                .frame(height: 2)
                .padding(.top, style == .name ? 0 : 2)
        }
    }

    private var status: String {
        if readout.isPreparing { return "准备中" }
        if !readout.hasTrack { return "未装入" }
        return readout.isPlaying ? "播放中" : "已暂停"
    }

    private var title: String {
        guard readout.hasTrack else { return "还没有磁带" }
        let text = readout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "未命名歌曲" : text
    }

    private var artist: String {
        guard readout.hasTrack else { return "在音乐库添加音乐" }
        let text = readout.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "未知艺人" : text
    }

    private var usesPaper: Bool {
        switch style {
        case .lcd, .fluid, .name, .fox, .ink: true
        default: false
        }
    }

    private var background: Color {
        usesPaper ? Color(red: 218 / 255, green: 223 / 255, blue: 224 / 255)
            : Color(red: 0.045, green: 0.060, blue: 0.066)
    }

    private var ink: Color {
        usesPaper ? Color(red: 17 / 255, green: 22 / 255, blue: 18 / 255)
            : Color(red: 0.86, green: 0.90, blue: 0.87)
    }
}

private struct OneTapeScreenFrameProgress: View {
    let fraction: Double
    let ink: Color

    private var finiteFraction: Double {
        fraction.isFinite ? min(1, max(0, fraction)) : 0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(ink.opacity(0.17))
                Capsule().fill(ink.opacity(0.88))
                    .frame(width: max(0, geometry.size.width) * finiteFraction)
            }
        }
        .accessibilityLabel("播放进度")
        .accessibilityValue("\(Int(finiteFraction * 100))%")
        .accessibilityIdentifier("screen.readout.progress")
    }
}
