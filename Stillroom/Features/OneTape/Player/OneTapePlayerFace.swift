import SwiftUI

/// A reference canvas in logical design points. Resource pixels are resolved by
/// the image catalog; the window transform applies to drawing and controls once.
struct OneTapePlayerFace: View {
    let appearance: OneTapeAppearance
    var readout: OneTapePlaybackReadout = .empty
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var customPrint: OneTapeResolvedPrint? = nil
    var artwork: UIImage? = nil
    var artworkColor: OneTapeTransportMaterial.RGB? = nil
    var visualization: AudioVisualizationSignal? = nil
    var tiltMonitor: OneTapeTiltMonitor? = nil
    var tapeProgress: Double = 0
    var quarterTurns: Int = 0
    var trackChangeMotionRate: Double? = nil
    var openingPose: OneTapeOpeningPlayerPose? = nil
    var playbackMode: OneTapePlaybackMode = .listLoop
    let glassInteractionEnabled: Bool
    let onGlass: () -> Void
    let onLCD: () -> Void
    let onTransport: (OneTapeTransportAction) -> Void
    let onSetGlassOpen: (Bool) -> Void
    var onBeginWind: (Int) -> Void = { _ in }
    var onEndWind: (Bool) -> Void = { _ in }
    var onPlaybackMode: () -> Void = {}

    @State private var windingDirection = 0

    private let canvas = CGSize(width: 393, height: 852)
    private var bodyReveal: Double { openingPose?.bodyReveal ?? 1 }

    var body: some View {
        GeometryReader { proxy in
            let scale = max(0.01, min(proxy.size.width / canvas.width,
                                      proxy.size.height / canvas.height))
            ZStack {
                OneTapeBodyFinish(appearance: appearance, artworkColor: artworkColor).backdrop
                    .opacity(bodyReveal)
                face(scale: scale, windowSize: proxy.size)
                    .frame(width: canvas.width, height: canvas.height)
                    .scaleEffect(scale)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }

    private func face(scale: CGFloat, windowSize: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let tiltMonitor, appearance.needsMotionTilt {
                    OneTapeLiveBodySurface(
                        appearance: appearance,
                        artworkColor: artworkColor,
                        artwork: artwork,
                        tiltMonitor: tiltMonitor,
                        visualization: visualization
                    )
                } else {
                    OneTapeBodySurface(appearance: appearance, artworkColor: artworkColor, artwork: artwork)
                }
            }
            .opacity(bodyReveal)
            .accessibilityHidden(true)

            OneTapeReelMotion(rate: trackChangeMotionRate ?? (windingDirection != 0
                ? Double(windingDirection) * OneTapeTransportRules.windingRate : readout.isPlaying ? 1 : 0),
                progress: tapeProgress, layout: .transport) { frame in
                cassette(frame: frame)
                    .modifier(OneTapeOpeningCassetteTransform(pose: openingPose, windowSize: windowSize))
            }
            .frame(width: canvas.width, height: canvas.height)

            Button(action: onLCD) {
                OneTapeDisplay(style: appearance.screenStyle, readout: readout,
                    visualization: visualization, quarterTurns: quarterTurns,
                    lcdMaterial: OneTapeLCDMaterial(appearance: appearance, artworkColor: artworkColor))
                    .frame(width: 264.39, height: 165.63)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: 100.33, y: 651.12)
            .opacity(bodyReveal)
            .accessibilityIdentifier("tape.lcd")
            .accessibilityLabel(readout.hasTrack
                ? "\(readout.title)，\(readout.artist)，第 \(readout.trackIndex + 1) 首，共 \(readout.trackCount) 首"
                : "当前播放，还没有磁带")
            .accessibilityValue(readout.hasTrack
                ? "\(appearance.screenStyle.resolvedStyle.rawValue)；\(screenAccessibilityState)；\(readout.positionLabel)；\(MediaTime.label(readout.durationSeconds))；\(readout.screenRemainingLabel)；\(readout.screenSideLabel)"
                : appearance.screenStyle.resolvedStyle.rawValue)
            .accessibilityHint(readout.hasTrack
                ? (appearance.screenStyle.resolvedStyle == .meters
                    ? "轻点切换屏幕样式；电平仅在可读取音频信号时显示" : "轻点切换屏幕样式")
                : "查看播放器外观")

            key(quarterTurns == -1 ? .next : .previous,
                y: OneTapeTransportGeometry.centersY[0], scale: scale)
                .opacity(bodyReveal)
            key(.play, y: OneTapeTransportGeometry.centersY[1], scale: scale)
                .opacity(bodyReveal)
            key(quarterTurns == -1 ? .previous : .next,
                y: OneTapeTransportGeometry.centersY[2], scale: scale)
                .opacity(bodyReveal)

            OneTapePlaybackModeKey(
                mode: playbackMode,
                appearance: appearance,
                artworkColor: artworkColor,
                hitDiameter: max(OneTapePlaybackModeKey.visualDiameter, 44 / max(0.01, scale)),
                quarterTurns: quarterTurns,
                action: onPlaybackMode
            )
            .position(x: OneTapeTransportGeometry.centerX, y: 34)
            .opacity(bodyReveal)
        }
    }

