import SwiftUI

/// Each cell draws a shallow box, not a card tilted as a single flat image.
/// The spine stays legible while the cover/back plane changes with its position
/// in the scroll viewport. Image pixels never become gesture coordinates.
struct OneTapeCrateView: View {
    let collections: [MusicCollection]
    let artworks: [String: UIImage]
    let selectedID: String?
    let hidesSelected: Bool
    let selectedOriginY: CGFloat
    let onSelect: (MusicCollection, CGRect, CGFloat) -> Void
    let onLoadArtwork: (MusicCollection) -> Void
    var onBrowse: (OneTapeLibraryBrowseEvent) -> Void = { _ in }
    var isReloadReady = true
    var isActive = true
    @Binding var scrollID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBrowsing = false

    var body: some View {
        GeometryReader { viewport in
            let viewportWidth = max(0, viewport.size.width)
            let width = min(max(0, viewportWidth - 64), 470)
            let scale = width / 329
            let anchorIndex = collections.firstIndex { $0.id == scrollID } ?? 0
            ScrollView(.vertical) {
                LazyVStack(spacing: 8 * scale) {
                    ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                        GeometryReader { geometry in
                            let center = geometry.frame(in: .named("oneTapeCrate")).midY
                            let relative = reduceMotion ? CGFloat(0.24) : min(0.87, max(-0.87,
                                (center - viewport.size.height * 0.47) / max(1, viewport.size.height * 0.5)))
                            let frame = geometry.frame(in: .named("oneTapeLibrary"))
                            ZStack {
                                OneTapeSpatialCase(
                                    collection: collection, artwork: artworks[collection.id],
                                    angle: OneTapeCaseGeometry.shelfAngle(pitch: relative)
                                )
                                .frame(width: width, height: width * OneTapeCaseGeometry.portraitAspectRatio)
                                .frame(width: width, height: 112 * scale, alignment: .top)
                                .offset(y: 56 * scale)
                                Color.clear
                            }
                            .frame(width: width, height: 112 * scale)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(collection, frame, relative) }
                            .offset(y: selectedID != nil && selectedID != collection.id
                                ? (frame.midY < selectedOriginY ? -140 : 140) * scale : 0)
                            .opacity(selectedID == collection.id ? (hidesSelected ? 0 : 1)
                                : selectedID == nil ? 1 : 0.2)
                            .accessibilityElement(children: .ignore)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("\(collection.title) by \(collection.subtitle)")
                            .accessibilityValue("\(collection.songCount) 首")
                            .accessibilityIdentifier("crate.album.\(index)")
                            .accessibilityAction { onSelect(collection, frame, relative) }
                        }
                        .frame(width: width, height: 112 * scale)
                        .frame(width: viewportWidth, height: 112 * scale, alignment: .center)
                        .modifier(OneTapeLibraryReloadReveal(ready: isReloadReady,
                            order: min(abs(index - anchorIndex), 4)))
                        .id(collection.id)
                        // A stable cell identity makes media snapshots redraw
                        // freely without dispatching a new artwork request.
                        .task(id: collection.id) { onLoadArtwork(collection) }
                    }
                }
                .scrollTargetLayout()
                .frame(width: viewportWidth, alignment: .center)
                .padding(.top, max(120, viewport.size.height * 0.36))
                .padding(.bottom, max(150, viewport.size.height * 0.42))
            }
            .frame(width: viewportWidth, height: max(0, viewport.size.height), alignment: .top)
            .coordinateSpace(name: "oneTapeCrate")
            .scrollPosition(id: $scrollID, anchor: .center)
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
            .accessibilityIdentifier("library.crate")
            .mask {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.10),
                    .init(color: .black, location: 0.90),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

/// The shelf and its floating selection render the same box. Interpolating the
/// angle here recomputes every projected face on each animation frame; swapping
/// front/back at the edge-on pose cannot flash a full-size flat cover.
struct OneTapeSpatialCase: View, Animatable {
    let collection: MusicCollection
    let artwork: UIImage?
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        GeometryReader { geometry in
            let projection = OneTapeCaseProjection(width: geometry.size.width, angle: angle)
            let faceSize = CGSize(width: projection.width, height: projection.height)
            let spineSize = CGSize(width: projection.width, height: projection.thickness)
            ZStack(alignment: .topLeading) {
                side(projection.left)
                side(projection.right)
                OneTapeCaseArtwork(collection: collection, artwork: artwork,
                                   showsFront: projection.showsFront, layout: .shelf)
                    .frame(width: faceSize.width, height: faceSize.height)
                    .overlay(.black.opacity(min(0.13, abs(sin(angle * .pi / 180)) * 0.13)))
                    .projectionEffect(OneTapeCaseProjection.transform(size: faceSize,
                        corners: projection.showsFront ? projection.front : projection.back))
                    .opacity(min(1, abs(cos(angle * .pi / 180)) * 1_000))
                OneTapeCaseSpine(collection: collection, artwork: artwork, width: projection.width)
                    .frame(width: spineSize.width, height: spineSize.height)
                    .projectionEffect(OneTapeCaseProjection.transform(size: spineSize, corners: projection.spine))
                    // SwiftUI can draw a singular projection as identity. Hide
                    // the zero-area face so no unrotated spine flashes at 0°.
                    .opacity(min(1, abs(sin(angle * .pi / 180)) * 1_000))
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func side(_ points: [CGPoint]) -> some View {
        Path { path in
            path.addLines(points)
            path.closeSubpath()
        }
        .fill(Color(white: 0.055))
        .overlay {
            Path { path in path.addLines(points); path.closeSubpath() }
                .stroke(.white.opacity(0.18), lineWidth: 0.7)
        }
    }
}

private struct OneTapeCaseSpine: View {
    let collection: MusicCollection
    let artwork: UIImage?
    let width: CGFloat
    private var scale: CGFloat { width / 329 }
    private var spineHeight: CGFloat { 51.1 * scale }
    private var palette: OneTapeCasePalette { OneTapeCasePalette(artwork: artwork) }

    var body: some View { spine }

    private var spine: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2 * scale).fill(Color(white: 0.035))
            Rectangle().fill(palette.paper)
                .padding(.horizontal, 12 * scale).padding(.vertical, 3 * scale)
            barcode
                .frame(width: width * 0.5, height: spineHeight - 7 * scale)
                .padding(.leading, 24 * scale)
            Text("\(collection.title.uppercased())   \(collection.subtitle.uppercased())")
                .font(.system(size: 15 * scale, weight: .bold))
                .foregroundStyle(palette.ink)
                .lineLimit(1).truncationMode(.tail)
                .padding(.horizontal, 25 * scale)
            RoundedRectangle(cornerRadius: 2 * scale)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.8 * scale)
            Rectangle().fill(.white.opacity(0.14))
                .frame(height: scale).padding(.horizontal, 4 * scale)
                .frame(maxHeight: .infinity, alignment: .top).padding(.top, 2 * scale)
        }
        .frame(width: width, height: spineHeight)
    }

    private var barcode: some View {
        Canvas { context, size in
            // Stable decorative paper grain from collection identity, never an
            // audio waveform or manufactured song progress.
            let seed = collection.id.utf8.reduce(UInt64(0)) { ($0 &* 31) &+ UInt64($1) }
            for index in 0..<45 {
                let value = (seed &+ UInt64(index * 7919)) % 29
                let x = CGFloat(index) * size.width / 45
                let h = size.height * (0.25 + CGFloat(value) / 40)
                context.fill(Path(CGRect(x: x, y: 0, width: scale * (value % 3 == 0 ? 3 : 1.1), height: h)),
                             with: .color(.white.opacity(0.025 + Double(value % 5) * 0.008)))
            }
        }
    }
}
