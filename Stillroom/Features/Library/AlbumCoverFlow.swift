import SwiftUI

/// A bounded set of covers provides depth without instantiating an entire private library.
struct AlbumCoverFlow: View {
    let albums: [Track]
    let artworks: [String: UIImage]
    @Binding var selection: Int
    let side: CGFloat
    let artworkTransition: Namespace.ID?
    let reducedMotion: Bool
    let onChoose: (Track) -> Void
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.82, dampingFraction: 0.9)))
    private var translation: CGFloat = 0
    @State private var ignoreTapUntil = Date.distantPast
    @GestureState private var interactionActive = false

    private var stride: CGFloat { side * 0.86 }
    private var visible: [Int] { albums.indices.filter { abs($0 - selection) <= 2 } }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(visible, id: \.self) { index in
                    let distance = Double(index - selection) + AlbumFlowMotion.drag(Double(translation), index: selection,
                                                                                  count: albums.count) / Double(stride)
                    let pose = AlbumCoverPose(distance: distance)
                    Button {
                        guard Date.now >= ignoreTapUntil else { return }
                        onChoose(albums[index])
                    } label: {
                        ArtworkView(track: albums[index], image: artworks[albums[index].id], printed: true)
                            .frame(width: side, height: side)
                            .overlay(Rectangle().strokeBorder(.white.opacity(0.14), lineWidth: 0.7))
                            .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 20)
                            .listeningHero(ListeningArtworkTransition.cover(albums[index]), in: artworkTransition)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .scaleEffect(pose.scale)
                        .rotation3DEffect(.degrees(reducedMotion ? 0 : pose.rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                        .opacity(pose.opacity)
                        .position(x: geometry.size.width / 2 + distance * Double(stride),
                                  y: Double(side) * 0.56 + pose.vertical)
                        .zIndex(5 - abs(distance))
                        .allowsHitTesting(abs(distance) < 1.5)
                        .accessibilityHidden(abs(distance) >= 1.5)
                        .accessibilityLabel("放上唱盘，" + albums[index].album)
                        .accessibilityIdentifier("shelf." + albums[index].id)
                        .accessibilityAction(named: "上一张专辑") { focus(selection - 1) }
                        .accessibilityAction(named: "下一张专辑") { focus(selection + 1) }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped().contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 10)
                    .updating($interactionActive) { _, active, _ in active = true }
                    .onChanged { _ in
                        // A simultaneous drag does not cancel Button's release action. Suppress
                        // that release briefly so browsing never also places an album on the deck.
                        ignoreTapUntil = .distantFuture
                    }
                    .updating($translation) { value, state, transaction in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        transaction.animation = nil
                        state = value.translation.width
                    }
                    .onEnded { value in
                        ignoreTapUntil = Date.now.addingTimeInterval(0.25)
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        focus(AlbumFlowMotion.destination(index: selection, count: albums.count,
                                                          translation: value.translation.width,
                                                          predicted: value.predictedEndTranslation.width, stride: stride))
                    })
        }.frame(height: side * 1.23)
            .onChange(of: interactionActive) { _, active in
                // GestureState also resets on cancellation, so an interrupted drag cannot lock taps out.
                if !active { ignoreTapUntil = Date.now.addingTimeInterval(0.25) }
            }
            .transaction { if reducedMotion { $0.animation = nil } }
    }

    private func focus(_ index: Int) {
        guard !albums.isEmpty else { return }
        withAnimation(ListeningArtworkTransition.animation(reducedMotion: reducedMotion)) {
            selection = min(albums.count - 1, max(0, index))
        }
    }
}
