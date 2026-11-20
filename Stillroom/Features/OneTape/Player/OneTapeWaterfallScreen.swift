import SwiftUI

/// Frequency history contains measured audio only. Decorative animation cannot
/// create spectral energy, and unsupported audio clears the recorded rows.
struct OneTapeWaterfallScreen: View {
    let response: OneTapeScreenResponse

    var body: some View {
        Canvas { context, size in
            OneTapeScreenArt.background(context, size: size,
                                        top: Color(red: 0.055, green: 0.10, blue: 0.105),
                                        bottom: Color(red: 0.015, green: 0.035, blue: 0.045))
            let columns = 16
            let cellWidth = (size.width - 20) / Double(columns)
            let cellHeight = (size.height - 22) / 72
            for (row, bands) in response.spectrumHistory.enumerated() {
                for column in 0..<min(columns, bands.count) {
                    let value = pow(min(1, max(0, bands[column])), 2.1)
                    guard value > 0.005 else { continue }
                    let rect = CGRect(x: 10 + Double(column) * cellWidth,
                                      y: 12 + Double(row) * cellHeight,
                                      width: cellWidth + 0.15, height: cellHeight + 0.15)
                    context.fill(Path(rect), with: .color(color(value).opacity(0.25 + value * 0.75)))
                }
            }
            var grid = Path()
            for column in 0...columns {
                let x = 10 + Double(column) * cellWidth
                grid.move(to: CGPoint(x: x, y: 9))
                grid.addLine(to: CGPoint(x: x, y: size.height - 9))
            }
            for row in 0..<9 {
                let y = 12 + Double(row) / 8 * (size.height - 24)
                grid.move(to: CGPoint(x: 8, y: y))
                grid.addLine(to: CGPoint(x: size.width - 8, y: y))
            }
            context.stroke(grid, with: .color(.black.opacity(0.22)), lineWidth: 0.5)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(stops: [.init(color: .clear, location: 0.35),
                                 .init(color: OneTapeScreenArt.charcoal.opacity(0.74), location: 1)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            for column in 0..<min(columns, response.bands.count) {
                let value = response.bands[column]
                let rect = CGRect(x: 10 + Double(column) * cellWidth, y: 7,
                                  width: max(1, cellWidth - 1), height: 1.6)
                context.fill(Path(rect), with: .color(color(value).opacity(value)))
            }
            OneTapeScreenArt.finish(context, size: size, grain: 140)
        }
    }

    private func color(_ value: Double) -> Color {
        if value > 0.76 {
            let warm = min(1, (value - 0.76) / 0.24)
            return Color(red: 0.74 + warm * 0.18, green: 0.78 - warm * 0.24, blue: 0.73 - warm * 0.39)
        }
        let t = value / 0.76
        return Color(red: 0.11 + t * 0.63, green: 0.31 + t * 0.47, blue: 0.34 + t * 0.39)
    }
}
