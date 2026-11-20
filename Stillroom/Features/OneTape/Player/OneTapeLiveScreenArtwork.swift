import SwiftUI

/// Approved artwork studies adapted to live content. The parent supplies visual
/// seconds and measured audio; no clock, playback engine or persistence lives here.
struct OneTapeLiveScreenArtwork: View {
    let style: OneTapeAppearance.ScreenStyle
    let phase: Double
    let readout: OneTapePlaybackReadout
    let response: OneTapeScreenResponse
    let signalAvailable: Bool

    var body: some View {
        switch style {
        case .fluid:
            OneTapePhotographicMaterial(style: .fluid, phase: phase)
        case .rain, .trails:
            OneTapeLivePhotoArtwork(style: style, phase: phase)
        case .name:
            OneTapeParticleTitle(readout: readout, phase: phase)
        case .meters:
            OneTapeMeasuredMeters(response: response,
                signalAvailable: signalAvailable && readout.isPlaying && !readout.isPreparing,
                showUnavailable: readout.isPlaying && !readout.isPreparing && !signalAvailable)
        default:
            Color.clear
        }
    }
}

/// Pausing clears the lamps. Missing PCM deliberately produces
/// empty rails; a silent measured frame is also empty, with no synthetic rhythm.
struct OneTapeMeasuredMeters: View {
    let response: OneTapeScreenResponse
    let signalAvailable: Bool
    var showUnavailable = false

    var body: some View {
        let measured = response
        let available = signalAvailable
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(red: 0.022, green: 0.031, blue: 0.034)))
            let tall = size.height > size.width
            let layout = OneTapeScreenLayoutGeometry(size: size)
            let unit = layout.unit
            let plot = OneTapeApprovedScreenLayout.artworkRect(style: .meters, size: size)
            let columns = tall ? 8 : 16, rows = tall ? 20 : 25
            let pitch = plot.height / Double(rows)
            let gap = plot.width / Double(columns)
            let barWidth = gap * layout.mix(0.38, 0.49)
            let bottom = plot.maxY
            for column in 0..<columns {
                let values = Self.columnValues(response: measured, column: column, narrow: tall)
                let level = available ? values.amplitude : 0
                let peak = available ? values.peak : 0
                let x = plot.minX + Double(column) * gap + (gap - barWidth) / 2
                for row in 0..<rows {
                    let lit = row < Int(floor(level * Double(rows)))
                    let tint = Double(row) > Double(rows) * 0.82 ? Color(red: 0.85, green: 0.67, blue: 0.39)
                        : Color(red: 0.89, green: 0.86, blue: 0.75)
                    let rect = CGRect(x: x, y: bottom - Double(row + 1) * pitch,
                                      width: barWidth, height: max(0.6 * unit, pitch * 0.24))
                    context.fill(Path(rect), with: .color(tint.opacity(lit ? 0.76 : 0.045)))
                }
                if peak > 0.01 {
                    let rect = CGRect(x: x, y: bottom - (floor(peak * Double(rows - 1)) + 1) * pitch,
                                      width: barWidth, height: max(0.6 * unit, pitch * 0.25))
                    context.fill(Path(rect), with: .color(Color(red: 0.91, green: 0.76, blue: 0.47)))
                }
            }
        }
        .overlay {
            if showUnavailable {
                GeometryReader { geometry in
                    let plot = OneTapeApprovedScreenLayout.artworkRect(style: .meters, size: geometry.size)
                    Text("暂不支持音频显示")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color(red: 0.83, green: 0.81, blue: 0.72))
                        .padding(.horizontal, 5).padding(.vertical, 3)
                        .background(Color.black.opacity(0.85))
                        .position(x: plot.midX, y: plot.midY)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Pair adjacent measured bands in a narrow screen. Averaging amplitude
    /// retains their energy trend; the held marker uses the larger measured peak.
    nonisolated static func columnValues(response: OneTapeScreenResponse, column: Int,
                                        narrow: Bool) -> (amplitude: Double, peak: Double) {
        if narrow {
            let first = column * 2
            return ((level(response.bands, first) + level(response.bands, first + 1)) / 2,
                    max(level(response.heldPeaks, first), level(response.heldPeaks, first + 1)))
        }
        return (level(response.bands, column), level(response.heldPeaks, column))
    }

    nonisolated private static func level(_ values: [Double], _ index: Int) -> Double {
        guard values.indices.contains(index), values[index].isFinite else { return 0 }
        return min(1, max(0, values[index]))
    }
}

private struct OneTapeLivePhotoArtwork: View {
    let style: OneTapeAppearance.ScreenStyle
    let phase: Double
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.oneTapePhotoFrameMode) private var frameMode

    var body: some View {
        let selected = style
        let seconds = reduceMotion ? 0 : (phase.isFinite ? max(0, phase) : 0)
        let scale = displayScale
        GeometryReader { geometry in
            if case .playback(let running) = frameMode {
                OneTapePlaybackPhotoFrame(request: .init(style: selected, phase: seconds,
                    size: geometry.size, scale: scale, running: running && !reduceMotion))
            } else {
            ZStack {
                Image(selected == .rain ? "OneTapeScreenRainPhoto" : "OneTapeScreenTrailsPhoto")
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                // The same zero-pose algorithm is used for paused/reduced
                // motion and at the animation seam, including the weak S line.
                Canvas { context, size in
                    if let image = OneTapeLivePhotoRasterizer.render(style: selected, phase: 0,
                                                                    size: size, displayScale: scale) {
                        context.draw(Image(decorative: image, scale: 1), in: CGRect(origin: .zero, size: size))
                    }
                }
                if seconds > 0 {
                    Canvas(rendersAsynchronously: true) { context, size in
                        if let image = OneTapeLivePhotoRasterizer.render(style: selected, phase: seconds,
                                                                        size: size, displayScale: scale) {
                            context.draw(Image(decorative: image, scale: 1),
                                         in: CGRect(origin: .zero, size: size))
                        }
                    }
                }
            }
            .clipped()
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
