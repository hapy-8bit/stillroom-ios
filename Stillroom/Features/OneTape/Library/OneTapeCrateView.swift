import SwiftUI

/// Vertical 3D cassette crate ("翻箱"). Each cell projects a rigid horizontal Norelco
/// jewel case whose focal tape fans open to expose ~95% of its front artwork while
/// neighboring cases tuck back along the rack with realistic depth, z-ordering, and shadows.
struct OneTapeCrateView: View {
    let collections: [MusicCollection]
    let artworks: [String: UIImage]
    let selectedID: String?
    let hidesSelected: Bool
    let selectedOriginY: CGFloat
    var currentCollectionID: String? = nil
    var isPlaying = false
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
            let width = min(max(0, viewportWidth - 52), 440)
            let scale = width / 329.0
            let slotHeight = 136 * scale
            let caseHeight = width * OneTapeCaseGeometry.portraitAspectRatio
            let anchorIndex = collections.firstIndex { $0.id == scrollID } ?? 0

            ScrollView(.vertical) {
                LazyVStack(spacing: 8 * scale) {
                    ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                        let isCurrent = currentCollectionID == collection.id
                        GeometryReader { geometry in
                            let center = geometry.frame(in: .named("oneTapeCrate")).midY
                            let focalY = viewport.size.height * 0.45
                            let relative = reduceMotion
                                ? CGFloat(0)
                                : min(1.0, max(-1.0, (center - focalY) / max(1, viewport.size.height * 0.44)))
                            let focus = reduceMotion ? 1.0 : OneTapeCaseGeometry.crateFocus(for: relative)
                            let angle = reduceMotion ? -5.0 : OneTapeCaseGeometry.shelfAngle(pitch: relative)
                            // Upper cases subtly recede in scale; lower foreground cases stay full-width.
                            let cardScale: CGFloat = reduceMotion
                                ? 1.0
                                : (relative < 0 ? CGFloat(0.89 + 0.11 * focus) : CGFloat(0.95 + 0.05 * focus))
                            let depthDim = reduceMotion ? 0.0 : (1.0 - focus) * (relative < 0 ? 0.34 : 0.22)
                            let lowerClearance = reduceMotion
                                ? CGFloat(0)
                                : OneTapeCaseGeometry.crateClearanceFraction(for: relative) * (82 * scale)
                            let visualOffsetY = -28 * scale + lowerClearance
                            let frame = geometry.frame(in: .named("oneTapeLibrary"))
                            let tapFrame = frame.offsetBy(dx: 0, dy: lowerClearance)

                            ZStack {
                                OneTapeSpatialCase(
                                    collection: collection,
                                    artwork: artworks[collection.id],
                                    angle: angle,
                                    isCurrent: isCurrent,
                                    isPlaying: isPlaying && isCurrent,
                                    sheenShift: relative * 0.20,
                                    dimAmount: depthDim
                                )
                                .frame(width: width, height: caseHeight)
                                .scaleEffect(cardScale, anchor: .top)
                                .shadow(
                                    color: .black.opacity(0.30 + 0.34 * focus),
                                    radius: (8 + 14 * focus) * scale,
                                    y: (6 + 9 * focus) * scale
                                )
                                .frame(width: width, height: slotHeight, alignment: .top)
                                .offset(y: visualOffsetY)
                                Color.clear
                            }
                            .frame(width: width, height: slotHeight)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(collection, tapFrame, relative) }
                            .offset(y: selectedID != nil && selectedID != collection.id
                                ? (frame.midY < selectedOriginY ? -140 : 140) * scale : 0)
                            .opacity(selectedID == collection.id ? (hidesSelected ? 0 : 1)
                                : selectedID == nil ? 1 : 0.18)
                            .accessibilityElement(children: .ignore)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("\(collection.title) by \(collection.subtitle)")
                            .accessibilityValue("\(collection.songCount) 首")
                            .accessibilityIdentifier("crate.album.\(index)")
                            .accessibilityAction { onSelect(collection, tapFrame, relative) }
                        }
                        .frame(width: width, height: slotHeight)
                        .frame(width: viewportWidth, height: slotHeight, alignment: .center)
                        // Strictly monotonic physical layering: closer/lower cassettes always stay
                        // in front of cassettes further back so z-order never snaps mid-scroll.
                        .zIndex(Double(index))
                        .modifier(OneTapeLibraryReloadReveal(ready: isReloadReady,
                            order: min(abs(index - anchorIndex), 4)))
                        .id(collection.id)
                        // Stable cell identity lets media snapshots redraw freely without
                        // re-dispatching artwork network requests.
                        .task(id: collection.id) { onLoadArtwork(collection) }
                    }
                }
                .scrollTargetLayout()
                .frame(width: viewportWidth, alignment: .center)
                .padding(.top, max(130, viewport.size.height * 0.25))
                .padding(.bottom, max(220, viewport.size.height * 0.42))
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
                    .init(color: .black, location: 0.08),
                    .init(color: .black, location: 0.90),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

