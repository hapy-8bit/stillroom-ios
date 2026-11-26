import AppIntents
import SwiftUI
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

enum OneTapeWidgetControlsMode {
    /// WidgetKit Home Screen mode using real `AudioPlaybackIntent` buttons.
    case intents
    /// Interactive Settings preview mode wired to live `OneTapeMusicStore` actions.
    case callbacks(onTogglePlayback: () -> Void, onNextTrack: () -> Void)
}

/// Shared dark/light matte surface with album dominant color tint wash and soft
/// top-leading sheen, used as both WidgetKit's `containerBackground` and the
/// Settings preview card backing.
struct OneTapeWidgetBackground: View {
    let snapshot: OneTapeWidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            baseSurface
            if let tint = snapshot.tint {
                LinearGradient(
                    colors: [
                        Color(red: tint.red, green: tint.green, blue: tint.blue)
                            .opacity(isDark ? 0.20 : 0.16),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            RadialGradient(
                colors: [
                    .white.opacity(isDark ? 0.07 : 0.48),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 220
            )
        }
    }

    private var baseSurface: Color {
        isDark
            ? Color(red: 0.105, green: 0.11, blue: 0.11)
            : Color(red: 0.91, green: 0.90, blue: 0.865)
    }
}

/// Canonical Small / Medium / Large cassette widget renderer shared between
/// Settings previews and the WidgetKit extension. Layouts are authored on
/// 170×170, 364×170, and 364×382 canvases and uniformly scaled to fit.
struct OneTapeWidgetCardView: View {
    let snapshot: OneTapeWidgetSnapshot
    let size: OneTapeWidgetSize
    let artwork: UIImage?
    let controlsMode: OneTapeWidgetControlsMode

    @Environment(\.colorScheme) private var colorScheme
    #if canImport(WidgetKit)
    @Environment(\.widgetRenderingMode) private var renderingMode
    #endif

    private var isDark: Bool { colorScheme == .dark }

    private var isFullColor: Bool {
        #if canImport(WidgetKit)
        renderingMode == .fullColor
        #else
        true
        #endif
    }

    private var primaryInk: Color {
        isDark ? Color(white: 0.94) : Color(red: 0.19, green: 0.21, blue: 0.21)
    }

    private var secondaryInk: Color {
        primaryInk.opacity(0.58)
    }

    private var playingLED: Color {
        Color(red: 0.50, green: 0.68, blue: 0.39)
    }

    var body: some View {
        GeometryReader { geometry in
            let design = size.designSize
            let scale = min(geometry.size.width / design.width, geometry.size.height / design.height)
            content
                .frame(width: design.width, height: design.height)
                .scaleEffect(scale, anchor: .center)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch size {
        case .small:
            smallBody
        case .medium:
            mediumBody
        case .large:
            largeBody
        }
    }

    // MARK: - Small (170 × 170)

    private var smallBody: some View {
        ZStack {
            cassette(width: 138, height: 93.15, angleDegrees: -8)
                .offset(x: 0.5, y: -0.5)

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text("A 面")
                        .tracking(1.4)
                    Spacer(minLength: 4)
                    Text("C60")
                        .tracking(1.0)
                }
                .font(.custom("GeistMono-Regular", fixedSize: 8))
                .foregroundStyle(secondaryInk)

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 5) {
                    Image(systemName: snapshot.isPlaying ? "play.fill" : "pause.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(snapshot.isPlaying ? playingLED : primaryInk)
                        .modifier(WidgetAccentableModifier(enabled: true))

                    Text(snapshot.smallStatusLabel)
                        .font(.custom("GeistMono-Regular", fixedSize: 8))
                        .tracking(1.1)
                        .foregroundStyle(primaryInk)

                    Spacer(minLength: 4)

                    Text(snapshot.counterText)
                        .font(.custom("GeistPixel-Square", fixedSize: 12))
                        .foregroundStyle(primaryInk)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.smallAccessibilitySummary)
    }

    // MARK: - Medium (364 × 170)

    private var mediumBody: some View {
        VStack(spacing: 0) {
            deckHeader
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 14) {
                cassette(width: 168, height: 113.4, angleDegrees: -8)
                    .offset(x: -2, y: 2)

                VStack(alignment: .leading, spacing: 0) {
                    Text(snapshot.cardTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(primaryInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if !snapshot.artist.isEmpty {
                        Text(snapshot.artist)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(secondaryInk)
                            .lineLimit(1)
                            .padding(.top, 3)
                    }

                    Spacer(minLength: 6)

                    transportButtons
                }
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Large (364 × 382)

    private var largeBody: some View {
        VStack(spacing: 0) {
            deckHeader

            Spacer(minLength: 6)

            cassette(width: 280, height: 189.0, angleDegrees: -5)

            Spacer(minLength: 6)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.cardTitle)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(primaryInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if !snapshot.artist.isEmpty {
                        Text(snapshot.artist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(secondaryInk)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                transportButtons
            }
            .frame(height: 74)

            largeCounterStrip
        }
        .padding(18)
    }

    // MARK: - Shared Subcomponents

    private var deckHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: 5) {
                Circle()
                    .fill(snapshot.isPlaying ? playingLED : secondaryInk)
                    .frame(width: 5, height: 5)
                    .modifier(WidgetAccentableModifier(enabled: snapshot.isPlaying))

                Text(snapshot.deckStatusLabel)
                    .font(.custom("GeistMono-Regular", fixedSize: 8))
                    .tracking(1.6)
                    .foregroundStyle(secondaryInk)
            }

            Spacer(minLength: 8)

            Text("A / 立体声")
                .font(.custom("GeistMono-Regular", fixedSize: 8))
                .tracking(1.1)
                .foregroundStyle(secondaryInk)
        }
        .accessibilityHidden(true)
    }

    private var transportButtons: some View {
        HStack(spacing: 8) {
            playPauseButton
            nextButton
        }
    }

    @ViewBuilder
    private var playPauseButton: some View {
        let icon = snapshot.isPlaying ? "pause.fill" : "play.fill"
        let label = snapshot.isPlaying ? "暂停" : "播放"
        switch controlsMode {
        case .intents:
            Button(intent: OneTapeTogglePlaybackIntent()) {
                buttonFace(systemName: icon, primary: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        case .callbacks(let onTogglePlayback, _):
            Button(action: onTogglePlayback) {
                buttonFace(systemName: icon, primary: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        }
    }

    @ViewBuilder
    private var nextButton: some View {
        switch controlsMode {
        case .intents:
            Button(intent: OneTapeNextTrackIntent()) {
                buttonFace(systemName: "forward.end.fill", primary: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下一首")
        case .callbacks(_, let onNextTrack):
            Button(action: onNextTrack) {
                buttonFace(systemName: "forward.end.fill", primary: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下一首")
        }
    }

    private func buttonFace(systemName: String, primary: Bool) -> some View {
        let iconColor: Color = {
            if !isFullColor { return primary ? .black : .white }
            if primary { return isDark ? Color(white: 0.10) : Color(white: 0.96) }
            return primaryInk
        }()
        let fillColor: Color = {
            if !isFullColor { return primary ? .white : .white.opacity(0.16) }
            if primary { return primaryInk }
            return isDark ? Color(white: 0.18) : primaryInk.opacity(0.07)
        }()
        let strokeColor: Color = .white.opacity(isDark ? 0.12 : 0.18)

        return Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(iconColor)
            .frame(width: 42, height: 38)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fillColor)
                    .modifier(WidgetAccentableModifier(enabled: primary))
            }
            .overlay {
                if !primary {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(strokeColor, lineWidth: 0.7)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var largeCounterStrip: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 3) {
                ForEach(Array(snapshot.counterDigits.enumerated()), id: \.offset) { _, digit in
                    Text(digit)
                        .font(.custom("GeistPixel-Square", fixedSize: 22))
                        .foregroundStyle(primaryInk)
                        .frame(width: 18, height: 28)
                        .background(
                            primaryInk.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 3, style: .continuous)
                        )
                }
            }

            Text("磁带计数")
                .font(.custom("GeistMono-Regular", fixedSize: 8))
                .tracking(1.0)
                .foregroundStyle(secondaryInk)
                .fixedSize()

            GeometryReader { bar in
                let fillWidth = max(0, bar.size.width * snapshot.clampedProgress)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(primaryInk.opacity(0.12))
                        .frame(height: 2.5)
                    Capsule()
                        .fill(snapshot.isPlaying ? playingLED : primaryInk.opacity(0.68))
                        .frame(width: fillWidth, height: 2.5)
                        .modifier(WidgetAccentableModifier(enabled: true))
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 12)

            Text("\(snapshot.percent)%")
                .font(.custom("GeistMono-Regular", fixedSize: 10))
                .monospacedDigit()
                .foregroundStyle(secondaryInk)
                .fixedSize()
        }
        .frame(height: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("专辑进度，百分之 \(snapshot.percent)")
    }

    private func cassette(width: CGFloat, height: CGFloat, angleDegrees: Double) -> some View {
        OneTapeWidgetCassetteView(snapshot: snapshot, artwork: artwork)
            .frame(width: width, height: height)
            .rotationEffect(.degrees(angleDegrees))
            .shadow(color: .black.opacity(isDark ? 0.50 : 0.22), radius: 10, x: 1, y: 10)
            .shadow(color: .black.opacity(0.16), radius: 2, x: 0, y: 2)
    }
}

private struct WidgetAccentableModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        #if canImport(WidgetKit)
        content.widgetAccentable(enabled)
        #else
        content
        #endif
    }
}
