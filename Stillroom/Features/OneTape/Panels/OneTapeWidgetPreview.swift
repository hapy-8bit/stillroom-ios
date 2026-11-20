import SwiftUI

struct OneTapeWidgetPreview: View {
    enum Size: String {
        case small, medium, large
        var title: String {
            switch self {
            case .small: "小"
            case .medium: "中"
            case .large: "大"
            }
        }
        var width: CGFloat { self == .small ? 152 : 320 }
        var height: CGFloat { self == .large ? 320 : 152 }
    }

    let size: Size

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(white: 0.18), Color(white: 0.105)],
                startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(size == .small ? "A 面" : "● 已装入")
                    Spacer()
                    Text("C60")
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.top, 14)

                OneTapeTapeThumbnail(tilt: -9)
                    .padding(.horizontal, size == .small ? 6 : 18)
                    .padding(.top, size == .large ? 30 : 4)

                HStack {
                    Label("已装入", systemImage: "pause.fill")
                    Spacer()
                    Text("000").italic()
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct OneTapeTapeThumbnail: View {
    var tilt: Double = 0
    var appearance = OneTapeAppearance()
    var showsPrint = true
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var customPrint: OneTapeResolvedPrint? = nil

    var body: some View {
        GeometryReader { geometry in
            // The reference-preview layers share a portrait canvas. The
            // thumbnail intentionally turns that canvas onto its long edge.
            let portraitWidth = min(geometry.size.height, geometry.size.width / (1728.0 / 1129.0))
            OneTapeCassetteArtwork(appearance: appearance, showsPrint: showsPrint, showsFineTexture: false,
                cassetteReadout: cassetteReadout, customPrint: customPrint)
            .frame(width: 376.33, height: 576)
            .scaleEffect(portraitWidth / 376.33)
            .rotationEffect(.degrees(-90 + tilt))
            .shadow(color: .black.opacity(0.4), radius: 10, y: 8)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
