import SwiftUI

/// The approved material study uses one uninterrupted image with live metadata
/// in its negative space. Coordinates are fractions of the proposed LCD size;
/// rotation exchanges that proposal before this view lays out its text.
struct OneTapeEditorialScreenFrame<Artwork: View>: View {
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
            let size = geometry.size
            let tall = size.height > size.width
            let scale = max(0.85, min(1.2, size.width / 264.39))
            ZStack(alignment: .topLeading) {
                artwork
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .accessibilityHidden(true)
                glassShading(tall: tall)
                if style == .fluid {
                    trackIndex(scale: scale)
                        .padding(.leading, size.width * 0.08)
                        .padding(.top, size.height * 0.09)
                    metadata(scale: scale, tall: tall)
                        .frame(width: size.width * (tall ? 0.84 : 0.70), alignment: .leading)
                        .frame(maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.leading, size.width * 0.08)
                        .padding(.bottom, size.height * 0.18)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        trackIndex(scale: scale)
                            .padding(.bottom, size.width * (style == .iron ? 0.032 : 0.05))
                        metadata(scale: scale, tall: tall,
                                 artistWidth: style == .dunes ? size.width * (tall ? 0.60 : 0.44) : nil)
                    }
                    .frame(width: size.width * (tall ? 0.84 : (style == .dunes ? 0.58 : 0.62)),
                           alignment: .leading)
                    .padding(.leading, size.width * 0.08)
                    .padding(.top, size.height * (style == .iron ? 0.31 : 0.12))
                }
                footer(scale: scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.horizontal, size.width * 0.08)
                    .padding(.bottom, size.height * (style == .fluid ? 0.07 : 0.085))
            }
            .frame(width: size.width, height: size.height)
            .background(Color(white: 0.04))
            .foregroundStyle(Color(red: 0.933, green: 0.918, blue: 0.886))
            .clipped()
        }
    }

    private func glassShading(tall: Bool) -> some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: .black.opacity(0.09), location: 0),
                .init(color: .clear, location: 0.18),
                .init(color: .clear, location: style == .dunes && tall ? 0.65 : 0.79),
                .init(color: .black.opacity(style == .dunes && tall ? 0.75 : 0.20), location: 1)
            ], startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [.clear, .black.opacity(0.07)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func trackIndex(scale: CGFloat) -> some View {
        Text("A — \(readout.hasTrack ? String(format: "%02d", readout.trackIndex + 1) : "--")")
            .font(.custom("DMMono-Regular", fixedSize: 8.3 * scale))
            .tracking(0.5 * scale)
            .foregroundStyle(Color(white: 0.73))
            .lineLimit(1)
            .accessibilityIdentifier("screen.readout.track")
    }

    private func metadata(scale: CGFloat, tall: Bool, artistWidth: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3.5 * scale) {
            Text(title)
                .font(titleFont(scale: scale))
                .tracking(style == .iron ? -0.5 * scale : -0.2 * scale)
                // Long names stay in the dark negative space instead of
                // pushing the artist across the dune's illuminated ridge.
                .lineLimit(tall ? 2 : 1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("screen.readout.title")
            Text(artist)
                .font(.custom("DMSans-Regular", fixedSize: 9 * scale))
                .foregroundStyle(Color(white: 0.73))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: artistWidth ?? .infinity, alignment: .leading)
                .accessibilityIdentifier("screen.readout.artist")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func titleFont(scale: CGFloat) -> Font {
        switch style {
        case .iron: .custom("DMSans-Medium", fixedSize: 16 * scale)
        case .fluid: .custom("InstrumentSerif-Italic", fixedSize: 23 * scale)
        default: .custom("InstrumentSerif-Regular", fixedSize: 21 * scale)
        }
    }

    @ViewBuilder
    private func footer(scale: CGFloat) -> some View {
        if style == .dunes {
            VStack(alignment: .trailing, spacing: 3 * scale) {
                time(scale: scale)
                status(scale: scale)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8 * scale) {
                time(scale: scale)
                Spacer(minLength: 3)
                status(scale: scale)
            }
        }
    }

    private func time(scale: CGFloat) -> some View {
        HStack(spacing: 4 * scale) {
            Text(readout.positionLabel)
                .accessibilityIdentifier("screen.readout.elapsed")
            Text("/ \(MediaTime.label(readout.durationSeconds))")
                .foregroundStyle(Color(white: 0.62))
                .accessibilityIdentifier("screen.readout.duration")
        }
        .font(.custom("DMMono-Regular", fixedSize: 8.5 * scale))
        .tracking(0.2 * scale)
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(Color(white: 0.82))
    }

    private func status(scale: CGFloat) -> some View {
        Text(statusLabel)
            .font(.custom("DMMono-Regular", fixedSize: 8 * scale))
            .tracking(0.8 * scale)
            .foregroundStyle(Color(white: 0.67))
            .lineLimit(1)
            .fixedSize()
            .accessibilityIdentifier("screen.readout.status")
    }

    private var title: String {
        guard readout.hasTrack else { return "还没有磁带" }
        let text = readout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "未命名歌曲" : text
    }

    private var artist: String {
        if readout.isPreparing { return "正在准备播放" }
        guard readout.hasTrack else { return "在音乐库添加音乐" }
        let text = readout.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "未知艺人" : text
    }

    private var statusLabel: String {
        if readout.isPreparing { return "LOADING" }
        guard readout.hasTrack else { return "NO TAPE" }
        return readout.isPlaying ? "PLAY" : "PAUSED"
    }
}

extension OneTapeAppearance.ScreenStyle {
    var usesPhotographicMaterial: Bool {
        self == .dunes || self == .iron || self == .fluid
    }
}
