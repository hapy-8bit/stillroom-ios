import SwiftUI

struct OneTapeCustomizationTile<Thumbnail: View>: View {
    let title: String
    let selected: Bool
    let studioMarker: Bool
    let identifier: String
    let action: () -> Void
    @ViewBuilder let thumbnail: () -> Thumbnail

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                thumbnail()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(240.0 / 153.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(alignment: .topTrailing) {
                        if studioMarker {
                            Circle()
                                .fill(Color(red: 0.92, green: 0.61, blue: 0.28))
                                .frame(width: 6, height: 6)
                                .overlay { Circle().stroke(.black.opacity(0.15), lineWidth: 0.5) }
                                .padding(9.5)
                                .accessibilityHidden(true)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(selected ? .white.opacity(0.95) : .clear, lineWidth: 1.8)
                            .padding(-2.5)
                    }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(selected ? 0.95 : 0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "已选择" : "")
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

extension OneTapeCustomizationTab {
    var title: String {
        switch self {
        case .tape: "磁带"
        case .print: "印花"
        case .reel: "卷盘"
        case .body: "机身"
        case .screen: "屏幕"
        }
    }

    var panelHeightFraction: CGFloat {
        switch self {
        case .tape, .print, .reel: 1
        case .body: 0.8674
        case .screen: 0.763
        }
    }
}

extension OneTapeAppearance.TapeStyle {
    var customizationTitle: String {
        switch self {
        case .classic: "白色"
        case .graphite: "黑色"
        case .armature: "桁架"
        case .fieldNotes: "档案"
        case .silverOval: "银铝"
        case .twinArc: "双弧"
        case .strata: "岩层"
        case .facet: "折面"
        case .islands: "浮岛"
        case .ribs: "肋骨"
        case .stream: "流线"
        case .eclipse: "月蚀"
        case .clear: "透明"
        case .window: "窗口"
        case .memphis: "Memphis"
        case .bronze: "古铜"
        }
    }
}
