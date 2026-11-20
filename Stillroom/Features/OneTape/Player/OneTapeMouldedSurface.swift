import SwiftUI

/// Approved sculptural molding is a text-free fixed photograph. Its small
/// drive cores are composited separately, using the existing player phase.
struct OneTapeMouldedSurface: View, Equatable {
    let style: OneTapeAppearance.TapeStyle
    var showsFineTexture = true
    private var geometry: OneTapeMouldGeometry { OneTapeMouldGeometry(style: style) }

    var body: some View {
        Image(geometry.asset + (showsFineTexture ? "" : "Preview"))
            .resizable()
            .interpolation(.high)
            .frame(width: geometry.photoFrame.width, height: geometry.photoFrame.height)
            .position(x: geometry.photoFrame.midX, y: geometry.photoFrame.midY)
            .frame(width: OneTapeMouldGeometry.size.width, height: OneTapeMouldGeometry.size.height)
            .mask { geometry.outline.fill(.white) }
            .transaction { $0.animation = nil }
    }
}
