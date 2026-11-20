import SwiftUI

struct OneTapeCustomizationChip: View {
    let title: String
    let selected: Bool
    let studioMarker: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14))
                if studioMarker {
                    Circle()
                        .fill(Color(red: 0.86, green: 0.52, blue: 0.25))
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.white.opacity(selected ? 0.95 : 0.65))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(.white.opacity(selected ? 0.14 : 0.065), in: Capsule())
            .overlay { Capsule().stroke(selected ? .white.opacity(0.65) : .clear, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "已选择" : "")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Native-size chips wrap using the current panel width instead of an assumed
/// phone's pixel coordinates. The same arrangement is used to measure/place.
struct OneTapeChipFlow: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let arrangement = arrange(width: proposal.width ?? .greatestFiniteMagnitude, subviews: subviews)
        return CGSize(width: proposal.width ?? arrangement.size.width, height: arrangement.size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(width: bounds.width, subviews: subviews)
        for (index, point) in arrangement.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widestRow: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            widestRow = max(widestRow, x + size.width)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: widestRow, height: y + rowHeight), origins)
    }
}
