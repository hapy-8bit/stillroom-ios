import SwiftUI

struct OrbitGridView: View {
    let presentation: OrbitPlaybackPresentation
    let active: Bool
    var onSelectAlbum: (String) -> Void
    var onToggle: () -> Void
    @State private var focus: Double = 0
    @State private var dragBase: Double?
    @State private var ignoreTapUntil = Date.distantPast

    var body: some View {
        GeometryReader { geometry in
            let rows = geometry.size.height > geometry.size.width * 0.75 ? 3 : 1
            let diameter = max(0, min(geometry.size.width * 0.455, (geometry.size.height - 16) / (CGFloat(rows) + CGFloat(rows - 1) * 0.1)))
            let stride = max(1, diameter * 1.1)
            let usedRows = min(rows, presentation.albums.count)
            let usedHeight = CGFloat(usedRows) * stride - diameter * 0.1
            let top = max(12, (geometry.size.height - usedHeight) / 2)
            ZStack(alignment: .topLeading) {
                ForEach(Array(Int(floor(focus)) - 3...Int(floor(focus)) + 3), id: \.self) { column in
                    ForEach(0..<usedRows, id: \.self) { row in
                        if let album = album(column: column, row: row, rows: rows) {
                            let selected = isSelected(album, column: column, rows: rows)
                            ZStack(alignment: .topTrailing) {
                                Button { choose(album, column: column) } label: {
                                    OrbitRotating(running: active && selected && presentation.playing && !presentation.reducedMotion) {
                                        OrbitDiscArtwork(track: album, artwork: presentation.albumArtworks[album.id], libraryDisc: true)
                                    }.frame(width: diameter, height: diameter)
                                }.buttonStyle(.plain).accessibilityLabel("\(album.album)，\(album.artist)\(selected ? "，当前专辑" : "，播放专辑")")
                                    .accessibilityIdentifier("orbit.grid.album.\(album.id).column.\(column)")
                                if selected && presentation.playing {
                                    OrbitTonearm(fraction: 0.35, raised: false, purple: true, reducedMotion: presentation.reducedMotion)
                                        .frame(width: diameter * 0.34, height: diameter * 0.94)
                                        .offset(x: diameter * 0.09, y: max(-top + 3, -diameter * 0.06))
                                        .accessibilityHidden(false).accessibilityLabel("当前唱片，唱臂已落针")
                                        .accessibilityIdentifier("orbit.grid.arm")
                                }
                            }.frame(width: diameter, height: diameter)
                                .position(x: geometry.size.width / 2 + (Double(column) - focus) * stride,
                                          y: top + CGFloat(row) * stride + diameter / 2)
                        }
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped().contentShape(Rectangle())
                .simultaneousGesture(drag(stride: stride))
                .onAppear { syncSelection(rows: rows) }
                .onChange(of: presentation.current.albumKey) { _, _ in syncSelection(rows: rows) }
                .onChange(of: presentation.albums.map(\.albumKey)) { _, _ in syncSelection(rows: rows) }
                .onChange(of: rows) { _, _ in syncSelection(rows: rows) }
        }.onChange(of: active) { _, isActive in if !isActive { dragBase = nil } }
            .accessibilityElement(children: .contain).accessibilityIdentifier("orbit.grid")
    }

    private func columns(_ rows: Int) -> Int { max(1, (presentation.albums.count + rows - 1) / rows) }
    private func album(column: Int, row: Int, rows: Int) -> Track? {
        guard !presentation.albums.isEmpty else { return nil }
        let count = columns(rows)
        let index = ((column % count + count) % count) * rows + row
        return presentation.albums.indices.contains(index) ? presentation.albums[index] : nil
    }
    private func isSelected(_ album: Track, column: Int, rows: Int) -> Bool {
        guard album.albumKey == presentation.current.albumKey,
              let index = presentation.albums.firstIndex(where: { $0.albumKey == album.albumKey }) else { return false }
        let base = Double(index / rows), count = Double(columns(rows))
        return column == Int(base + ((focus - base) / count).rounded() * count)
    }
    private func syncSelection(rows: Int) {
        dragBase = nil
        guard let index = presentation.albums.firstIndex(where: { $0.albumKey == presentation.current.albumKey }) else { return }
        let base = Double(index / rows), count = Double(columns(rows))
        focus = base + ((focus - base) / count).rounded() * count
    }
    private func settle(_ target: Double) {
        withAnimation(presentation.reducedMotion ? nil : .spring(response: 0.36, dampingFraction: 0.92)) {
            focus = max(-1_000_000, min(1_000_000, target))
        }
    }
    private func choose(_ album: Track, column: Int) {
        guard active, Date() >= ignoreTapUntil else { return }
        settle(Double(column))
        if album.albumKey == presentation.current.albumKey { onToggle() } else { onSelectAlbum(album.albumKey) }
    }
    private func drag(stride: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8).onChanged { value in
            guard active else { return }
            if dragBase == nil { dragBase = focus }
            focus = (dragBase ?? focus) - value.translation.width / stride
        }.onEnded { value in
            guard active, let base = dragBase else { dragBase = nil; return }
            dragBase = nil; ignoreTapUntil = Date().addingTimeInterval(0.18)
            let actual = base - value.translation.width / stride
            let prediction = (value.predictedEndTranslation.width - value.translation.width) / stride
            settle((actual - max(-1.25, min(1.25, prediction))).rounded())
        }
    }
}
