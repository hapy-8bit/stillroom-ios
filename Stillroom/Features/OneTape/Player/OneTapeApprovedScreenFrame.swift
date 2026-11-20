import SwiftUI

/// Full-panel approved composition, driven only by one authoritative readout.
/// The particle leaf owns the name title; every other glyph uses the shared
/// logical-point baseline contract so rotation does not stretch a wide layout.
struct OneTapeApprovedScreenFrame<Artwork: View>: View {
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
            let metadata = OneTapeApprovedScreenLayout.metadataTextLayout(
                style: style, title: readout.screenTitle, size: size)
            let name = OneTapeApprovedScreenLayout.nameTextLayout(title: readout.screenTitle, size: size)
            let copyRect = OneTapeApprovedScreenLayout.metadataRect(size: size)
            let artistRect = style == .name
                ? CGRect(x: size.width * 0.09, y: 0, width: size.width * 0.82, height: size.height) : copyRect
            let symbolRect = OneTapeApprovedScreenLayout.symbolRect(size: size)
            ZStack(alignment: .topLeading) {
                artwork
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .accessibilityHidden(true)
                glassShading
                header(size: size)
                if style != .name {
                    ForEach(Array(metadata.lines.enumerated()), id: \.offset) { index, line in
                        baselineText(rect: copyRect,
                                     baseline: metadata.firstBaseline + CGFloat(index) * metadata.linePitch) {
                            Text(line)
                                .font(OneTapeApprovedScreenTypeface.titleFont(size: size))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel(readout.screenTitle)
                                .accessibilityHidden(index > 0)
                                .accessibilityIdentifier(index == 0 ? "screen.readout.title" : "screen.readout.title.continuation")
                        }
                    }
                }
                baselineText(rect: artistRect, baseline: style == .name ? name.artistBaseline : metadata.artistBaseline) {
                    Text(readout.screenArtist)
                        .font(OneTapeApprovedScreenTypeface.artistFont(size: size))
                        .foregroundStyle(muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: style == .name ? .center : .leading)
                        .accessibilityIdentifier("screen.readout.artist")
                }
                time(size: size, remaining: false)
                time(size: size, remaining: true)
                OneTapeScreenPlaybackSymbol(style: style, state: readout.screenState,
                                          unit: OneTapeApprovedScreenTypeface.unit(size: size))
                    .frame(width: symbolRect.width, height: symbolRect.height)
                    .position(x: symbolRect.midX, y: symbolRect.midY)
            }
            .frame(width: size.width, height: size.height)
            .background(Color(white: 0.035))
            .foregroundStyle(ink)
            .clipped()
        }
    }

    private func header(size: CGSize) -> some View {
        let rect = OneTapeApprovedScreenLayout.metadataRect(size: size)
        let baseline = OneTapeApprovedScreenLayout.headerBaseline(size: size)
        return ZStack(alignment: .topLeading) {
            baselineText(rect: rect, baseline: baseline) {
                Text(readout.screenTrackLabel)
                    .font(OneTapeApprovedScreenTypeface.headerFont(size: size))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("screen.readout.track")
            }
            baselineText(rect: rect, baseline: baseline) {
                Text(readout.screenSideLabel)
                    .font(OneTapeApprovedScreenTypeface.headerFont(size: size))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("screen.readout.side")
            }
        }
        .foregroundStyle(muted)
    }

    private func time(size: CGSize, remaining: Bool) -> some View {
        let value = remaining ? readout.screenRemainingLabel : readout.screenElapsedLabel
        let rect = remaining ? OneTapeApprovedScreenLayout.remainingRect(size: size)
            : OneTapeApprovedScreenLayout.elapsedRect(size: size)
        let pointSize = OneTapeApprovedScreenTypeface.timeSize(style: style, size: size,
                                                              text: value, remaining: remaining)
        return baselineText(rect: rect, baseline: OneTapeApprovedScreenLayout.readoutBaseline(size: size)) {
            Text(value)
                .font(.custom(OneTapeApprovedScreenTypeface.timeFace(style: style), fixedSize: pointSize))
                .foregroundStyle(remaining ? muted : ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: remaining ? .trailing : .leading)
                .accessibilityLabel(remaining
                    ? (readout.hasTrack && readout.durationSeconds > 0 ? "剩余 \(value.dropFirst())" : "剩余时间未知")
                    : (readout.hasTrack ? "已播放 \(value)" : "尚未载入曲目"))
                .accessibilityIdentifier(remaining ? "screen.readout.remaining" : "screen.readout.elapsed")
        }
    }

    private func baselineText<Content: View>(rect: CGRect, baseline: CGFloat,
                                             @ViewBuilder content: () -> Content) -> some View {
        OneTapeScreenBaselineAnchor(rect: rect, baseline: baseline) { content() }
    }

    private var glassShading: some View {
        LinearGradient(stops: [
            .init(color: .black.opacity(0.06), location: 0),
            .init(color: .clear, location: 0.20),
            .init(color: .clear, location: 0.77),
            .init(color: .black.opacity(0.20), location: 1)
        ], startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var ink: Color { Color(red: 238 / 255, green: 234 / 255, blue: 223 / 255) }
    private var muted: Color { Color(red: 185 / 255, green: 185 / 255, blue: 176 / 255) }
}

/// Canvas preview coordinates name a text baseline. SwiftUI position() names a
/// view center instead, so use actual text dimensions to preserve that baseline
/// for serif numerals, Chinese fallback glyphs and emoji without guessed offsets.
private struct OneTapeScreenBaselineAnchor: Layout {
    let rect: CGRect
    let baseline: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: rect.maxX, height: max(1, baseline + 12)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let view = subviews.first else { return }
        let textProposal = ProposedViewSize(width: rect.width, height: nil)
        let dimensions = view.dimensions(in: textProposal)
        view.place(at: CGPoint(x: bounds.minX + rect.minX,
                               y: bounds.minY + baseline - dimensions[.firstTextBaseline]),
                   anchor: .topLeading, proposal: textProposal)
    }
}
