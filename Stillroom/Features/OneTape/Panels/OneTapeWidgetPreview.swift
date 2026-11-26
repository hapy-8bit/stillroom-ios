import SwiftUI
import UIKit

/// Renders a live, device-accurate Home Screen widget preview card inside
/// Settings using the exact same view hierarchy as the WidgetKit extension.
struct OneTapeWidgetPreview: View {
    typealias Size = OneTapeWidgetSize

    let size: OneTapeWidgetSize
    var snapshot: OneTapeWidgetSnapshot = .empty
    var artwork: UIImage? = nil
    var metrics: OneTapeWidgetMetrics = OneTapeWidgetMetrics.forScreen(width: 393, height: 852)
    var onTogglePlayback: () -> Void = {}
    var onNextTrack: () -> Void = {}

    var body: some View {
        let cardSize = metrics.size(for: size)
        ZStack {
            OneTapeWidgetBackground(snapshot: snapshot)
            OneTapeWidgetCardView(
                snapshot: snapshot,
                size: size,
                artwork: artwork,
                controlsMode: .callbacks(
                    onTogglePlayback: onTogglePlayback,
                    onNextTrack: onNextTrack
                )
            )
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}

struct OneTapeTapeThumbnail: View {
    var tilt: Double = 0
    var appearance = OneTapeAppearance()
    var showsPrint = true
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var customPrint: OneTapeResolvedPrint? = nil

    var body: some View {
        GeometryReader { geometry in
            // The reference-preview layers share a portrait canvas. The
            // thumbnail intentionally turns that canvas onto its long edge.
            let portraitWidth = min(geometry.size.height, geometry.size.width / (1728.0 / 1129.0))
            OneTapeCassetteArtwork(appearance: appearance, showsPrint: showsPrint, showsFineTexture: false,
                cassetteReadout: cassetteReadout, customPrint: customPrint)
            .frame(width: 376.33, height: 576)
            .scaleEffect(portraitWidth / 376.33)
            .rotationEffect(.degrees(-90 + tilt))
            .shadow(color: .black.opacity(0.4), radius: 10, y: 8)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
