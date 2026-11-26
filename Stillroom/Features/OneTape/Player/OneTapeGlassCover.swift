import SwiftUI

/// The cassette artwork stays fixed. A rounded cutout slides vertically through
/// it as the glass opens or closes; moving the artwork itself would shift the
/// cassette lettering. Keeping one stable structural mask during transitions
/// ensures SwiftUI interpolates `animatableData` smoothly on spring rebound.
struct OneTapeGlassCover: View {
    let appearance: OneTapeAppearance
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var customPrint: OneTapeResolvedPrint? = nil
    var tiltMonitor: OneTapeTiltMonitor? = nil
    var progress: CGFloat
    var isTransitioning: Bool = false
    var supplyAngle: Angle = .zero
    var takeupAngle: Angle = .zero
    var tapeProgress: Double = 0
    var reelExposureDegrees: Double = 0

    private var showsFrostedLayer: Bool {
        isTransitioning || progress < 0.999
    }

    private var showsClearLayer: Bool {
        isTransitioning || progress > 0.001
    }

    var body: some View {
        // Keep each layer inside a fixed 353.91×553.8 container before adding the
        // 376.33×576 cassette canvas so offsets and reveal masks never drift.
        Color.clear
            .frame(width: 353.91, height: 553.8)
            .overlay(alignment: .topLeading) {
                if showsFrostedLayer {
                    Color.clear
                        .frame(width: 353.91, height: 553.8)
                        .overlay(alignment: .topLeading) {
                            cassetteLayer(isFrosted: true)
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                if showsClearLayer {
                    Color.clear
                        .frame(width: 353.91, height: 553.8)
                        .overlay(alignment: .topLeading) {
                            cassetteLayer(isFrosted: false)
                        }
                        // Always keep the same mask shape identity while visible so
                        // spring-back animations never switch branches mid-flight.
                        .mask(OneTapeGlassReveal(progress: progress))
                }
            }
            .overlay(alignment: .topLeading) {
                if showsFrostedLayer {
                    OneTapeGlassPaneSheen(progress: progress)
                }
            }
            .overlay(alignment: .topLeading) {
                Group {
                    if let tiltMonitor, appearance.tapeFoilStyle != nil {
                        OneTapeLiveBrandPrint(
                            appearance: appearance,
                            cassetteReadout: cassetteReadout,
                            customPrint: customPrint,
                            tiltMonitor: tiltMonitor
                        )
                    } else {
                        OneTapeBrandPrint(
                            appearance: appearance,
                            cassetteReadout: cassetteReadout,
                            customPrint: customPrint
                        )
                    }
                }
                .frame(width: 376.33, height: 576)
                .offset(x: -11.22, y: -10.97)
            }
            .overlay {
                if isTransitioning || (progress > 0.001 && progress < 0.999) {
                    OneTapeGlassEdgeOverlay(progress: progress)
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
        let clamped = min(1, max(0, progress))
        if clamped >= 0.9995 {
            return Path(roundedRect: rect, cornerRadius: 19.12)
        }
        if clamped <= 0.0005 {
            return Path()
        }
        let boundary = Path(roundedRect: rect, cornerRadius: 19.12)
        let cutout = Path(roundedRect: rect.offsetBy(dx: 0, dy: clamped * rect.height),
                          cornerRadius: 19.12)
        return boundary.subtracting(cutout, eoFill: false)
    }
}

/// Subtle translucent specular sheen on the moving glass sheet itself so the
/// glass cover reads clearly as a physical sliding pane on every cassette shell.
private struct OneTapeGlassPaneSheen: View, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let clamped = min(1, max(0, progress))
            let coverage = 1 - clamped
            guard coverage > 0.001 else { return }
            let y = clamped * size.height
            let paneRect = CGRect(x: 0, y: y, width: size.width, height: size.height - y + 20)
            let pane = Path(roundedRect: paneRect, cornerRadius: 19.12)

            // Soft diagonal glass glare moving with the pane.
            context.fill(
                pane,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(0.11 * coverage), location: 0.00),
                        .init(color: .white.opacity(0.03 * coverage), location: 0.16),
                        .init(color: .clear, location: 0.55),
                        .init(color: .white.opacity(0.04 * coverage), location: 1.00)
                    ]),
                    startPoint: CGPoint(x: 0, y: y),
                    endPoint: CGPoint(x: size.width * 0.45, y: size.height)
                )
            )
        }
        .allowsHitTesting(false)
    }
}

/// Animatable moving top rim of the sliding glass pane. Smoothly fades at the
/// top and bottom pocket boundaries instead of popping out on release.
private struct OneTapeGlassEdgeOverlay: View, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let clamped = min(1, max(0, progress))
        let edgeFade = min(1, clamped / 0.025) * min(1, (1 - clamped) / 0.025)
        ZStack {
            OneTapeGlassEdge(progress: clamped)
                .stroke(.black.opacity(0.55 * edgeFade), lineWidth: 3)
            OneTapeGlassEdge(progress: clamped)
                .stroke(.white.opacity(0.36 * edgeFade), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct OneTapeGlassEdge: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(1, max(0, progress))
        guard clamped > 0.001, clamped < 0.999 else { return Path() }
        let y = rect.minY + clamped * rect.height
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
