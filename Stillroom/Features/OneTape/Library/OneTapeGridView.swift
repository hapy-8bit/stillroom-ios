import SwiftUI

/// Three-column horizontal Norelco cassette wall ("平铺"). Replaces the old
/// cropped vertical portrait list with crisp 1.55:1 landscape crystal jewel cases
/// and full 1:1 album artwork per tile.
struct OneTapeGridView: View {
    let collections: [MusicCollection]
    let artworks: [String: UIImage]
    let selectedID: String?
    var currentCollectionID: String? = nil
    var isPlaying = false
    @Binding var scrollID: String?
    let onSelect: (MusicCollection, CGRect, CGFloat) -> Void
    let onLoadArtwork: (MusicCollection) -> Void
    var onBrowse: (OneTapeLibraryBrowseEvent) -> Void = { _ in }
    var isReloadReady = true
    var isActive = true
    @State private var isBrowsing = false

    private let columnsPerRow = 3

    var body: some View {
        GeometryReader { viewport in
            let width = max(0, viewport.size.width)
            let inset = min(20, max(14, width * 0.036))
            let contentWidth = max(0, width - inset * 2)
            let spacing: CGFloat = width < 360 ? 8 : 10
            let columnWidth = max(0, (contentWidth - spacing * CGFloat(columnsPerRow - 1)) / CGFloat(columnsPerRow))
            let caseHeight = columnWidth / OneTapeCaseGeometry.landscapeAspectRatio
            let anchorIndex = collections.firstIndex { $0.id == scrollID } ?? 0

            ScrollView(.vertical) {
                LazyVStack(spacing: 18) {
                    ForEach(rows) { row in
                        HStack(alignment: .top, spacing: spacing) {
                            ForEach(Array(row.items.enumerated()), id: \.element.id) { offset, item in
                                tile(
                                    item,
                                    index: row.startIndex + offset,
                                    columnWidth: columnWidth,
                                    caseHeight: caseHeight
                                )
                            }
                            if row.items.count < columnsPerRow {
                                ForEach(0..<(columnsPerRow - row.items.count), id: \.self) { _ in
                                    Color.clear
                                        .frame(width: columnWidth, height: 1)
                                        .accessibilityHidden(true)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .modifier(OneTapeLibraryReloadReveal(ready: isReloadReady,
                            order: min(abs(row.startIndex / columnsPerRow - anchorIndex / columnsPerRow), 4)))
                        .id(row.id)
                    }
                }
                .scrollTargetLayout()
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, inset)
                .padding(.top, 74)
                .padding(.bottom, 128)
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
        stride(from: 0, to: collections.count, by: columnsPerRow).map { start in
            let end = min(start + columnsPerRow, collections.count)
            return OneTapeCoverRow(startIndex: start, items: Array(collections[start..<end]))
        }
    }

    private var rowScrollID: Binding<String?> {
        Binding(get: {
            guard let id = scrollID, let index = collections.firstIndex(where: { $0.id == id }) else { return nil }
            return collections[index - index % columnsPerRow].id
        }, set: { scrollID = $0 })
    }

    private func tile(_ collection: MusicCollection, index: Int,
                      columnWidth: CGFloat, caseHeight: CGFloat) -> some View {
        let isCurrent = currentCollectionID == collection.id
        return VStack(alignment: .leading, spacing: 7) {
            GeometryReader { cell in
                Button {
                    let origin = cell.frame(in: .named("oneTapeLibrary"))
                    onSelect(collection, origin, 0)
                } label: {
                    ZStack {
                        OneTapeCaseArtwork(
                            collection: collection,
                            artwork: artworks[collection.id],
                            layout: .grid,
                            compact: true,
                            isCurrent: isCurrent,
                            isPlaying: isPlaying && isCurrent
                        )
                        .shadow(color: .black.opacity(0.48), radius: 6, y: 4)
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
            .frame(width: columnWidth, height: caseHeight)

            VStack(alignment: .leading, spacing: 2.5) {
                Text(collection.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(isCurrent ? Color(red: 0.90, green: 0.60, blue: 0.30) : .white.opacity(0.90))
                Text(collection.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 1)
            .accessibilityHidden(true)
        }
        .frame(width: columnWidth, alignment: .leading)
        .task(id: collection.id) { onLoadArtwork(collection) }
    }
}

private struct OneTapeCoverRow: Identifiable {
    let startIndex: Int
    let items: [MusicCollection]
    var id: String { items[0].id }
}

/// Reload staggers nearby visible rows rather than delaying by an absolute
/// library index. A restored position deep in a large collection stays prompt.
struct OneTapeLibraryReloadReveal: ViewModifier {
    let ready: Bool
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animation: Animation {
        if reduceMotion { return .easeOut(duration: 0.14) }
        return ready ? .spring(duration: 0.36, bounce: 0.08).delay(Double(order) * 0.025)
            : .easeIn(duration: 0.10)
    }

    func body(content: Content) -> some View {
        content
            .opacity(ready ? 1 : 0)
            .offset(y: reduceMotion || ready ? 0 : 14)
            .animation(animation, value: ready)
    }
}
