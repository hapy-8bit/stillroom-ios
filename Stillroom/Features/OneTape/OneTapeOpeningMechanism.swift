import SwiftUI

/// Horizontal jewel-case coordinates are logical points. Both halves share
/// one closed footprint; the paper insert completely hides the tape at rest.
struct OneTapeOpeningCase: View {
    let lid: Bool
    var opening: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: lid
                    ? [Color(white: 0.75), Color(white: 0.25), Color(white: 0.55)]
                    : [Color(white: 0.11), Color(white: 0.035), Color(white: 0.15)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            if lid { paperInsert.padding(10) }
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.12),
                    .white.opacity(0.38), .black.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1).padding(5)
            if lid {
                LinearGradient(stops: [.init(color: .clear, location: 0.13),
                    .init(color: .white.opacity(0.24), location: 0.32),
                    .init(color: .clear, location: 0.48)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Capsule().fill(.white.opacity(0.4)).frame(width: 46, height: 3)
                    .offset(y: 190)
            } else {
                ForEach([CGFloat(-238), 238], id: \.self) { x in
                    Capsule().fill(.white.opacity(0.22)).frame(width: 32, height: 7)
                        .offset(x: x, y: -191)
                }
            }
        }
        .frame(width: 598, height: 392)
        .shadow(color: .black.opacity(lid ? 0.2 : 0.7), radius: lid ? 3 : 28, x: 2, y: 20)
        .rotation3DEffect(.degrees(lid ? 112 * opening : 0), axis: (x: 1, y: 0, z: 0),
                          anchor: .top, perspective: 0.4)
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private var paperInsert: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.83, green: 0.87, blue: 0.84)
            VStack(alignment: .leading) {
                Spacer()
                Text("One Cassette")
                    .font(.custom("InstrumentSerif-Italic", size: 108))
                    .tracking(-3).foregroundStyle(Color(red: 0.74, green: 0.25, blue: 0.16))
                Spacer()
                Text("A").font(.custom("InstrumentSerif-Regular", size: 26))
                    .foregroundStyle(.black.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32).padding(.vertical, 26)
            Rectangle().fill(.black.opacity(0.08)).frame(width: 17)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

/// Drawn below the real player cassette; its lid lives in the overlay above it.
struct OneTapeOpeningBackdrop: View {
    @ObservedObject var opening: OneTapeOpeningStore
    let reducedMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            let layout = OneTapeOpeningLayout(size: geometry.size)
            ZStack {
                Color(red: 0.048, green: 0.047, blue: 0.044)
                    .overlay {
                        RadialGradient(colors: [Color(red: 0.86, green: 0.53, blue: 0.32).opacity(0.08), .clear],
                            center: UnitPoint(x: 0.5, y: 0.46), startRadius: 0,
                            endRadius: max(geometry.size.width, geometry.size.height) * 0.5)
                    }
                    .opacity(1 - opening.homeReveal)
                OneTapeOpeningCase(lid: false)
                    .rotation3DEffect(.degrees(reducedMotion ? 0 : 7), axis: (x: 1, y: 0, z: 0))
                    .scaleEffect(layout.caseScale * (reducedMotion ? 1 : 1 - 0.10 * opening.extraction))
                    .position(x: layout.looseCenter.x,
                              y: layout.looseCenter.y + (reducedMotion ? 0 : 24 * opening.extraction))
                    .opacity(opening.caseOpacity)
            }
        }
        .ignoresSafeArea(.container)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
