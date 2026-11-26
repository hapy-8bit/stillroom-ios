import SwiftUI

struct OneTapeScreenCanvas: View {
    let style: OneTapeAppearance.ScreenStyle
    var response: OneTapeScreenResponse = .silent
    var phase = 0.0

    var body: some View {
        Group {
            switch style {
            case .fluid, .dunes, .iron:
                OneTapePhotographicMaterial(style: style, phase: phase)
            case .water:
                OneTapeMaterialScreens(style: style, phase: phase, response: response)
            case .ink, .rain, .trails:
                OneTapeAtmosphereScreens(style: style, phase: phase, response: response)
            case .waterfall:
                OneTapeWaterfallScreen(response: response)
            case .oscilloscope, .meters, .sand:
                Canvas { context, size in
                    switch style {
                    case .oscilloscope: scope(context, size: size)
                    case .meters: meters(context, size: size)
                    default: sand(context, size: size)
                    }
                    OneTapeScreenArt.finish(context, size: size)
                }
            default: Color.clear
            }
        }
    }

    private func scope(_ context: GraphicsContext, size: CGSize) {
        OneTapeScreenArt.background(context, size: size)
        var grid = Path()
        for column in 1..<10 {
            let x = Double(column) / 10 * size.width
            grid.move(to: CGPoint(x: x, y: 10))
            grid.addLine(to: CGPoint(x: x, y: size.height - 10))
        }
        for row in 1..<6 {
            let y = Double(row) / 6 * size.height
            grid.move(to: CGPoint(x: 10, y: y))
            grid.addLine(to: CGPoint(x: size.width - 10, y: y))
        }
        context.stroke(grid, with: .color(OneTapeScreenArt.silver.opacity(0.055)), lineWidth: 0.5)
        let samples = response.waveform
        let count = max(2, samples.count)
        let points = (0..<count).map { index in
            CGPoint(x: 10 + Double(index) / Double(count - 1) * (size.width - 20),
                    y: size.height / 2 - (index < samples.count ? samples[index] : 0) * size.height * 0.43)
        }
        OneTapeScreenArt.glow(OneTapeScreenArt.line(points), context: context,
                             color: OneTapeScreenArt.silver, width: 0.95, radius: 2.2)
    }

    private func meters(_ context: GraphicsContext, size: CGSize) {
        OneTapeScreenArt.background(context, size: size)
        let stride = (size.width - 24) / 16
        let pitchY = min(5, (size.height - 24) / 32)
        for column in 0..<16 {
            let measured = column < response.bands.count ? response.bands[column] : 0
            let held = column < response.heldPeaks.count ? response.heldPeaks[column] : 0
            let level = Int(measured * 32)
            let peak = min(31, max(0, Int(held * 32) - 1))
            for row in 0..<32 {
                let lit = row < level
                let isPeak = held > 0 && row == peak
                let color = row > 25 ? OneTapeScreenArt.copper : OneTapeScreenArt.silver
                let alpha = isPeak ? 0.85 : (lit ? 0.4 + Double(row) / 64 : 0.035)
                let rect = CGRect(x: 12 + Double(column) * stride,
                                  y: size.height - 12 - Double(row + 1) * pitchY,
                                  width: max(2, stride - 3), height: pitchY * 0.62)
                context.fill(Path(roundedRect: rect, cornerRadius: 0.35), with: .color(color.opacity(alpha)))
            }
        }
    }

    private func sand(_ context: GraphicsContext, size: CGSize) {
        OneTapeScreenArt.background(context, size: size,
                                    top: Color(red: 0.12, green: 0.125, blue: 0.115),
                                    bottom: OneTapeScreenArt.charcoal)
        let pattern = Int(response.motionTime / 12) % 3
        let n = Double([2, 3, 4][pattern])
        let m = Double([3, 5, 3][pattern])
        let kick = min(1, response.transient * 2)
        for index in 0..<2500 {
            let seed = Double(index)
            var x = OneTapeScreenArt.noise(seed * 7.71) * 2 - 1
            var y = OneTapeScreenArt.noise(seed * 13.37 + 7) * 2 - 1
            for _ in 0..<4 {
                let a = .pi * x
                let b = .pi * y
                let value = cos(n * a) * cos(m * b) - cos(m * a) * cos(n * b)
                let dx = -.pi * n * sin(n * a) * cos(m * b) + .pi * m * sin(m * a) * cos(n * b)
                let dy = -.pi * m * cos(n * a) * sin(m * b) + .pi * n * cos(m * a) * sin(n * b)
                let norm = dx * dx + dy * dy + 0.03
                x -= value * dx / norm * 0.7
                y -= value * dy / norm * 0.7
            }
            let jitter = (OneTapeScreenArt.noise(seed * 2.43 + response.motionTime * 0.02) - 0.5) * (1.4 + kick * 9)
            let point = CGPoint(x: (min(1, max(-1, x)) + 1) * (size.width - 20) / 2 + 10 + jitter,
                                y: (min(1, max(-1, y)) + 1) * (size.height - 20) / 2 + 10 - jitter)
            let radius = 0.35 + OneTapeScreenArt.noise(seed) * 0.25
            let color = index % 9 == 0 ? OneTapeScreenArt.copper : OneTapeScreenArt.silver
            context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: radius * 2, height: radius * 2)),
                         with: .color(color.opacity(0.4 + OneTapeScreenArt.noise(seed * 3.1) * 0.5)))
        }
    }
}
