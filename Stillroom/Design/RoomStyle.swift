import SwiftUI

enum RoomStyle {
    static let background = Color(hex: 0x252525)
    static let surface = Color(hex: 0x2D2C2B)
    static let paper = Color(hex: 0xEDE4CE)
    static let secondary = Color(hex: 0xB4AEA5)
    static let muted = Color(hex: 0x8C8780)
    static let accent = Color(hex: 0xE2D6BC)
    static let copper = Color(hex: 0xC59A75)
    static let dock = Color(hex: 0x323130)

    static func serif(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func caption(_ size: CGFloat = 10) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct RoomBackground: View {
    var body: some View {
        ZStack {
            RoomStyle.background
            CharcoalTexture().equatable()
            LinearGradient(colors: [.white.opacity(0.015), .clear, .black.opacity(0.14)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

struct RoundControl: View {
    let symbol: String
    let label: String
    var size: CGFloat = 44
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size * 0.34, weight: .medium))
                .foregroundStyle(filled ? RoomStyle.background : RoomStyle.paper)
                .frame(width: size, height: size)
                .background(filled ? RoomStyle.paper : .white.opacity(0.055), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct SectionEyebrow: View {
    let text: String
    var body: some View {
        Text(text).font(RoomStyle.caption()).tracking(2.2).foregroundStyle(RoomStyle.secondary)
    }
}