    private var screenAccessibilityState: String {
        switch readout.screenState {
        case .empty: "暂无歌曲"
        case .loading: "正在加载"
        case .playing: "播放中"
        case .paused: "已暂停"
        }
    }

    private func cassette(frame: OneTapeReelKinematics.Frame) -> some View {
        let supplyAngle = Angle(radians: frame.supplyRadians)
        let takeupAngle = Angle(radians: frame.takeupRadians)
        return ZStack(alignment: .topLeading) {
            OneTapeGlassControl(
                isOpen: appearance.glassOpen,
                summary: "\(appearance.tapeStyle.customizationTitle)，\(printAccessibilitySummary)"
                    + (appearance.tapeStyle.isSculpted ? "，\(cassetteReadout.accessibilitySummary)" : ""),
                isEnabled: glassInteractionEnabled,
                onTap: onGlass,
                onSetOpen: onSetGlassOpen
            ) { progress, isTransitioning in
                OneTapeGlassCover(appearance: appearance, cassetteReadout: cassetteReadout, customPrint: customPrint,
                    tiltMonitor: tiltMonitor, progress: progress, isTransitioning: isTransitioning,
                    supplyAngle: supplyAngle, takeupAngle: takeupAngle,
                    tapeProgress: frame.progress, reelExposureDegrees: frame.exposureDegrees)
            }
            .frame(width: 353.91, height: 553.8)
            .offset(x: 19.55, y: 68.3)

        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
    }

    private func key(_ action: OneTapeTransportAction, y: CGFloat, scale: CGFloat) -> some View {
        let label: String
        let identifier: String
        switch action {
        case .previous:
            label = "上一首"
            identifier = "tape.previous"
        case .play:
            label = playKeyEngaged ? "暂停" : "播放"
            identifier = "tape.play"
        case .next:
            label = "下一首"
            identifier = "tape.next"
        }
        return OneTapeTransportKey(
            supportsHold: action != .play,
            hitDiameter: OneTapeTransportGeometry.hitDiameter(scale: scale),
            action: { onTransport(action) },
            onHoldBegan: {
                if readout.hasTrack {
                    windingDirection = action == .previous ? -1 : 1
                    onBeginWind(windingDirection)
                }
            },
            onHoldEnded: { windingDirection = 0; onEndWind($0) },
            appearance: appearance,
            artworkColor: artworkColor,
            transportAction: action,
            isPlayKey: action == .play,
            illuminated: action == .play && playKeyEngaged,
            quarterTurns: quarterTurns
        )
        .position(x: OneTapeTransportGeometry.centerX, y: y)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
        .accessibilityValue(action == .play ? playKeyAccessibilityValue : "")
    }

    // During a short mechanical change the engine is deliberately paused. The
    // key still means cancel/pause; media labels continue to show real time.
    private var playKeyEngaged: Bool {
        readout.isPlaying || readout.isPreparing || trackChangeMotionRate != nil
    }

    private var playKeyAccessibilityValue: String {
        if let rate = trackChangeMotionRate { return rate == 0 ? "亮起；切歌停顿" : "亮起；切歌快转" }
        return playKeyEngaged ? "亮起" : "未亮起"
    }

    private var printAccessibilitySummary: String {
        let foilNote = appearance.tapeFoilStyle == .holo ? "，全息镭射箔" : ""
        if appearance.trackListEnabled {
            return "曲目表印花\(foilNote)"
        }
        if appearance.customDrawingID != nil {
            return "自定义画作\(foilNote)"
        }
        if appearance.customArtworkID != nil {
            return "自定义照片印花\(foilNote)"
        }
        return "\(appearance.isBrandPrintVisible ? "One Cassette 印字" : "无品牌印字")，\(appearance.doodleStyle.customizationTitle)\(foilNote)"
    }
}

/// The source still's 376.33×576 logical canvas includes 11-point backdrop
/// padding. The rounded boundary aligns with the sliding glass and keeps its
/// narrow photographed rim, while allowing the body color to show outside it.
struct OneTapeCassettePocketMask: Shape {
    // The fixed module frame is shared by the tape crop and body-finish cutout.
    // Its size is in player design points, independent of tape or screen style.
    static let openingFrame = CGRect(x: 19.55, y: 68.3, width: 353.91, height: 553.8)

    // Visible plastic bounds in the cassette's 376.33×576 logical canvas.
    // Calibrate every shell to the classic shell, not its photograph's padding;
    // the surrounding pocket and its separation from the body stay fixed.
    static let shellFrame = OneTapeCassetteStandard.portraitShellFrame

    func path(in rect: CGRect) -> Path {
        let xScale = rect.width / 376.33
        let yScale = rect.height / 576
        let pocket = CGRect(x: rect.minX + (Self.openingFrame.minX - 8.33) * xScale,
                            y: rect.minY + (Self.openingFrame.minY - 57.33) * yScale,
                            width: Self.openingFrame.width * xScale,
                            height: Self.openingFrame.height * yScale)
        return Path(roundedRect: pocket,
                    cornerSize: CGSize(width: 19.12 * xScale, height: 19.12 * yScale))
    }
}
