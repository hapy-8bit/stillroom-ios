import SwiftUI

/// Lower-deck hardware preview matching Cassette's 240:153 body thumbnail framing
/// (cassette pocket lower bevel + bridge + 3 transport keys + recessed LCD viewport).
/// Uses offscreen cached GPU snapshots from `OneTapeBodyMetalEngine` so scrolling
/// the customization grid remains 120fps without spawning multiple live Metal layers.
struct OneTapeMaterialPreview: View {
    let appearance: OneTapeAppearance
    var tilt: CGSize = CGSize(width: 0.30, height: -0.20)
    var energy: Double = 0.68
    var pulsePhase: Double = 0.35

    init(material: OneTapeBodyMaterial) {
        var value = OneTapeAppearance()
        value.bodyMaterial = material
        self.appearance = value
    }

    init(bodyStyle: OneTapeAppearance.BodyStyle) {
        var value = OneTapeAppearance()
        value.bodyStyle = bodyStyle
        self.appearance = value
    }

    private var gpuSnapshot: UIImage? {
        if let material = appearance.bodyMaterial {
            switch material {
            case .holoFoil, .silverFoil, .disco, .circuitGlow, .seeThrough:
                return OneTapeFoilAndOpticBodyRenderer.previewSnapshot(
                    for: material, tilt: tilt, energy: energy, pulsePhase: pulsePhase
                )
            case .greyTracks, .cleanPlates, .camoStealth, .camoDigital, .linen, .stickerBomb:
                return OneTapeTactileBodyRenderer.previewSnapshot(
                    for: material, tilt: tilt
                )
            default:
                return nil
            }
        }
        if appearance.bodyStyle == .graphite && appearance.bodyColor == .black {
            let uniforms = OneTapeBodyUniforms(
                designSize: SIMD2(393, 852),
                uvOffset: SIMD2(0, 608.0 / 852.0),
                uvScale: SIMD2(1, 244.0 / 852.0),
                tilt: SIMD2(Float(tilt.width), Float(tilt.height)),
                phase: 0,
                energy: 0,
                grain: 0.014
            )
            return OneTapeBodyMetalEngine.shared.cachedSnapshot(
                key: "preview.graphite",
                program: .graphite,
                pixelSize: CGSize(width: 393 * 2, height: 244 * 2),
                uniforms: uniforms
            )
        }
        return nil
    }

    private var isDarkShell: Bool {
        if let material = appearance.bodyMaterial {
            return material.isDarkShell
        }
        return appearance.bodyStyle == .black
    }

    var body: some View {
        GeometryReader { geometry in
            let lcd = OneTapeLCDMaterial(appearance: appearance)
            ZStack(alignment: .topLeading) {
                if let image = gpuSnapshot {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 393, height: 244)
                        .offset(y: 608)
                } else {
                    OneTapeBodyFinish(appearance: appearance).backdrop
                        .frame(width: 393, height: 852)
                }

                OneTapeBodyMoldOverlay(isDarkShell: isDarkShell, tilt: tilt)

                // Dark cassette pocket floor peeking above the lower bridge bevel.
                RoundedRectangle(cornerRadius: 19.12, style: .continuous)
                    .fill(Color(white: 0.08))
                    .frame(width: OneTapeCassettePocketMask.openingFrame.width,
                           height: OneTapeCassettePocketMask.openingFrame.height)
                    .offset(x: OneTapeCassettePocketMask.openingFrame.minX,
                            y: OneTapeCassettePocketMask.openingFrame.minY)

                // Coordinated recessed LCD viewport.
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(lcd.background.materialColor)
                    .frame(width: 264.39, height: 165.63)
                    .offset(x: 100.33, y: 651.12)

                ForEach(Array(OneTapeTransportAction.allCases.enumerated()), id: \.offset) { index, action in
                    OneTapeTransportKeyVisual(
                        appearance: appearance,
                        action: action,
                        illuminated: action == .play && appearance.bodyStyle == .graphite && appearance.bodyMaterial == nil,
                        quarterTurns: 0
                    )
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
