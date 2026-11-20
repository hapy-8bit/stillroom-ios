import SwiftUI

/// A static woven surface in logical points. Deterministic strokes stay fixed while content scrolls.
struct CharcoalTexture: View, Equatable {
    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            var light = Path()
            var dark = Path()
            let rows = Int(ceil(size.height / 5.5))
            let columns = Int(ceil(size.width / 28)) + 1
            for row in 0..<rows {
                for column in 0..<columns {
                    let seed = (row * 17 + column * 29 + row * column * 3) % 101
                    let x = CGFloat(column) * 28 - (row.isMultiple(of: 2) ? 0 : 14)
                    let y = CGFloat(row) * 5.5
                    let length = CGFloat(5 + seed % 17)
                    light.move(to: CGPoint(x: x, y: y))
                    light.addLine(to: CGPoint(x: x + length, y: y))
                    dark.move(to: CGPoint(x: x + 1, y: y + 0.8))
                    dark.addLine(to: CGPoint(x: x + length + 1, y: y + 0.8))
                }
            }
            context.stroke(dark, with: .color(.black.opacity(0.16)), lineWidth: 0.6)
            context.stroke(light, with: .color(.white.opacity(0.055)),
                           style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
        }
    }
}
