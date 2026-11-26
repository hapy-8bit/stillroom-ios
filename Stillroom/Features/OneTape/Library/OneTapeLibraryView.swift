import SwiftUI

struct OneTapeLibraryView: View {
    @Binding var layout: OneTapeLibraryLayout
    var albums: [MusicCollection] = []
    var playlists: [MusicCollection] = []
    var tracks: [Track] = []
    var artworks: [String: UIImage] = [:]
    var currentTrackID: String? = nil
    var isPlaying = false
    var isActive = true
    var favourites: Set<String> = []
    var recentlyPlayedTrackIDs: [String] = []
    var onSelect: (MusicCollection, Int, Bool) -> Void = { _, _, _ in }
    var onToggleFavourite: (Track) -> Void = { _ in }
    var onSetAlbumCover: (MusicCollection) -> Void = { _ in }
    var onTogglePlayback: () -> Void = {}
    var onLoadArtwork: (MusicCollection) -> Void = { _ in }
    var onBrowse: (OneTapeLibraryBrowseEvent) -> Void = { _ in }
    let onSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedID: String?
    @State private var openingStage: OneTapeAlbumOpeningStage = .folded
    @State private var openingOrigin: CGRect = .zero
    @State private var openingPitch: CGFloat = 0
    @State private var openedLayout: OneTapeLibraryLayout = .shelf
    @State private var openingTask: Task<Void, Never>?
    @State private var openingGeneration = 0
    @State private var section: OneTapeLibrarySection = .albums
    @State private var source: OneTapeLibrarySource = .all
    @State private var sort: OneTapeLibrarySort = .recentlyAdded
    @State private var isSearching = false
    @State private var query = ""
    @State private var entranceStage: EntranceStage = .waiting
    @State private var shelfScrollID: String?
    @State private var gridScrollID: String?
    @State private var pendingLayout: OneTapeLibraryLayout?
    @State private var reloadStage: ReloadStage = .ready
    @State private var isLayoutReloading = false
    @FocusState private var searchFocused: Bool

    private enum EntranceStage { case waiting, albums, controls }
    private enum ReloadStage { case ready, clearing, loading }

