import SwiftUI

struct MechanicalCounterWindow: View {
    let value: String
    let numericValue: Double
    let caption: String
    let identifier: String
    let reducedMotion: Bool
    var accessibilityText: String? = nil
    @ScaledMetric(relativeTo: .caption) private var fontSize: CGFloat = 14

    var body: some View {
        VStack(spacing: 5) {
            MechanicalRollingNumber(value: value, numericValue: numericValue,
                                    fontSize: fontSize, reducedMotion: reducedMotion)
                .padding(.horizontal, 4).foregroundStyle(MechanicalCardStyle.ink)
                .frame(width: min(64, fontSize * 4.15), height: fontSize * 1.75)
                .background(LinearGradient(stops: [.init(color: MechanicalCardStyle.windowTop, location: 0),
                                                   .init(color: MechanicalCardStyle.windowCenter, location: 0.45),
                                                   .init(color: MechanicalCardStyle.windowTop, location: 1)],
                                           startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.black.opacity(0.5), lineWidth: 1.6))
                .overlay(RoundedRectangle(cornerRadius: 4).inset(by: 2).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
            Text(caption).font(.system(size: 8, design: .monospaced)).foregroundStyle(MechanicalCardStyle.text.opacity(0.62))
        }
        // Keep one semantic reading outside the animating glyph tree. Applying its identifier
        // to that tree would expose every visible/hidden cylinder digit as a duplicate value.
        .accessibilityRepresentation {
            Text(accessibilityText ?? value).accessibilityHint(caption).accessibilityIdentifier(identifier)
        }
    }
}

struct MechanicalRivet: View {
    var body: some View {
        Circle().fill(RadialGradient(colors: [.white.opacity(0.7), Color(hex: 0x777775), Color(hex: 0x424242)],
                                     center: .init(x: 0.3, y: 0.2), startRadius: 0, endRadius: 8))
            .frame(width: 9, height: 9).shadow(color: .black.opacity(0.7), radius: 2, y: 2)
            .padding(.bottom, 15).accessibilityHidden(true)
    }
}