/// The shelf and its floating selection render the same rigid 3D box. Interpolating
/// `angle` recomputes every projected face smoothly without flashing an unrotated plane.
struct OneTapeSpatialCase: View, Animatable {
    let collection: MusicCollection
    let artwork: UIImage?
    var angle: Double
    var isCurrent = false
    var isPlaying = false
    var sheenShift: CGFloat = 0
    var dimAmount: Double = 0

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        GeometryReader { geometry in
            let projection = OneTapeCaseProjection(width: geometry.size.width, angle: angle)
            let faceSize = CGSize(width: projection.width, height: projection.height)
            let spineSize = CGSize(width: projection.width, height: projection.thickness)
            let frontShade = min(0.55, dimAmount + abs(sin(angle * .pi / 180)) * 0.14)
            let spineShade = min(0.45, dimAmount * 0.72)

            ZStack(alignment: .topLeading) {
                side(projection.left)
                side(projection.right)
                OneTapeCaseArtwork(
                    collection: collection,
                    artwork: artwork,
                    showsFront: projection.showsFront,
                    layout: .shelf,
                    compact: false,
                    isCurrent: isCurrent,
                    isPlaying: isPlaying,
                    sheenShift: sheenShift
                )
                .frame(width: faceSize.width, height: faceSize.height)
                .overlay(.black.opacity(frontShade))
                .projectionEffect(OneTapeCaseProjection.transform(size: faceSize,
                    corners: projection.showsFront ? projection.front : projection.back))
                .opacity(min(1, abs(cos(angle * .pi / 180)) * 1_000))

                OneTapeCaseSpine(
                    collection: collection,
                    artwork: artwork,
                    width: projection.width,
                    isCurrent: isCurrent
                )
                .frame(width: spineSize.width, height: spineSize.height)
                .overlay(.black.opacity(spineShade))
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
                .stroke(.white.opacity(max(0.06, 0.20 * (1 - dimAmount))), lineWidth: 0.7)
        }
    }
}

private struct OneTapeCaseSpine: View {
    let collection: MusicCollection
    let artwork: UIImage?
    let width: CGFloat
    var isCurrent = false

    private var scale: CGFloat { width / 329.0 }
    private var spineHeight: CGFloat { 51.1 * scale }
    private var palette: OneTapeCasePalette { OneTapeCasePalette(artwork: artwork) }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2.5 * scale, style: .continuous)
                .fill(Color(white: 0.038))

            // J-card paper spine strip with leading color index tab.
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isCurrent ? Color(red: 0.87, green: 0.55, blue: 0.25) : palette.accentStrip)
                    .frame(width: 9 * scale)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [palette.paper, palette.paperShadow],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding(.horizontal, 12 * scale)
            .padding(.vertical, 3.5 * scale)

            paperGrain
                .frame(width: width * 0.52, height: spineHeight - 8 * scale)
                .padding(.leading, 24 * scale)

            HStack(alignment: .center, spacing: 10 * scale) {
                Text(collection.title.uppercased())
                    .font(.system(size: 14 * scale, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4 * scale)
                Text(collection.subtitle.uppercased())
                    .font(.system(size: 11 * scale, weight: .medium))
                    .foregroundStyle(palette.ink.opacity(0.62))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.leading, 28 * scale)
            .padding(.trailing, 22 * scale)

            // Clear polystyrene spine wall edge highlights.
            RoundedRectangle(cornerRadius: 2.5 * scale, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 0.85 * scale)
            Rectangle()
                .fill(.white.opacity(0.20))
                .frame(height: max(0.6, 1.1 * scale))
                .padding(.horizontal, 5 * scale)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 2.2 * scale)
        }
        .frame(width: width, height: spineHeight)
    }

    private var paperGrain: some View {
        Canvas { context, size in
            // Deterministic decorative paper grain keyed by collection identity.
            let seed = collection.id.utf8.reduce(UInt64(0)) { ($0 &* 31) &+ UInt64($1) }
            for index in 0..<42 {
                let value = (seed &+ UInt64(index * 7919)) % 29
                let x = CGFloat(index) * size.width / 42
                let h = size.height * (0.24 + CGFloat(value) / 42)
                context.fill(
                    Path(CGRect(x: x, y: 0, width: scale * (value % 3 == 0 ? 2.6 : 1.0), height: h)),
                    with: .color(.white.opacity(0.022 + Double(value % 5) * 0.007))
                )
            }
        }
    }
}
