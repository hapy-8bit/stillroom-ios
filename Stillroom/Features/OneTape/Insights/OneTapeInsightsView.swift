import SwiftUI

/// Dedicated "洞察" listening analytics surface aligned with One Cassette's
/// tactile dark-room instrument aesthetic and reflective monochrome LCD grammar.
struct OneTapeInsightsView: View {
    let ledger: ListeningLedger
    let liveEvent: ListeningSessionEvent?
    let appearance: OneTapeAppearance
    let albums: [MusicCollection]
    let tracks: [Track]
    let artworks: [String: UIImage]
    let favorites: Set<String>
    let isPlaying: Bool
    let isActive: Bool
    let onLoadArtwork: (MusicCollection) -> Void
    let onPlayAlbum: (String) -> Void
    let onPlayTrack: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var rangeSelection
    @State private var range: ListeningTimeRange = .week
    @State private var appeared = false
    @State private var revealTrigger = 0
    @State private var rangeTapCount = 0

    private let accent = Color(red: 0.87, green: 0.55, blue: 0.25)

    private var snapshot: ListeningInsightsSnapshot {
        ListeningInsightsSnapshot.build(
            ledger: ledger,
            liveEvent: liveEvent,
            range: range,
            tracks: tracks,
            albums: albums,
            favorites: favorites
        )
    }

    private var lcdMaterial: OneTapeLCDMaterial {
        OneTapeLCDMaterial(appearance: appearance)
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: Color(white: 0.10), location: 0),
                    .init(color: Color(white: 0.04), location: 0.24),
                    .init(color: Color(white: 0.02), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.container)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                        .modifier(StaggeredReveal(visible: appeared, index: 0, reduceMotion: reduceMotion))

                    OneTapeInsightsLCDHero(
                        snapshot: snapshot,
                        lcdMaterial: lcdMaterial,
                        isPlaying: isPlaying,
                        isActive: isActive,
                        revealTrigger: revealTrigger
                    )
                    .modifier(StaggeredReveal(visible: appeared, index: 1, reduceMotion: reduceMotion))

                    metricPair
                        .modifier(StaggeredReveal(visible: appeared, index: 2, reduceMotion: reduceMotion))

                    OneTapeInsightsRhythmCard(
                        snapshot: snapshot,
                        revealTrigger: revealTrigger
                    )
                    .modifier(StaggeredReveal(visible: appeared, index: 3, reduceMotion: reduceMotion))

                    OneTapeInsightsRankingsCard(
                        snapshot: snapshot,
                        albums: albums,
                        tracks: tracks,
                        artworks: artworks,
                        revealTrigger: revealTrigger,
                        onLoadArtwork: onLoadArtwork,
                        onPlayAlbum: onPlayAlbum,
                        onPlayTrack: onPlayTrack
                    )
                    .modifier(StaggeredReveal(visible: appeared, index: 4, reduceMotion: reduceMotion))

                    OneTapeInsightsLibraryCard(
                        library: snapshot.library,
                        revealTrigger: revealTrigger
                    )
                    .modifier(StaggeredReveal(visible: appeared, index: 5, reduceMotion: reduceMotion))
                }
                .padding(.horizontal, 16)
                // Reserve generous clearance above the floating glass navigation dock.
                .padding(.bottom, 118)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("insights.scroll")
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: rangeTapCount)
        .onAppear { triggerEntrance() }
        .onChange(of: isActive) { _, active in
            if active {
                triggerEntrance()
            } else if !reduceMotion {
                appeared = false
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("洞察")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("insights.title")

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                ForEach(ListeningTimeRange.allCases) { item in
                    let selected = range == item
                    Button {
                        guard range != item else { return }
                        rangeTapCount += 1
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.26, bounce: 0.10)) {
                            range = item
                        }
                    } label: {
                        Text(item.title)
                            .font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                            .foregroundStyle(.white.opacity(selected ? 0.96 : 0.50))
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background {
                                if selected {
                                    Capsule()
                                        .fill(.white.opacity(0.16))
                                        .matchedGeometryEffect(id: "insights.rangePill", in: rangeSelection)
                                }
                            }
                            .frame(minHeight: 36)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("insights.range.\(item.rawValue)")
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 3)
            .background(.white.opacity(0.055), in: Capsule())
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.075), lineWidth: 0.6)
            }
        }
    }

    private var metricPair: some View {
        HStack(spacing: 12) {
            playsCard
            focusCard
        }
    }

    private var playsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("有效曲次")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.50))
                Spacer()
                if snapshot.currentStreakDays > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(accent).frame(width: 5.5, height: 5.5)
                        Text("连续 \(snapshot.currentStreakDays) 天")
                            .font(.custom("GeistMono-Regular", size: 10.5))
                            .foregroundStyle(accent)
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(snapshot.countedPlays)")
                    .font(.custom("GeistMono-Regular", size: 28))
                    .foregroundStyle(.white.opacity(0.94))
                    .contentTransition(.numericText())
                Text("首")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Text(snapshot.activeDays > 0 ? "活跃聆听 \(snapshot.activeDays) 天" : "本周期尚无有效曲次")
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.036), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.075), lineWidth: 0.6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("insights.metric.plays")
    }

    private var focusCard: some View {
        let rateText: String = {
            guard let rate = snapshot.completionRate else { return "--" }
            return "\(Int((rate * 100).rounded()))"
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("完播专注")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.50))
                Spacer()
                Text(snapshot.peakWindowLabel)
                    .font(.custom("GeistMono-Regular", size: 10.5))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(rateText)
                    .font(.custom("GeistMono-Regular", size: 28))
                    .foregroundStyle(.white.opacity(0.94))
                    .contentTransition(.numericText())
                Text("%")
                    .font(.custom("GeistMono-Regular", size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.06))
                    if let rate = snapshot.completionRate {
                        Capsule()
                            .fill(accent)
                            .frame(width: max(4, proxy.size.width * CGFloat(max(0, min(1, rate)))))
                    }
                }
            }
            .frame(height: 4)
            .padding(.top, 5)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.036), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.075), lineWidth: 0.6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("insights.metric.focus")
    }

    private func triggerEntrance() {
        revealTrigger += 1
        if reduceMotion {
            appeared = true
            return
        }
        appeared = false
        DispatchQueue.main.async {
            appeared = true
        }
    }
}

/// Mechanical staggered entrance modifier matching One Cassette's damped reveal cadence.
private struct StaggeredReveal: ViewModifier {
    let visible: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(visible || reduceMotion ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 14)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(duration: 0.42, bounce: 0.06).delay(Double(index) * 0.045),
                value: visible
            )
    }
}
