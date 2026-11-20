import SwiftUI

/// The large disc is decoration. Only the small exposed aperture receives gestures.
struct MechanicalPaperRotor: View {
    let size: CGSize
    let radius: CGFloat
    let centerX: CGFloat
    let depth: CGFloat
    let slotWidth: CGFloat
    let digits: Int
    let angle: Double
    let reducedMotion: Bool
    let label: String
    let identifier: String
    @State private var manualOffset = 0.0
    @GestureState(resetTransaction: Transaction(animation: .interpolatingSpring(mass: 1, stiffness: 90, damping: 20)))
    private var drag = 0.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            NumberedPaperDisc(digits: digits).frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(angle + 3))
                .rotationEffect(.degrees(manualOffset + drag))
                .position(x: centerX, y: depth - radius).allowsHitTesting(false).accessibilityHidden(true)
            Color.clear.frame(width: max(44, slotWidth), height: max(44, depth))
                .contentShape(Rectangle())
                // Extra touch height extends above the card, never down across its wordmark.
                .position(x: centerX, y: depth - max(44, depth) / 2)
                .simultaneousGesture(DragGesture(minimumDistance: 4)
                    .updating($drag) { value, state, transaction in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        transaction.animation = nil
                        state = degrees(value.translation.width)
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let target = MechanicalWheelMotion.detent(from: manualOffset,
                                                                  drag: degrees(value.translation.width),
                                                                  predicted: degrees(value.predictedEndTranslation.width),
                                                                  reducedMotion: reducedMotion)
                        withAnimation(reducedMotion ? nil : .interpolatingSpring(mass: 1, stiffness: 90, damping: 20)) {
                            manualOffset = target
                        }
                    })
                .accessibilityElement(children: .ignore).accessibilityLabel(label)
                .accessibilityValue("\(Int((manualOffset / 6).rounded())) 格")
                .accessibilityHint("左右拨动纸轮")
                .accessibilityAdjustableAction { direction in
                    withAnimation(reducedMotion ? nil : .smooth(duration: 0.4)) {
                        switch direction {
                        case .increment: manualOffset += 6
                        case .decrement: manualOffset -= 6
                        @unknown default: break
                        }
                    }
                }.accessibilityIdentifier(identifier)
        }.frame(width: size.width, height: size.height)
            .transaction { if reducedMotion { $0.animation = nil } }
    }

    private func degrees(_ translation: CGFloat) -> Double {
        // At the bottom rim, horizontal points approximate arc length: theta = distance / radius.
        Double(translation / max(1, radius)) * 180 / .pi
    }
}

private struct NumberedPaperDisc: View {
    let digits: Int

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2
            context.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)),
                         with: .radialGradient(Gradient(colors: [MechanicalCardStyle.wheelCenter, MechanicalCardStyle.wheelEdge]),
                                               center: center, startRadius: radius * 0.75, endRadius: radius))
            context.stroke(Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 3, dy: 3)),
                           with: .color(.black.opacity(0.18)), lineWidth: 0.5)
            for number in 0..<60 {
                let angle = (.pi / 2) + Double(number) * .pi / 30
                var label = context
                label.translateBy(x: center.x + cos(angle) * (radius - 15),
                                  y: center.y + sin(angle) * (radius - 15))
                label.rotate(by: .radians(angle))
                label.draw(Text(String(format: digits == 2 ? "%02d" : "%03d", number))
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(MechanicalCardStyle.ink), at: .zero)
            }
        }.drawingGroup()
    }
}
