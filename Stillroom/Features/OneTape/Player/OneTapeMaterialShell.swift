import SwiftUI

/// Unified 393×852 logical-point body material pipeline.
/// Layer 1: GPU Metal / precision industrial material surface.
/// Layer 2: Shared 3D iPhone chassis molding overlay (`OneTapeBodyMoldOverlay`).
/// The caller masks out the cassette pocket and LCD viewport cleanly.
struct OneTapeMaterialShell: View {
    let material: OneTapeBodyMaterial
    var color: OneTapeAppearance.BodyColor = .black
    var tilt: CGSize = OneTapeTiltMonitor.restingTilt
    var energy: Double = 0
    var animatePulse: Bool = false

    var body: some View {
        ZStack {
            surfaceLayer
            OneTapeBodyMoldOverlay(
                isDarkShell: material.isDarkShell,
                tilt: tilt
            )
        }
        .frame(width: 393, height: 852)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var surfaceLayer: some View {
        switch material {
        case .holoFoil, .silverFoil, .circuitGlow, .disco, .seeThrough:
            OneTapeFoilAndOpticBodyRenderer.view(
                for: material,
                tilt: tilt,
                energy: energy,
                animatePulse: animatePulse
            )
        case .greyTracks, .cleanPlates, .camoStealth, .camoDigital, .linen, .stickerBomb:
            OneTapeTactileBodyRenderer.view(
                for: material,
                tilt: tilt
            )
        case .frostedGlass, .smokedGlass, .brushedAluminum, .darkTitanium:
            material.palette(color: color).shell.materialColor
                .frame(width: 393, height: 852)
        }
    }
}

extension OneTapeTransportMaterial.RGB {
    var materialColor: Color { Color(red: red, green: green, blue: blue) }
}
