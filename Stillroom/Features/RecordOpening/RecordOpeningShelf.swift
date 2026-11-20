import SwiftUI

/// First-run selection only. Data and media intent belong to the caller; this view owns only
/// the finite stack's scroll position and the captured origin of the selected visual object.
struct RecordOpeningShelf: View {
    let albums: [Track]
    let artworks: [String: UIImage]
    let selectedTrackID: String?
    let openProgress: Double
    var exitProgress: Double = 0
    let reducedMotion: Bool
    var gravityY: Double = 0
    let onSelect: (Track) -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedOrigin: OpeningStackSelection?
    @State private var ignoreTapUntil = Date.distantPast
    @GestureState private var drag: CGFloat = 0
    @GestureState private var dragging = false

    private var motionReduced: Bool { reducedMotion || systemReducedMotion }
    private var turn: Double { RecordOpeningGeometry.clampedProgress(openProgress) }
    private var extraction: Double { RecordOpeningGeometry.clampedProgress(exitProgress) }

    var body: some View {
        GeometryReader { proxy in
            let geometry = OpeningStackGeometry(size: proxy.size, isPad: UIDevice.current.userInterfaceIdiom == .pad)
            let offset = scrollOffset + resistedDrag(geometry: geometry)
            let selectedIndex = albums.firstIndex { $0.id == selectedTrackID }
            ZStack {
                ForEach(visibleIndices(geometry: geometry, offset: offset), id: \.self) { index in
                    row(index: index, geometry: geometry, offset: offset, selectedIndex: selectedIndex)
                }
                if let selectedIndex {
                    selected(index: selectedIndex, geometry: geometry, offset: offset)
                        .zIndex(1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .simultaneousGesture(browseGesture(geometry: geometry))
            .clipped()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordOpening.shelf")
        .onChange(of: selectedTrackID) { _, id in if id == nil { selectedOrigin = nil } }
        .onChange(of: albums.map(\.id)) { _, _ in scrollOffset = 0; selectedOrigin = nil }
        .onChange(of: dragging) { _, active in
            // Cancellation resets GestureState without onEnded. Do not leave selection locked.
            if !active { ignoreTapUntil = Date.now.addingTimeInterval(0.25) }
        }
        .transaction { if motionReduced { $0.animation = nil } }
    }

    private func row(index: Int, geometry: OpeningStackGeometry, offset: CGFloat,
                     selectedIndex: Int?) -> some View {
        let midpoint = geometry.rowMidpoint(index: index, count: albums.count, scrollOffset: offset)
        let pose = geometry.pose(midpoint: midpoint, gravityY: gravityY)
        let retirement = geometry.retirement(index: index, selectedIndex: selectedIndex, midpoint: midpoint)
        let center = geometry.point(midpoint: midpoint)
        let track = albums[index]
        return OpeningSleeveRenderer(track: track, artwork: artworks[track.id], geometry: geometry, pose: pose,
            interactive: selectedTrackID == nil, accessibilityID: "recordOpening.album." + track.id) {
                choose(index: index, geometry: geometry, midpoint: midpoint, pose: pose)
            }
            .position(center)
            .offset(x: geometry.axis == .horizontal ? retirement.offset : 0,
                    y: geometry.axis == .vertical ? retirement.offset : 0)
            .blur(radius: motionReduced ? 0 : retirement.blur)
            .zIndex(pose.zIndex)
            .animation(motionReduced ? nil : .spring(response: 0.4, dampingFraction: 1)
                .delay(retirement.delay), value: selectedTrackID)
            .opacity(selectedIndex == index ? 0 : 1)
            .accessibilityAction(named: "上一张封套") { focus(index: index - 1, geometry: geometry) }
            .accessibilityAction(named: "下一张封套") { focus(index: index + 1, geometry: geometry) }
    }

    private func selected(index: Int, geometry: OpeningStackGeometry, offset: CGFloat) -> some View {
        let track = albums[index]
        let fallbackMidpoint = geometry.rowMidpoint(index: index, count: albums.count, scrollOffset: offset)
        let origin = selectedOrigin?.trackID == track.id ? selectedOrigin : nil
        let midpoint = origin.map { $0.axisFraction * geometry.axisLength } ?? fallbackMidpoint
        let pose = origin?.pose ?? geometry.pose(midpoint: midpoint, gravityY: gravityY)
        let start = geometry.point(midpoint: midpoint)
        let target = CGPoint(x: geometry.openFrame.midX, y: geometry.openFrame.midY)
        return OpeningSleeveRenderer(track: track, artwork: artworks[track.id], geometry: geometry, pose: pose,
            progress: turn, interactive: false, onSelect: {})
            .scaleEffect(1 + (geometry.openFrame.width / geometry.coverSide - 1) * turn)
            .position(x: start.x + (target.x - start.x) * turn + geometry.extractionX * extraction,
                      y: start.y + (target.y - start.y) * turn)
            .opacity(motionReduced ? 1 - extraction : 1)
    }

    private func choose(index: Int, geometry: OpeningStackGeometry, midpoint: CGFloat, pose: OpeningStackPose) {
        guard selectedTrackID == nil, Date.now >= ignoreTapUntil else { return }
        selectedOrigin = OpeningStackSelection(trackID: albums[index].id,
            axisFraction: midpoint / geometry.axisLength, pose: pose)
        onSelect(albums[index])
    }

    private func visibleIndices(geometry: OpeningStackGeometry, offset: CGFloat) -> [Int] {
        albums.indices.filter { index in
            let mid = geometry.rowMidpoint(index: index, count: albums.count, scrollOffset: offset)
            return mid > -geometry.coverSide && mid < geometry.axisLength + geometry.coverSide
        }
    }

    private func nearestIndex(geometry: OpeningStackGeometry) -> Int {
        let value = (geometry.axisLength / 2 - geometry.contentOrigin(count: albums.count) - geometry.stride / 2 - scrollOffset) / geometry.stride
        return min(max(0, albums.count - 1), max(0, Int(value.rounded())))
    }

    private func resistedDrag(geometry: OpeningStackGeometry) -> CGFloat {
        CGFloat(AlbumFlowMotion.drag(Double(drag), index: nearestIndex(geometry: geometry), count: albums.count))
    }

    private func browseGesture(geometry: OpeningStackGeometry) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragging) { _, active, _ in if selectedTrackID == nil { active = true } }
            .updating($drag) { value, state, transaction in
                guard selectedTrackID == nil else { return }
                transaction.animation = nil
                state = geometry.axis == .vertical ? value.translation.height : value.translation.width
            }
            .onChanged { _ in if selectedTrackID == nil { ignoreTapUntil = .distantFuture } }
            .onEnded { value in
                ignoreTapUntil = Date.now.addingTimeInterval(0.25)
                guard selectedTrackID == nil else { return }
                let translation = geometry.axis == .vertical ? value.translation.height : value.translation.width
                let predicted = geometry.axis == .vertical ? value.predictedEndTranslation.height : value.predictedEndTranslation.width
                // Browsing friction/prediction remains the existing bounded adapter; it is not
                // claimed as recovered original UIScrollView velocity or inertia configuration.
                let index = AlbumFlowMotion.destination(index: nearestIndex(geometry: geometry), count: albums.count,
                    translation: Double(translation), predicted: Double(predicted), stride: Double(geometry.stride))
                focus(index: index, geometry: geometry)
            }
    }

    private func focus(index: Int, geometry: OpeningStackGeometry) {
        guard !albums.isEmpty else { return }
        let target = min(albums.count - 1, max(0, index))
        withAnimation(motionReduced ? nil : .spring(response: 0.4, dampingFraction: 1)) {
            scrollOffset = geometry.centeredScrollOffset(index: target, count: albums.count)
        }
    }
}

private struct OpeningStackSelection {
    let trackID: String
    let axisFraction: CGFloat
    let pose: OpeningStackPose
}
