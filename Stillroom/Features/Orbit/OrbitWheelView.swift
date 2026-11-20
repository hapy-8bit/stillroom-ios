import SwiftUI

/// Repeated positions are visual slots. Every selection resolves back to one real album identity.
struct OrbitWheelView: View {
    let presentation: OrbitPlaybackPresentation
    let active: Bool
    var onSelectAlbum: (String) -> Void
    var onToggle: () -> Void
    @State private var focus: Double = 0
    @State private var dragBase: Double?
    @State private var ignoreTapUntil = Date.distantPast

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width, geometry.size.height / 1.35)
            let radius = scale * 0.83
            let cover = scale * 0.225
            let center = CGPoint(x: -scale * 0.055, y: geometry.size.height * 0.51)
            let orbit = radius - cover * 1.05
            let stride = max(1, orbit * 26 * .pi / 180)
            ZStack(alignment: .topLeading) {
                paperWheel(diameter: radius * 2)
                    .rotationEffect(.degrees(-focus * 26)).position(center)
                    .animation(nil, value: presentation.position)
                ForEach(slots, id: \.self) { slot in
                    if let album = album(at: slot) {
                        let angle = Double(slot) * 26 - focus * 26
                        let radians = angle * .pi / 180
                        Button { select(album, slot: slot) } label: {
                            ArtworkView(track: album, image: presentation.albumArtworks[album.id])
                                .frame(width: cover, height: cover).clipShape(RoundedRectangle(cornerRadius: cover * 0.2))
                                .overlay(RoundedRectangle(cornerRadius: cover * 0.2).strokeBorder(.black.opacity(0.18), lineWidth: 1))
                                .shadow(color: .black.opacity(0.23), radius: 3, y: 2)
                        }.buttonStyle(.plain).rotationEffect(.degrees(angle))
                            .position(x: center.x + orbit * cos(radians), y: center.y + orbit * sin(radians))
                            .accessibilityLabel("\(album.album)，\(album.artist)\(album.albumKey == presentation.current.albumKey ? "，当前专辑" : "，播放专辑")")
                            .accessibilityIdentifier("orbit.wheel.album.\(album.id).slot.\(slot)")
                    }
                }
                selectionMark.position(x: geometry.size.width - 26, y: center.y)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .contentShape(Rectangle()).simultaneousGesture(drag(stride: stride))
        }.onAppear { syncSelection() }
            .onChange(of: presentation.current.albumKey) { _, _ in syncSelection() }
            .onChange(of: presentation.albums.map(\.albumKey)) { _, _ in syncSelection() }
            .onChange(of: active) { _, isActive in if !isActive { dragBase = nil } }
            .accessibilityElement(children: .contain).accessibilityIdentifier("orbit.wheel")
    }

    private var slots: [Int] {
        guard !presentation.albums.isEmpty else { return [] }
        return Array(Int(floor(focus)) - 4...Int(floor(focus)) + 4)
    }
    private func album(at slot: Int) -> Track? {
        guard !presentation.albums.isEmpty else { return nil }
        let count = presentation.albums.count
        return presentation.albums[(slot % count + count) % count]
    }
    private func select(_ album: Track, slot: Int) {
        guard active, Date() >= ignoreTapUntil else { return }
        settle(Double(slot))
        if album.albumKey == presentation.current.albumKey { onToggle() } else { onSelectAlbum(album.albumKey) }
    }
    private func syncSelection() {
        dragBase = nil
        guard let index = presentation.albums.firstIndex(where: { $0.albumKey == presentation.current.albumKey }) else { return }
        let count = Double(presentation.albums.count)
        focus = Double(index) + ((focus - Double(index)) / count).rounded() * count
    }
    private func settle(_ target: Double) {
        withAnimation(presentation.reducedMotion ? nil : .spring(response: 0.38, dampingFraction: 0.9)) {
            focus = max(-1_000_000, min(1_000_000, target))
        }
    }
    private func drag(stride: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8).onChanged { value in
            guard active else { return }
            if dragBase == nil { dragBase = focus }
            focus = (dragBase ?? focus) - value.translation.height / stride
        }.onEnded { value in
            guard active, let base = dragBase else { dragBase = nil; return }
            dragBase = nil; ignoreTapUntil = Date().addingTimeInterval(0.18)
            let actual = base - value.translation.height / stride
            let projection = (value.predictedEndTranslation.height - value.translation.height) / stride
            settle((actual - max(-1.5, min(1.5, projection))).rounded())
        }
    }
    private func paperWheel(diameter: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(red: 0.94, green: 0.93, blue: 0.92))
                .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
            Text("STILLROOM").font(.system(size: diameter * 0.073, weight: .black)).tracking(-2)
                .rotationEffect(.degrees(90)).offset(x: diameter * 0.12)
            Text("RECORD LIBRARY\n33⅓ · SIDE A").font(.system(size: diameter * 0.022, weight: .heavy))
                .multilineTextAlignment(.center).rotationEffect(.degrees(90)).offset(x: diameter * 0.25)
            ForEach(0..<14) { index in
                Capsule().fill(.black).frame(width: diameter * 0.047, height: diameter * 0.018)
                    .offset(x: diameter * 0.455).rotationEffect(.degrees(Double(index) * 26))
            }
            Circle().fill(.black.opacity(0.1)).frame(width: diameter * 0.035)
        }.foregroundStyle(.black).frame(width: diameter, height: diameter).accessibilityHidden(true)
    }
    private var selectionMark: some View {
        HStack(spacing: 2) {
            ForEach(1..<6) { count in
                VStack(spacing: 2) { ForEach(0..<count, id: \.self) { _ in Circle().fill(.white).frame(width: 3, height: 3) } }
            }
        }.rotationEffect(.degrees(180)).accessibilityHidden(true)
    }
}
