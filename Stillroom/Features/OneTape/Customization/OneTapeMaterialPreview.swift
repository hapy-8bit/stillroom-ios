import SwiftUI

/// Original materials have their own native preview. The four existing
/// Cassette reference thumbnails remain unchanged beside the new choices.
struct OneTapeMaterialPreview: View {
    let material: OneTapeBodyMaterial

    private var appearance: OneTapeAppearance {
        var value = OneTapeAppearance()
        value.bodyMaterial = material
        return value
    }

    var body: some View {
        GeometryReader { geometry in
            let palette = material.palette()
            ZStack(alignment: .topLeading) {
                OneTapeBodySurface(
                    appearance: appearance,
                    tilt: CGSize(width: 0.34, height: -0.22),
                    energy: 0.62
                )
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(palette.lcd.materialColor)
                    .frame(width: 264.39, height: 165.63)
                    .offset(x: 100.33, y: 651.12)
                ForEach(Array(OneTapeTransportAction.allCases.enumerated()), id: \.offset) { index, action in
                    OneTapeTransportKeyVisual(appearance: appearance, action: action,
                        illuminated: false, quarterTurns: 0)
                        .position(x: OneTapeTransportGeometry.centerX,
                                  y: OneTapeTransportGeometry.centersY[index])
                }
            }
            .frame(width: 393, height: 852, alignment: .topLeading)
            .offset(y: -608)
            .scaleEffect(geometry.size.width / 393, anchor: .topLeading)
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