    var body: some View {
        GeometryReader { geometry in
            // The foreground stays in the safe area. Restoring its full window
            // height keeps the empty label fixed when the native keyboard appears.
            let fullHeight = geometry.size.height + geometry.safeAreaInsets.top
                + geometry.safeAreaInsets.bottom
            ZStack(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: Color(white: 0.10), location: 0),
                        .init(color: Color(white: 0.04), location: 0.24),
                        .init(color: Color(white: 0.02), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(.container)

                RadialGradient(
                    colors: [focalCrateAtmosphere.opacity(0.82), .clear],
                    center: .init(x: 0.5, y: 0.44),
                    startRadius: 20,
                    endRadius: max(geometry.size.width * 0.85, 280)
                )
                .ignoresSafeArea(.container)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: shelfScrollID)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                ZStack(alignment: .top) {
                    if visibleCollections.isEmpty {
                        emptyState
                            .position(
                                x: geometry.size.width / 2,
                                y: fullHeight * 0.572 - geometry.safeAreaInsets.top
                            )
                    } else {
                        collectionDisplay
                            .id(layout)
                    }
                }
                // Both scroll styles own the same viewport before any reveal
                // transform; a narrow child must not determine the new origin.
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .offset(y: entranceStage == .waiting ? geometry.size.height * 0.85 : 0)
                .opacity(entranceStage == .waiting ? 0 : 1)
                .opacity(reloadStage == .ready ? 1 : 0)
                .scaleEffect(x: 1, y: reduceMotion || reloadStage == .ready ? 1 : 0.96, anchor: .top)
                .offset(y: reduceMotion || reloadStage == .ready ? 0 : reloadStage == .clearing ? -16 : 42)
                .opacity(selection == nil || openingStage != .revealed ? 1 : 0)
                .allowsHitTesting(selection == nil && entranceStage == .controls && !isLayoutReloading)
                .accessibilityHidden(selection != nil || entranceStage != .controls || isLayoutReloading)

                if reloadStage == .loading {
                    ProgressView()
                        .tint(.white.opacity(0.6))
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.46)
                        .accessibilityLabel("正在切换显示样式")
                        .accessibilityIdentifier("library.reloading")
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                if selection == nil {
                    header(width: geometry.size.width)
                        .padding(.horizontal, 16)
                        .padding(.top, 3)
                        .offset(y: entranceStage == .controls ? 0 : -geometry.safeAreaInsets.top - 68)
                        .opacity(entranceStage == .controls ? 1 : 0)
                        .allowsHitTesting(entranceStage == .controls)
                        .accessibilityHidden(entranceStage != .controls)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let collection = selection {
                    OneTapeAlbumDetail(
                        collection: collection, tracks: collectionTracks(collection),
                        artwork: artworks[collection.id], currentTrackID: currentTrackID,
                        isPlaying: isPlaying, isActive: isActive, openingStage: openingStage,
                        openingOrigin: openingOrigin, openingPitch: openingPitch,
                        openingLayout: openedLayout,
                        favourites: favourites,
                        onPlay: { index, shuffle in play(collection, index: index, shuffle: shuffle) },
                        onToggleFavourite: onToggleFavourite,
                        onSetAlbumCover: collection.remoteID.isEmpty ? { onSetAlbumCover(collection) } : nil,
                        onTogglePlayback: onTogglePlayback,
                        onBack: closeCollection
                    )
                    .task(id: collection.id) { onLoadArtwork(collection) }
                    .transition(.identity)
                    .zIndex(1)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .coordinateSpace(name: "oneTapeLibrary")
        }
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(.dark)
        .task(id: isActive) { await enterLibrary() }
        .task(id: isActive && scenePhase == .active ? pendingLayout : nil) {
            if isActive, scenePhase == .active, let pendingLayout { await reloadLayout(to: pendingLayout) }
        }
        .task(id: isSearching && isActive) {
            guard isSearching, isActive else { searchFocused = false; return }
            // Let the capsule expand before presenting the keyboard. This
            // view-owned task cancels if search closes or the library hides.
            do {
                if !reduceMotion { try await Task.sleep(for: .milliseconds(240)) }
            } catch { return }
            guard !Task.isCancelled, isSearching, isActive else { return }
            searchFocused = true
        }
        .onDisappear {
            searchFocused = false; cancelOpening(); cancelLayoutReload(); onBrowse(.ended)
        }
        .onChange(of: isActive) { _, active in
            if !active {
                onBrowse(.ended)
                searchFocused = false
                cancelOpening()
                cancelLayoutReload()
                if selection != nil { openingStage = .revealed }
            }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced, isActive { entranceStage = .controls }
            if reduced, selection != nil { cancelOpening(); openingStage = .revealed }
            if reduced, let target = pendingLayout {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) { layout = target; cancelLayoutReload() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelLayoutReload() }
        }
        .onChange(of: (albums + playlists).map(\.id)) { _, ids in
            if let selectedID, !ids.contains(selectedID) { cancelOpening(); self.selectedID = nil }
        }
    }

    private var currentCollectionID: String? {
        guard let currentTrackID else { return nil }
        return visibleCollections.first { $0.trackIDs.contains(currentTrackID) }?.id
    }

    private var focalCrateAtmosphere: Color {
        guard layout == .shelf, selection == nil, !visibleCollections.isEmpty else { return .clear }
        let focalID = shelfScrollID ?? visibleCollections.first?.id
        guard let focalID, let art = artworks[focalID] else { return .clear }
        return OneTapeCasePalette(artwork: art).atmosphere
    }

    @ViewBuilder private var collectionDisplay: some View {
        switch layout {
        case .shelf:
            OneTapeCrateView(
                collections: visibleCollections, artworks: artworks,
                selectedID: selectedID, hidesSelected: true,
                selectedOriginY: openingOrigin.midY,
                currentCollectionID: currentCollectionID,
                isPlaying: isPlaying,
                onSelect: openCollection, onLoadArtwork: onLoadArtwork,
                onBrowse: onBrowse, isReloadReady: reloadStage == .ready,
                isActive: isActive && selection == nil && !isLayoutReloading,
                scrollID: $shelfScrollID
            )
        case .grid:
            OneTapeGridView(
                collections: visibleCollections, artworks: artworks,
                selectedID: selectedID,
                currentCollectionID: currentCollectionID,
                isPlaying: isPlaying,
                scrollID: $gridScrollID,
                onSelect: openCollection, onLoadArtwork: onLoadArtwork,
                onBrowse: onBrowse, isReloadReady: reloadStage == .ready,
                isActive: isActive && selection == nil && !isLayoutReloading
            )
        }
    }

    private func selectLayout(_ target: OneTapeLibraryLayout) {
        guard target != layout, !isLayoutReloading else { return }
        onBrowse(.ended)
        isLayoutReloading = true
        withAnimation(.easeIn(duration: reduceMotion ? 0.05 : 0.10)) { reloadStage = .clearing }
        pendingLayout = target
    }

    private func reloadLayout(to target: OneTapeLibraryLayout) async {
        // This is a view-owned reload presentation. The keyed task cancels on
        // navigation/backgrounding, so it cannot later switch a hidden shelf.
        do {
            try await Task.sleep(for: .milliseconds(reduceMotion ? 50 : 100))
            try Task.checkCancellation()
            guard isActive, pendingLayout == target else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                reloadStage = .loading
                layout = target
            }
            // Commit a hidden layout frame before its crisp staggered reveal.
            try await Task.sleep(for: .milliseconds(reduceMotion ? 30 : 40))
            try Task.checkCancellation()
            guard isActive, pendingLayout == target else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.36, bounce: 0.08)) {
                reloadStage = .ready
            }
            try await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 320))
            try Task.checkCancellation()
            guard isActive, pendingLayout == target else { return }
            isLayoutReloading = false
            pendingLayout = nil
        } catch {
            // Lifecycle handlers own cleanup. A cancelled older task must not
            // reset a later request that happens to choose the same layout.
            return
        }
    }

    private func cancelLayoutReload() {
        pendingLayout = nil
        isLayoutReloading = false
        reloadStage = .ready
    }

    private func enterLibrary() async {
        guard isActive else { entranceStage = .waiting; return }
        guard !reduceMotion, selection == nil else { entranceStage = .controls; return }
        entranceStage = .waiting
        // Mount below the window before starting the upward shelf motion.
        // A cancelled navigation cannot later reveal the hidden toolbar.
        do { try await Task.sleep(for: .milliseconds(32)) } catch { return }
        guard !Task.isCancelled, isActive else { return }
        withAnimation(.timingCurve(0.18, 0.76, 0.25, 1, duration: 0.68)) {
            entranceStage = .albums
        }
        do { try await Task.sleep(for: .milliseconds(680)) } catch { return }
        guard !Task.isCancelled, isActive else { return }
        withAnimation(.easeOut(duration: 0.30)) { entranceStage = .controls }
    }

    private var selection: MusicCollection? {
        guard let selectedID else { return nil }
        return (albums + playlists).first { $0.id == selectedID }
    }

    private var visibleCollections: [MusicCollection] {
        OneTapeLibraryQuery.collections(
            section == .albums ? albums : playlists, tracks: tracks, query: query,
            source: source, sort: sort, favourites: favourites,
            recentlyPlayed: recentlyPlayedTrackIDs
        )
    }

    private func collectionTracks(_ collection: MusicCollection) -> [Track] {
        let lookup = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { _, newer in newer })
        return collection.trackIDs.compactMap { lookup[$0] }
    }

    private func openCollection(_ collection: MusicCollection, origin: CGRect, pitch: CGFloat) {
        searchFocused = false
        cancelOpening()
        // Keep the selected entry's header format with its retained detail page.
        openedLayout = layout
        openingOrigin = origin
        openingPitch = pitch
        openingStage = reduceMotion ? .revealed : .folded
        onBrowse(.ended)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.34)) {
            selectedID = collection.id
        }
        guard !reduceMotion else { return }
        let generation = openingGeneration
        openingTask = Task { @MainActor in
            // Commit the folded pose once before animating the newly mounted
            // floating case; otherwise insertion can skip the standing motion.
            do { try await Task.sleep(for: .milliseconds(32)) } catch { return }
            guard !Task.isCancelled, generation == openingGeneration else { return }
            withAnimation(.easeOut(duration: 0.42)) { openingStage = .standing }
            do {
                try await Task.sleep(for: .milliseconds(420))
                guard !Task.isCancelled, generation == openingGeneration else { return }
                withAnimation(.easeInOut(duration: 0.55)) { openingStage = .docked }
                // Let the 550ms lift finish, then hold the docked case for
                // 500ms before the list reveal. This is visual, not media time.
                try await Task.sleep(for: .milliseconds(1_050))
                guard !Task.isCancelled, generation == openingGeneration else { return }
                withAnimation(.easeOut(duration: 0.25)) { openingStage = .revealing }
                // A fading row can already appear hittable to AX while UIKit
                // still ignores its touch. Publish interaction readiness only
                // after the visible reveal completes.
                try await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, generation == openingGeneration else { return }
                openingStage = .revealed
                openingTask = nil
            } catch { return }
        }
    }

    private func closeCollection() {
        cancelOpening()
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.55, dampingFraction: 0.9)) {
            selectedID = nil
        }
    }

    private func cancelOpening() {
        openingGeneration += 1
        openingTask?.cancel()
        openingTask = nil
    }

    private func play(_ collection: MusicCollection, index: Int, shuffle: Bool) {
        onSelect(collection, index, shuffle)
    }

    private var emptyTitle: String {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "无匹配结果"
        }
        return section == .albums ? "无磁带" : "无播放列表"
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            if section == .playlists && query.isEmpty {
                Image(systemName: "music.note.list")
                    .font(.system(size: 29, weight: .medium))
                    .frame(width: 32, height: 32)
            } else {
                EmptyTapeStackMark()
                    .frame(width: 27, height: 32)
            }
            Text(emptyTitle)
                .font(.system(size: 12, weight: .regular))
                .tracking(2)
                .accessibilityIdentifier("library.empty")
        }
        .foregroundStyle(Color(white: 0.21))
    }

    private func header(width: CGFloat) -> some View {
        let availableWidth = max(0, width - 32)
        return ZStack(alignment: .leading) {
            if !isSearching {
                HStack(spacing: max(8, width * 0.025)) {
                    filterMenu
                    sectionPicker
                    layoutToggleButton
                    Color.clear.frame(width: 46, height: 46)
                }
                .foregroundStyle(.white.opacity(0.68))
                .frame(width: availableWidth)
                .transition(.move(edge: .leading))
            }
            searchBar
                .frame(width: availableWidth)
                .frame(width: isSearching ? availableWidth : 46, alignment: .leading)
                .clipShape(Capsule())
                .allowsHitTesting(isSearching)
                .accessibilityHidden(!isSearching)
                .frame(width: availableWidth, alignment: .trailing)
            if !isSearching {
                Button(action: openSearch) {
                    Color.clear.frame(width: 46, height: 46).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("搜索音乐库")
                .accessibilityIdentifier("library.search")
                .frame(width: availableWidth, alignment: .trailing)
            }
        }
        .frame(width: availableWidth, height: 46)
        // Keep one search capsule anchored at the right. It grows leftward as
        // the controls leave, then collapses back into the same search button.
        .clipped()
    }

    private var layoutToggleButton: some View {
        let activeLayout = pendingLayout ?? layout
        let nextLayout: OneTapeLibraryLayout = activeLayout == .shelf ? .grid : .shelf
        return Button {
            selectLayout(nextLayout)
        } label: {
            Group {
                if reduceMotion {
                    Image(systemName: activeLayout == .shelf ? "square.grid.3x2" : "rectangle.stack")
                } else {
                    Image(systemName: activeLayout == .shelf ? "square.grid.3x2" : "rectangle.stack")
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .font(.system(size: 16.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.76))
            .frame(width: 46, height: 46)
            .background { LibraryCapsuleSurface() }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isLayoutReloading)
        .sensoryFeedback(.selection, trigger: layout)
        .accessibilityLabel(activeLayout == .shelf ? "切换至平铺视图" : "切换至翻箱视图")
        .accessibilityIdentifier("library.layoutToggle")
    }

    private var layoutPicker: some View {
        Picker("显示样式", selection: Binding(
            get: { pendingLayout ?? layout }, set: { selectLayout($0) }
        )) {
            Label("翻箱", systemImage: "rectangle.stack")
                .tag(OneTapeLibraryLayout.shelf)
                .accessibilityIdentifier("library.layout.shelf")
            Label("平铺", systemImage: "square.grid.3x2")
                .tag(OneTapeLibraryLayout.grid)
                .accessibilityIdentifier("library.layout.grid")
        }
        // Native palette pickers form one horizontal row inside a Menu.
        .pickerStyle(.palette)
        .menuActionDismissBehavior(.enabled)
        .disabled(isLayoutReloading)
        .accessibilityIdentifier("library.layout")
    }

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(OneTapeLibrarySection.allCases) { item in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        section = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white.opacity(section == item ? 0.78 : 0.36))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            if section == item {
                                Capsule()
                                    .fill(.white.opacity(0.11))
                                    .overlay { Capsule().stroke(.white.opacity(0.15), lineWidth: 0.75) }
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(item == .albums ? "library.albums" : "library.playlists")
                .accessibilityAddTraits(section == item ? [.isSelected] : [])
            }
        }
        .padding(4)
        .frame(height: 46)
        .background { LibraryCapsuleSurface() }
    }

    private var filterMenu: some View {
        Menu {
            layoutPicker
            Divider()

            Picker("Show", selection: $source) {
                ForEach(OneTapeLibrarySource.allCases) { item in
                    Text(item.title)
                        .tag(item)
                        .accessibilityIdentifier("library.filter.\(item.rawValue)")
                }
            }
            .pickerStyle(.inline)

            Picker("Sort by", selection: $sort) {
                ForEach(OneTapeLibrarySort.allCases) { item in
                    Text(item.title)
                        .tag(item)
                        .accessibilityIdentifier("library.sort.\(item.rawValue)")
                }
            }
            .pickerStyle(.inline)

            Divider()
            Button("设置", systemImage: "gearshape", action: onSettings)
                .accessibilityIdentifier("library.openSettings")
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 17.5, weight: .semibold))
                .frame(width: 46, height: 46)
                .background { LibraryCapsuleSurface() }
        }
        .menuStyle(.borderlessButton)
        .menuOrder(.fixed)
        .accessibilityLabel("音乐库菜单")
        .accessibilityValue(sort.title)
        .accessibilityIdentifier("library.filter")
    }

    private var searchBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            if isSearching {
                TextField("搜索磁带和艺人", text: $query)
                .font(.system(size: 16.5))
                .foregroundStyle(.white)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel("搜索音乐库")
                .accessibilityIdentifier("library.searchField")
                .onSubmit { searchFocused = false }
            Button(action: closeSearch) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.1), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭搜索")
            .accessibilityIdentifier("library.closeSearch")
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, isSearching ? 18 : 13.5)
        .padding(.trailing, 10)
        .frame(height: 46)
        .background { LibraryCapsuleSurface() }
    }

    private func openSearch() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) {
            isSearching = true
        }
    }

    private func closeSearch() {
        searchFocused = false
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) {
            query = ""
            isSearching = false
        }
    }
}

private struct LibraryCapsuleSurface: View {
    var body: some View {
        Capsule()
            .fill(Color(white: 0.055).opacity(0.88))
            .overlay { Capsule().stroke(.white.opacity(0.12), lineWidth: 0.8) }
    }
}

private struct EmptyTapeStackMark: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 27, size.height / 32)
            var outline = Path()
            outline.addRoundedRect(in: CGRect(x: 3 * scale, y: 10 * scale,
                width: 21 * scale, height: 21 * scale), cornerSize: CGSize(width: 3 * scale, height: 3 * scale))
            outline.move(to: CGPoint(x: 5 * scale, y: 6 * scale))
            outline.addLine(to: CGPoint(x: 22 * scale, y: 6 * scale))
            outline.move(to: CGPoint(x: 8 * scale, y: 2 * scale))
            outline.addLine(to: CGPoint(x: 19 * scale, y: 2 * scale))
            context.stroke(outline, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

