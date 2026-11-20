import SwiftUI

/// The image stays fixed. A rounded cutout moves down through it as the glass
/// opens; moving the image itself would incorrectly move the cassette lettering.
struct OneTapeGlassCover: View {
    let appearance: OneTapeAppearance
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var customPrint: OneTapeResolvedPrint? = nil
    var progress: CGFloat
    var supplyAngle: Angle = .zero
    var takeupAngle: Angle = .zero
    var tapeProgress: Double = 0
    var reelExposureDegrees: Double = 0

    var body: some View {
        // Keep each layer inside a fixed 353.91×553.8 container before adding the
        // 376.33×576 cassette canvas so offsets and reveal masks never drift.
        Color.clear
            .frame(width: 353.91, height: 553.8)
            .overlay(alignment: .topLeading) {
                if progress < 0.999 {
                    Color.clear
                        .frame(width: 353.91, height: 553.8)
                        .overlay(alignment: .topLeading) {
                            cassetteLayer(isFrosted: true)
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                if progress > 0.001 {
                    let clearCover = Color.clear
                        .frame(width: 353.91, height: 553.8)
                        .overlay(alignment: .topLeading) {
                            cassetteLayer(isFrosted: false)
                        }
                    if progress < 0.999 {
                        clearCover.mask(OneTapeGlassReveal(progress: progress))
                    } else {
                        clearCover
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                OneTapeBrandPrint(appearance: appearance, cassetteReadout: cassetteReadout, customPrint: customPrint)
                    .frame(width: 376.33, height: 576)
                    .offset(x: -11.22, y: -10.97)
            }
            .overlay {
                if progress > 0.001 && progress < 0.999 {
                    OneTapeGlassEdge(progress: progress)
                        .stroke(.black.opacity(0.55), lineWidth: 3)
                        .overlay {
                            OneTapeGlassEdge(progress: progress)
                                .stroke(.white.opacity(0.32), lineWidth: 1)
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 19.12))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func cassetteLayer(isFrosted: Bool) -> some View {
        OneTapeCassetteArtwork(
            appearance: appearance,
            showsPrint: false,
            isFrosted: isFrosted,
            supplyAngle: supplyAngle,
            takeupAngle: takeupAngle,
            tapeProgress: tapeProgress,
            reelExposureDegrees: reelExposureDegrees
        )
        .frame(width: 376.33, height: 576)
        .offset(x: -11.22, y: -10.97)
    }
}

private struct OneTapeGlassReveal: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let boundary = Path(roundedRect: rect, cornerRadius: 19.12)
        let cutout = Path(roundedRect: rect.offsetBy(dx: 0, dy: progress * rect.height),
                          cornerRadius: 19.12)
        return boundary.subtracting(cutout, eoFill: false)
    }
}

private struct OneTapeGlassEdge: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0.001, progress < 0.999 else { return Path() }
        let y = rect.minY + progress * rect.height
        let radius: CGFloat = 19.12
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: y + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: y),
                          control: CGPoint(x: rect.minX, y: y))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: y))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: y + radius),
                          control: CGPoint(x: rect.maxX, y: y))
        return path
    }
}
