import SwiftUI

/// Independent digit drums keep punctuation still and carry through 9/5 -> 0 without a dissolve.
struct MechanicalRollingNumber: View {
    let value: String
    let numericValue: Double
    let fontSize: CGFloat
    let reducedMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            let characters = Array(value.reversed())
            let size = min(fontSize, max(6, geometry.size.width / (CGFloat(characters.count) * 0.62)))
            HStack(spacing: 0) {
                ForEach(characters.indices.reversed(), id: \.self) { index in
                    if let digit = characters[index].wholeNumberValue {
                        MechanicalDigitDrum(digit: digit, numericValue: numericValue,
                                            radix: value.contains(":") && index == 1 ? 6 : 10,
                                            fontSize: size, reducedMotion: reducedMotion)
                    } else {
                        Text(String(characters[index])).font(.system(size: size, design: .monospaced))
                            .frame(width: size * 0.62, height: geometry.size.height)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct MechanicalDigitDrum: View {
    let digit: Int
    let numericValue: Double
    let radix: Int
    let fontSize: CGFloat
    let reducedMotion: Bool
    @State private var phase: Double

    init(digit: Int, numericValue: Double, radix: Int, fontSize: CGFloat, reducedMotion: Bool) {
        self.digit = digit
        self.numericValue = numericValue
        self.radix = radix
        self.fontSize = fontSize
        self.reducedMotion = reducedMotion
        _phase = State(initialValue: Double(digit))
    }

    var body: some View {
        DigitCylinder(phase: reducedMotion ? Double(digit) : phase, radix: radix, fontSize: fontSize)
            .frame(width: fontSize * 0.62)
            .onChange(of: numericValue) { previous, next in
                let target = MechanicalDigitMotion.target(from: phase, digit: digit, radix: radix,
                                                         increasing: next >= previous, jump: abs(next - previous) > 1.1)
                withAnimation(reducedMotion ? nil : .timingCurve(0.18, 0.72, 0.22, 1, duration: 0.48)) {
                    phase = target
                }
            }
    }
}

private struct DigitCylinder: View, Animatable {
    var phase: Double
    let radix: Int
    let fontSize: CGFloat
    var animatableData: Double { get { phase } set { phase = newValue } }

    var body: some View {
        GeometryReader { geometry in
            let base = Int(floor(phase))
            ZStack {
                ForEach(-1...2, id: \.self) { step in
                    let distance = Double(base + step) - phase
                    let digit = ((base + step) % radix + radix) % radix
                    Text(String(digit)).font(.system(size: fontSize, weight: .regular, design: .monospaced))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        // Each glyph passes around a cylinder, compressing toward the window's lip.
                        .rotation3DEffect(.degrees(-distance * 62), axis: (x: 1, y: 0, z: 0), perspective: 0.2)
                        .opacity(max(0, 1 - abs(distance) * 0.72))
                        .offset(y: distance * geometry.size.height)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .accessibilityHidden(true)
    }
}
