import SwiftUI

/// Shared ink and spacing for the private-press desk; the original player retains its own chrome.
enum CraftStyle {
    static let desk = Color(hex: 0x10121A)
    static let surface = Color(hex: 0x1B1E28)
    static let paper = Color(hex: 0xF1F0E7)
    static let ink = Color(hex: 0x20242B)
    static let secondary = Color(hex: 0xA5A7B0)
    static let line = Color.white.opacity(0.13)
    static let accent = Color(hex: 0xCBDEA3)

    static func color(_ value: SleeveColor) -> Color { Color(hex: UInt32(value.hex, radix: 16) ?? 0x2546B8) }
    static func caption(_ size: CGFloat = 10) -> Font { .system(size: size, weight: .medium, design: .monospaced) }

    static func duration(_ ids: [String], tracks: [Track]) -> String {
        guard !ids.isEmpty else { return "尚未选曲" }
        let durations = ids.compactMap { id in tracks.first(where: { $0.id == id })?.duration }
        guard durations.count == ids.count, durations.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            return "\(ids.count) 首 · 时长待读取"
        }
        return "\(ids.count) 首 · \(MediaTime.label(durations.reduce(0, +)))"
    }
}

struct CraftPrimaryButton: View {
    let title: String
    var symbol = "arrow.right"
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.body.weight(.semibold))
                Spacer(minLength: 12)
                Image(systemName: symbol).font(.system(size: 16, weight: .medium))
            }.padding(.horizontal, 20).frame(minHeight: 52)
                .foregroundStyle(CraftStyle.desk).background(enabled ? CraftStyle.paper : CraftStyle.paper.opacity(0.3), in: RoundedRectangle(cornerRadius: 13))
        }.buttonStyle(.plain).disabled(!enabled)
    }
}

struct CraftCloseButton: View {
    var label = "返回"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 15, weight: .medium))
                .frame(width: 44, height: 44).background(.white.opacity(0.07), in: Circle())
        }.buttonStyle(.plain).foregroundStyle(CraftStyle.paper).accessibilityLabel(label)
    }
}

struct CraftSidePicker: View {
    @Binding var selected: CraftedSide
    var sideA = 0
    var sideB = 0
    var body: some View {
        HStack(spacing: 4) {
            ForEach(CraftedSide.allCases) { side in
                Button { selected = side } label: {
                    HStack(spacing: 8) {
                        Text(side.label).font(.subheadline.weight(.semibold))
                        Text(String(side == .a ? sideA : sideB)).font(CraftStyle.caption(11))
                            .opacity(0.65)
                    }.frame(maxWidth: .infinity).frame(minHeight: 44)
                        .foregroundStyle(selected == side ? CraftStyle.desk : CraftStyle.secondary)
                        .background(selected == side ? CraftStyle.paper : .clear, in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).accessibilityIdentifier("craft.side." + side.rawValue)
                    .accessibilityAddTraits(selected == side ? .isSelected : [])
            }
        }.padding(4).background(CraftStyle.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}
