import SwiftUI

/// Pure pickup drawing in 120×440 source points. The fixed pivot (70,50) and
/// opening scene's rotation anchor are stable. The parked tube sits right of that axis;
/// its headshell center is (85,391), following the supplied offset-carrier silhouette.
/// Only the carrier/tube/head rotate; the soft plinth footprint stays on the deck.
struct OrbitPickupArm: View {
    let fraction: Double?
    let raised: Bool
    let reducedMotion: Bool
    var previewAngle: Double? = nil
    var appearance: OrbitArmAppearance = .studioSilver
    var light: OrbitArmLight = .off

    private var angle: Double {
        if let previewAngle, previewAngle.isFinite { return previewAngle }
        return raised ? 0 : 11 + min(1, max(0, fraction ?? 0)) * 15
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 120
            ZStack(alignment: .topLeading) {
                mountingFootprint(scale: scale)
                assembly(scale: scale)
                    .rotationEffect(.degrees(angle), anchor: UnitPoint(x: 70 / 120, y: 50 / 440))
                    .animation(reducedMotion || previewAngle != nil ? nil :
                        .easeInOut(duration: raised ? 0.2 : 0.38), value: angle)
            }.frame(width: 120 * scale, height: 440 * scale)
        }.allowsHitTesting(false).accessibilityHidden(true)
    }

    private func mountingFootprint(scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 45 * scale)
            .fill(Color(white: 0.56).opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 45 * scale)
                .strokeBorder(.white.opacity(0.055), lineWidth: 1 * scale))
            .background {
                RoundedRectangle(cornerRadius: 45 * scale)
                    .fill(.black.opacity(0.09)).blur(radius: 2 * scale)
                    .offset(x: 1 * scale, y: 2 * scale)
            }
            .frame(width: 94 * scale, height: 154 * scale)
            .position(x: 70 * scale, y: 79 * scale)
    }

    private func assembly(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // A straight cylinder and broad black carrier follow the supplied normal-player
            // silhouette. This avoids the former oversized graduated flange.
            RoundedRectangle(cornerRadius: 2.8 * scale)
                .fill(appearance.cylindrical)
                .frame(width: 12.5 * scale, height: 279 * scale)
                .position(x: 90 * scale, y: 213.5 * scale)
                .shadow(color: .black.opacity(0.28), radius: 2 * scale, x: 3 * scale, y: 2 * scale)
            RoundedRectangle(cornerRadius: 1 * scale)
                .fill(Color(white: 0.095))
                .frame(width: 15 * scale, height: 26 * scale)
                .position(x: 90 * scale, y: 86 * scale)
            RoundedRectangle(cornerRadius: 1.2 * scale)
                .fill(LinearGradient(colors: [Color(white: 0.14), Color(white: 0.085)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 34 * scale, height: 14 * scale)
                .position(x: 59 * scale, y: 28 * scale)
            RoundedRectangle(cornerRadius: 2.5 * scale)
                .fill(LinearGradient(colors: [Color(white: 0.13), Color(white: 0.095), Color(white: 0.075)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 2.5 * scale)
                    .strokeBorder(.white.opacity(0.045), lineWidth: 0.6 * scale))
                .frame(width: 60 * scale, height: 40 * scale)
                .position(x: 70 * scale, y: 54 * scale)
                .shadow(color: .black.opacity(0.34), radius: 3 * scale, x: 2 * scale, y: 3 * scale)
            RoundedRectangle(cornerRadius: 1 * scale).fill(.white.opacity(0.07))
                .frame(width: 39 * scale, height: 1.6 * scale)
                .position(x: 59 * scale, y: 43 * scale)
            RoundedRectangle(cornerRadius: 2.5 * scale).fill(Color(white: 0.09))
                .frame(width: 21 * scale, height: 40 * scale)
                .position(x: 89.5 * scale, y: 54 * scale)
            RoundedRectangle(cornerRadius: 2 * scale)
                .fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.075)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 13 * scale, height: 31 * scale)
                .position(x: 90 * scale, y: 360 * scale)
            RoundedRectangle(cornerRadius: 2 * scale)
                .fill(LinearGradient(colors: [Color(white: 0.17), Color(white: 0.09)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 19 * scale, height: 32 * scale)
                .position(x: 90 * scale, y: 372 * scale)
            headshell(scale: scale)
                .rotationEffect(.degrees(32)).position(x: 85 * scale, y: 391 * scale)
        }.frame(width: 120 * scale, height: 440 * scale)
    }

    private func headshell(scale: CGFloat) -> some View {
        ZStack(alignment: .center) {
            if light != .off {
                // The four-state function is recovered; this local soft footprint is a
                // drawing approximation in source points, attached to the stylus assembly.
                Circle().fill(RadialGradient(colors: [OrbitInk.color(light.hex).opacity(0.82),
                    OrbitInk.color(light.hex).opacity(0.28), .clear], center: .center,
                    startRadius: 0, endRadius: 27 * scale))
                    .frame(width: 54 * scale, height: 54 * scale).offset(y: 31 * scale)
                    .blur(radius: 3 * scale).blendMode(.screen)
            }
            RoundedRectangle(cornerRadius: 3 * scale)
                .fill(LinearGradient(colors: [Color(white: 0.14), Color(white: 0.10)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28 * scale, height: 61 * scale)
            Capsule().fill(Color(white: 0.14))
                .frame(width: 22 * scale, height: 4 * scale)
                .offset(x: 12 * scale, y: 23 * scale)
            Rectangle().fill(Color(white: 0.32))
                .frame(width: 1 * scale, height: 3 * scale)
                .offset(y: 31 * scale)
            if light != .off {
                Circle().fill(OrbitInk.color(light.hex)).frame(width: 3 * scale, height: 3 * scale)
                    .offset(y: 32 * scale)
            }
        }.frame(width: 34 * scale, height: 66 * scale)
            .shadow(color: .black.opacity(0.22), radius: 1.5 * scale, x: 1 * scale, y: 2 * scale)
    }
}
