import SwiftUI

/// A second projection of the same collections. Scroll restoration targets a
/// centered two-cover row, so choosing either column cannot shift the viewport.
struct OneTapeGridView: View {
    let collections: [MusicCollection]
    let artworks: [String: UIImage]
    let selectedID: String?
    @Binding var scrollID: String?
    let onSelect: (MusicCollection, CGRect, CGFloat) -> Void
    let onLoadArtwork: (MusicCollection) -> Void
    var onBrowse: (OneTapeLibraryBrowseEvent) -> Void = { _ in }
    var isReloadReady = true
    var isActive = true
    @State private var isBrowsing = false

    var body: some View {
        GeometryReader { viewport in
            let width = max(0, viewport.size.width)
            let inset = min(max(24, width * 0.10), width / 2)
            let contentWidth = max(0, width - inset * 2)
            let spacing = min(26, contentWidth)
            let columnWidth = (contentWidth - spacing) / 2
            let coverWidth = min(columnWidth, width * 0.29, 180)
            let anchorIndex = collections.firstIndex { $0.id == scrollID } ?? 0
            ScrollView(.vertical) {
                LazyVStack(spacing: 28) {
                    ForEach(rows) { row in
                        HStack(alignment: .top, spacing: spacing) {
                            tile(row.first, index: row.index, columnWidth: columnWidth, coverWidth: coverWidth)
                            if let second = row.second {
                                tile(second, index: row.index + 1,
                                     columnWidth: columnWidth, coverWidth: coverWidth)
                            } else {
                                Color.clear.frame(width: columnWidth, height: 1)
                                    .accessibilityHidden(true).allowsHitTesting(false)
                            }
                        }
                        .frame(width: contentWidth, alignment: .center)
                        .modifier(OneTapeLibraryReloadReveal(ready: isReloadReady,
                            order: min(abs(row.index / 2 - anchorIndex / 2), 4)))
                        .id(row.id)
                    }
                }
                .scrollTargetLayout()
                .frame(width: contentWidth, alignment: .center)
                .padding(.horizontal, inset)
                .padding(.top, 82)
                .padding(.bottom, 130)
                .frame(width: width, alignment: .center)
            }
            .frame(width: width, height: max(0, viewport.size.height), alignment: .top)
            .scrollPosition(id: rowScrollID, anchor: .top)
            .onScrollPhaseChange { _, phase in
                guard isActive else { isBrowsing = false; onBrowse(.ended); return }
                if phase == .interacting, !isBrowsing {
                    isBrowsing = true
                    onBrowse(.began(currentID: scrollID))
                } else if phase == .idle || phase == .animating {
                    isBrowsing = false
                    onBrowse(.ended)
                }
            }
            .onChange(of: scrollID) { _, id in
                if isBrowsing, let id { onBrowse(.crossed(id)) }
            }
            .onChange(of: isActive) { _, active in
                if !active { isBrowsing = false; onBrowse(.ended) }
            }
            .onDisappear { isBrowsing = false; onBrowse(.ended) }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("library.grid")
        }
    }

    private var rows: [OneTapeCoverRow] {
        stride(from: 0, to: collections.count, by: 2).map { index in
            OneTapeCoverRow(index: index, first: collections[index],
                second: index + 1 < collections.count ? collections[index + 1] : nil)
        }
    }

    private var rowScrollID: Binding<String?> {
        Binding(get: {
            guard let id = scrollID, let index = collections.firstIndex(where: { $0.id == id }) else { return nil }
            // Normalize an older right-column anchor to its row's first cover.
            return collections[index - index % 2].id
        }, set: { scrollID = $0 })
    }

    private func tile(_ collection: MusicCollection, index: Int,
                      columnWidth: CGFloat, coverWidth: CGFloat) -> some View {
        VStack(spacing: 10) {
            GeometryReader { cell in
                Button {
                    let origin = cell.frame(in: .named("oneTapeLibrary"))
                    onSelect(collection, origin, 0)
                } label: {
                    ZStack {
                        OneTapeCaseArtwork(collection: collection, artwork: artworks[collection.id], layout: .grid)
                            .shadow(color: .black.opacity(0.4), radius: 5, y: 4)
                        Color.clear
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(selectedID == collection.id ? 0 : 1)
                .accessibilityLabel("\(collection.title)，\(collection.subtitle)")
                .accessibilityValue("\(collection.songCount) 首")
                .accessibilityIdentifier("grid.album.\(index)")
            }
            .frame(width: coverWidth, height: coverWidth / OneTapeCaseGeometry.portraitAspectRatio)

            VStack(spacing: 5) {
                Text(collection.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.93))
                Text(collection.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
        }
        .frame(width: columnWidth)
        .task(id: collection.id) { onLoadArtwork(collection) }
    }
}

private struct OneTapeCoverRow: Identifiable {
    let index: Int
    let first: MusicCollection
    let second: MusicCollection?
    var id: String { first.id }
}

/// Reload staggers nearby visible rows rather than delaying by an absolute
/// library index. A restored position deep in a large collection stays prompt.
struct OneTapeLibraryReloadReveal: ViewModifier {
    let ready: Bool
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animation: Animation {
        if reduceMotion { return .easeOut(duration: 0.14) }
        return ready ? .spring(duration: 0.4, bounce: 0.08).delay(Double(order) * 0.03)
            : .easeIn(duration: 0.12)
    }

    func body(content: Content) -> some View {
        content
            .opacity(ready ? 1 : 0)
            .offset(y: reduceMotion || ready ? 0 : 18)
            .animation(animation, value: ready)
    }
}
