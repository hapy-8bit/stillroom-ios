import SwiftUI
import UniformTypeIdentifiers

struct OneTapeRoot: View {
    @StateObject private var store = OneTapeStore()
    @StateObject private var music = OneTapeMusicStore()
    @StateObject private var orientation = OneTapeOrientationMonitor()
    @StateObject private var opening = OneTapeOpeningStore()
    @StateObject private var purchases = OneTapePurchaseStore()
    @StateObject private var drawingStore = OneTapeDrawingStore()
    @StateObject private var artworkStore = OneTapeArtworkStore()
    @State private var hasOpenedLibrary = false
    @State private var albumCoverPickerVisible = false
    @State private var albumCoverTargetID: String?
    @State private var bodyArtworkColor: OneTapeTransportMaterial.RGB?
    @State private var drawingRequest: OneTapeDrawingWorkflowRequest?
    @State private var halftoneRequest: OneTapeHalftoneWorkflowRequest?
    @State private var drawingOperationNotice: String?
    // Held via @State rather than @StateObject so 30Hz tilt updates only
    // invalidate leaf foil/body views instead of re-evaluating root chrome.
    @State private var tiltMonitor = OneTapeTiltMonitor()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var menuAnimation: Animation? { reduceMotion ? nil : .easeOut(duration: 0.4) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                Color.black.ignoresSafeArea()
                if opening.isVisible {
                    OneTapeOpeningBackdrop(opening: opening, reducedMotion: reduceMotion)
                }
                OneTapePlayerFace(
                        appearance: store.appearance,
                        readout: readout,
                        cassetteReadout: cassetteReadout,
                        customPrint: resolvedCustomPrint,
                        artwork: currentArtwork,
                        artworkColor: bodyArtworkColor,
                        visualization: music.player.visualization,
                        tiltMonitor: tiltMonitor,
                        tapeProgress: OneTapeTapeGeometry.progress(queueIDs: music.player.queue.ids,
                            tracks: music.player.tracks, currentID: music.player.currentTrack?.id,
                            position: music.player.position),
                        quarterTurns: orientation.quarterTurns,
                        trackChangeMotionRate: music.player.tapeTrackMotionRate,
                        openingPose: opening.playerPose(reducedMotion: reduceMotion),
                        playbackMode: music.player.playbackMode,
                        glassInteractionEnabled: !opening.isVisible && !store.presentation.customizationVisible && store.panel == nil,
                        onGlass: { withAnimation(menuAnimation) { store.toggleMenu() } },
                        onLCD: {
                            if readout.hasTrack { store.cycleScreen() }
                            else { store.present(.studio) }
                        },
                        onTransport: transport,
                        onSetGlassOpen: store.setGlassOpen,
                        onBeginWind: music.beginWindingForTape,
                        onEndWind: { music.player.endWinding(resume: $0) },
                        onPlaybackMode: music.cyclePlaybackModeForTape
                    )
                    .ignoresSafeArea(.container)
                    .opacity(opening.isVisible || store.presentation.destination == .player ? 1 : 0)
                    .allowsHitTesting(store.presentation.destination == .player)
                    .accessibilityHidden(store.presentation.destination != .player)
                    // Keep visual reel and screen animation running behind the
                    // translucent customization sheet while the player owns the scene.
                    .environment(\.scenePhase,
                        !opening.isVisible && store.presentation.destination == .player
                            ? scenePhase : .inactive)

                if hasOpenedLibrary || store.presentation.destination == .library {
                    OneTapeLibraryView(
                        layout: $store.libraryLayout,
                        albums: music.albums, playlists: music.playlists,
                        tracks: music.player.libraryTracks, artworks: music.artworks,
                        currentTrackID: music.player.currentTrack?.id,
                        isPlaying: music.player.isPlaying,
                        isActive: store.presentation.destination == .library,
                        favourites: music.player.favorites,
                        recentlyPlayedTrackIDs: music.player.recentlyPlayedTrackIDs,
                        onSelect: { collection, index, shuffle in
                            let id = collection.trackIDs.indices.contains(index) ? collection.trackIDs[index] : nil
                            music.selectTrack(in: collection, startAt: id, shuffle: shuffle)
                        },
                        onToggleFavourite: music.player.toggleFavorite,
                        onSetAlbumCover: { collection in
                            // Capture a durable local song identity before opening the system
                            // picker. Playback/remote refresh cannot change the cover's target.
                            guard let id = collection.trackIDs.first,
                                  !music.player.importCoordinator.busy else { return }
                            albumCoverTargetID = id
                            albumCoverPickerVisible = true
                        },
                        onTogglePlayback: music.togglePlaybackForTape,
                        onLoadArtwork: { collection in Task { await music.loadArtwork(for: collection) } },
                        onBrowse: music.handleLibraryBrowse,
                        onSettings: { store.present(.settings) }
                    )
                    .opacity(!opening.isVisible && store.presentation.destination == .library ? 1 : 0)
                    .allowsHitTesting(store.presentation.destination == .library)
                    .accessibilityHidden(store.presentation.destination != .library)
                }

                if !opening.isVisible, store.presentation.destination == .insights {
                    OneTapeInsightsView(
                        ledger: music.player.listeningLedger,
                        liveEvent: music.player.liveListeningEvent,
                        appearance: store.appearance,
                        albums: music.albums,
                        tracks: music.player.libraryTracks,
                        artworks: music.artworks,
                        favorites: music.player.favorites,
                        isPlaying: music.player.isPlaying,
                        isActive: store.presentation.destination == .insights,
                        onLoadArtwork: { collection in Task { await music.loadArtwork(for: collection) } },
                        onPlayAlbum: playInsightAlbum,
                        onPlayTrack: playInsightTrack
                    )
                    .transition(.opacity)
                }

                if !opening.isVisible, store.presentation.customizationVisible {
                    customization(in: geometry)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }

            }
            // The dock belongs to the window's safe viewport. Page content
            // may draw outside that viewport without moving its screen edges.
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay(alignment: .bottom) {
                if !opening.isVisible, store.presentation.menuVisible {
                    navigation
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .topTrailing) {
                if !opening.isVisible, store.presentation.menuVisible, store.presentation.destination == .player {
                    settingsButton
                        .padding(.trailing, 27)
                        // The physical player covers the status-bar region. Only
                        // this decorative HUD reaches into it; library uses safe area.
                        .offset(y: -geometry.safeAreaInsets.top + 9)
                        .transition(.opacity)
                }
            }
            #if DEBUG && targetEnvironment(simulator)
            .overlay(alignment: .topTrailing) {
                if !opening.isVisible, store.presentation.destination == .player {
                    OneTapeSimulatorFPSOverlay()
                        .padding(.trailing, 78)
                        .offset(y: -geometry.safeAreaInsets.top + 20)
                }
            }
            #endif
            .animation(menuAnimation, value: store.presentation.menuVisible)
            .allowsHitTesting(!opening.isVisible)
            .accessibilityHidden(opening.isVisible)
            .overlay {
                if opening.isVisible {
                    OneTapeOpeningScene(opening: opening,
                        safeAreaInsets: geometry.safeAreaInsets,
                        reducedMotion: reduceMotion,
                        onOpenCase: { opening.openCase(reducedMotion: reduceMotion) },
                        onInsert: {
                            opening.insert(reducedMotion: reduceMotion)
                        }, onSkip: opening.finish)
                }
            }
            .overlay {
                Color.clear
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .modifier(OneTapeHalftoneWorkflowModifier(
                        artworkStore: artworkStore,
                        appearance: $store.appearance,
                        cassetteReadout: cassetteReadout,
                        request: $halftoneRequest,
                        notice: $drawingOperationNotice
                    ))
            }
            .modifier(OneTapeDrawingWorkflowModifier(
                drawingStore: drawingStore,
                appearance: $store.appearance,
                cassetteReadout: cassetteReadout,
                request: $drawingRequest,
                notice: $drawingOperationNotice
            ))
        }
        .ignoresSafeArea(.keyboard)
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .sheet(item: Binding(get: { store.panel }, set: { store.panel = $0 })) { panel in
            panelContent(panel)
        }
        .fileImporter(isPresented: $albumCoverPickerVisible,
                      allowedContentTypes: [.jpeg, .png], allowsMultipleSelection: false) { result in
            let target = albumCoverTargetID
            albumCoverTargetID = nil
            switch result {
            case .success(let urls):
                guard let target, !urls.isEmpty else { return }
                Task {
                    await music.player.importCoordinator.prepareReplacement(
                        urls: urls, trackID: target, kind: .cover, album: true)
                    store.present(.localImport)
                }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError {
                    music.message = "封面图片未能读取，请重新选择。"
                }
            }
        }
        .alert(store.appearanceNotice == nil ? "音乐" : "外观设置", isPresented: Binding(
            get: { activeNotice != nil }, set: { if !$0 { clearNotice() } }
        )) {
            Button("知道了", role: .cancel, action: clearNotice)
        } message: {
            Text(activeNotice ?? "")
        }
        .task {
            // Empty UI fixtures never restore real music or a saved server.
            guard !ProcessInfo.processInfo.arguments.contains("--one-tape-empty") else { return }
            await music.restore()
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                purchases.start()
                await purchases.refreshEntitlements()
            }
        }
        .onChange(of: store.presentation.destination) { _, destination in
            // Keep the opened crate alive so returning from the physical player
            // preserves its selected case, query, section and scroll position.
            if destination == .library { hasOpenedLibrary = true }
            syncTiltMonitor()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { opening.suspend() }
            music.setTransportFeedbackActive(phase == .active)
            if phase == .active { store.activate(); orientation.start() } else {
                store.suspend()
                orientation.stop()
                music.player.cancelWinding()
                music.player.flushListeningLedger()
            }
            syncTiltMonitor()
        }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if opening.isVisible {
                store.navigate(to: .player)
            } else if args.contains("--one-tape-appearance-fixture"), args.contains("--open-insights-fixture") {
                store.navigate(to: .insights)
            }
            bodyArtworkColor = OneTapeArtworkColorSampler.color(from: currentArtwork)
            music.setTransportFeedbackActive(scenePhase == .active)
            store.activate(); orientation.start()
            syncTiltMonitor()
        }
        .onDisappear {
            opening.suspend()
            music.setTransportFeedbackActive(false)
            music.player.flushListeningLedger()
            store.suspend(); orientation.stop(); music.cancel()
            tiltMonitor.stop()
        }
        .onChange(of: currentArtwork) { _, image in
            bodyArtworkColor = OneTapeArtworkColorSampler.color(from: image)
        }
        .onChange(of: reduceMotion) { _, reduced in
            // Switching the accessibility setting mid-flight cancels the motion.
            if reduced, opening.isVisible { opening.suspend() }
            syncTiltMonitor()
        }
        .onChange(of: opening.isVisible) { _, visible in
            if !visible, let notice = opening.notice {
                music.message = notice
                opening.notice = nil
            }
            syncTiltMonitor()
        }
        .onChange(of: store.appearance.needsMotionTilt) { _, _ in
            syncTiltMonitor()
        }
        .task(id: music.player.currentTrack?.id) {
            // A cold restore may show the player without opening the crate.
            // Load the real current cover through the existing cancelable cache.
            guard let track = music.player.currentTrack,
                  let album = music.albums.first(where: { $0.trackIDs.contains(track.id) }) else { return }
            await music.loadArtwork(for: album)
        }
    }

    private var navigation: some View {
        OneTapeNavigation(
            destination: store.presentation.destination,
            customizationVisible: store.presentation.customizationVisible,
            tapeStyle: store.appearance.tapeStyle,
            readout: readout,
            hasPlayedCurrentTrack: music.player.recentlyPlayedTrackIDs.contains(
                music.player.currentTrack?.id ?? ""),
            onPlayer: { store.navigate(to: .player) },
            onLibrary: { store.navigate(to: .library) },
            onInsights: { store.navigate(to: .insights) },
            onCustomize: store.toggleCustomization,
            onImport: { store.present(.sources) },
            onSettings: { store.present(.settings) }
        )
    }

    private func customization(in geometry: GeometryProxy) -> some View {
        let fullHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
        let scale = min(geometry.size.width / 393, fullHeight / 852)
        let width = min(geometry.size.width - 24, 365 * scale)
        let top = max(0, (fullHeight - 852 * scale) / 2 + 118 * scale - geometry.safeAreaInsets.top)
        let height = min(616 * scale, geometry.size.height - top)
        return OneTapeCustomizationView(
            appearance: $store.appearance,
            tab: $store.customizationTab,
            readout: readout,
            cassetteReadout: cassetteReadout,
            customPrint: resolvedCustomPrint,
            drawings: drawingStore.drawings,
            artworks: artworkStore.artworks,
            thumbnailForDrawing: { drawingStore.thumbnail(for: $0) },
            titleForDrawing: { drawingStore.displayTitle(for: $0) },
            thumbnailForArtwork: { artworkStore.thumbnail(for: $0) },
            titleForArtwork: { artworkStore.displayTitle(for: $0) },
            visualization: music.player.visualization,
            onClose: { withAnimation(menuAnimation) { store.closeCustomization() } },
            onStudio: { store.present(.studio) },
            onStartNewDrawing: { drawingRequest = .startNewDrawing },
            onStartHalftone: { halftoneRequest = .startNewArtwork },
            onEditDrawing: { drawingRequest = .editDrawing($0) },
            onToggleInkMode: toggleInkMode,
            onDeleteDrawing: deleteDrawing,
            onEditArtwork: { halftoneRequest = .editArtwork($0) },
            onReprintArtwork: reprintArtwork,
            onDeleteArtwork: deleteArtwork,
            onGetPaper: { drawingRequest = .exportPaper },
            onImportFromPhotos: { drawingRequest = .importFromPhotos },
            onImportFromFiles: { drawingRequest = .importFromFiles }
        )
        .frame(width: width, height: height)
        .position(x: geometry.size.width / 2, y: top + height / 2)
    }

    private var settingsButton: some View {
        Button { store.present(.settings) } label: {
            ZStack {
                Image(systemName: "hexagon").font(.system(size: 22, weight: .medium))
                Circle().stroke(lineWidth: 1.5).frame(width: 9, height: 9)
            }
            .foregroundStyle(.white.opacity(0.65))
            .frame(width: 50, height: 50)
            .modifier(OneTapeGlassSurface(shape: Circle()))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("设置")
        .accessibilityIdentifier("nav.settings")
    }

    @ViewBuilder
    private func panelContent(_ panel: OneTapePanel) -> some View {
        switch panel {
        case .settings:
            OneTapeSettingsView(
                connectionName: music.connection?.baseURL.host,
                onStudio: { store.present(.studio) },
                onAddMusic: { store.present(.sources) },
                onReplayOpening: {
                    store.panel = nil
                    store.navigate(to: .player)
                    opening.replay()
                },
                proStatus: purchases.statusLabel,
                purchaseIssue: purchases.entitlementIssue,
                purchasesBusy: purchases.isBusy,
                isRestoringPurchases: purchases.operation == .restore,
                onRestorePurchases: purchases.restorePurchases,
                keepAwake: $store.keepAwake
            )
            .alert(item: $purchases.notice, content: purchaseAlert)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
        case .studio:
            OneTapeStudioView(product: purchases.product, isPro: purchases.isPro,
                isPurchasing: purchases.operation == .purchase, isLoadingProduct: purchases.isLoadingProduct,
                canPurchase: purchases.canPurchase, productIssue: purchases.productIssue,
                entitlementIssue: purchases.entitlementIssue, onPurchase: purchases.buy,
                onReload: { Task { await purchases.refreshEntitlements(); await purchases.loadProduct() } })
                .task { await purchases.refreshEntitlements(); await purchases.loadProduct() }
                .alert(item: $purchases.notice, content: purchaseAlert)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(30)
        case .sources:
            OneTapeSourcesView(
                connection: music.connection, albumCount: music.sourceAlbumCount,
                trackCount: music.sourceTrackCount, isLoading: music.isLoading,
                isDisconnecting: music.isDisconnecting,
                progressText: music.progress ?? "", message: music.message,
                onConnect: { address, username, password in
                    Task { await music.connect(address: address, username: username, password: password) }
                },
                onRefresh: { Task { await music.refresh() } },
                onDisconnect: { Task { await music.disconnect() } },
                onCancel: music.cancel,
                onLocal: { store.present(.localImport) },
                onOpenLibrary: { store.panel = nil; store.navigate(to: .library) }
            )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        case .localImport:
            MusicImportScreen(coordinator: music.player.importCoordinator, presentation: .oneTape)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func purchaseAlert(_ notice: OneTapePurchaseNotice) -> Alert {
        Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("知道了")))
    }

    private func syncTiltMonitor() {
        let shouldRun = !opening.isVisible
            && store.presentation.destination == .player
            && scenePhase == .active
            && store.appearance.needsMotionTilt
        tiltMonitor.setActive(shouldRun, reducedMotion: reduceMotion)
    }

    private var cassetteReadout: OneTapeCassetteReadout {
        OneTapeCassetteReadout(
            queueIDs: music.player.queue.ids,
            tracks: music.player.tracks,
            currentTrackID: music.player.currentTrack?.id
        )
    }

    private var currentArtwork: UIImage? {
        music.player.currentTrack.flatMap { music.artwork(for: $0) }
    }

    private var readout: OneTapePlaybackReadout {
        guard let track = music.player.currentTrack else { return .empty }
        let ids = music.player.queue.ids
        return OneTapePlaybackReadout(
            title: track.title, artist: track.artist,
            positionSeconds: music.player.position, durationSeconds: music.player.duration,
            isPlaying: music.player.isPlaying, isPreparing: music.player.snapshot.isPreparing,
            trackIndex: ids.firstIndex(of: track.id) ?? 0, trackCount: max(1, ids.count),
            trackID: track.id
        )
    }

    private func transport(_ action: OneTapeTransportAction) {
        guard music.player.currentTrack != nil else { return }
        switch action {
        case .previous: music.stepTrackForTape(-1)
        case .play: music.togglePlaybackForTape()
        case .next: music.stepTrackForTape(1)
        }
    }

    private var resolvedCustomPrint: OneTapeResolvedPrint? {
        drawingStore.resolvedPrint(for: store.appearance)
            ?? artworkStore.resolvedPrint(for: store.appearance)
    }

    private var activeNotice: String? {
        store.appearanceNotice
            ?? drawingOperationNotice
            ?? drawingStore.notice
            ?? artworkStore.notice
            ?? (store.panel == .sources ? nil : music.message)
            ?? music.player.message
    }

    private func clearNotice() {
        store.appearanceNotice = nil
        drawingOperationNotice = nil
        drawingStore.notice = nil
        artworkStore.notice = nil
        music.message = nil
        music.player.message = nil
    }

    private func toggleInkMode(_ drawing: OneTapeCustomDrawing) {
        let next: OneTapeDrawingInkMode = drawing.inkMode == .tapeInk ? .originalColors : .tapeInk
        drawingStore.updateInkMode(id: drawing.id, inkMode: next)
    }

    private func deleteDrawing(_ drawing: OneTapeCustomDrawing) {
        drawingStore.deleteDrawing(id: drawing.id)
        if store.appearance.customDrawingID == drawing.id {
            store.appearance.clearCustomDrawingSelection()
        }
    }

    private func reprintArtwork(_ artwork: OneTapeCustomArtwork) {
        do {
            let reprinted = try artworkStore.reprintArtwork(id: artwork.id, for: store.appearance.tapeStyle)
            store.appearance.selectCustomArtwork(reprinted.id)
        } catch {
            drawingOperationNotice = error.localizedDescription
        }
    }

    private func deleteArtwork(_ artwork: OneTapeCustomArtwork) {
        artworkStore.deleteArtwork(id: artwork.id)
        if store.appearance.customArtworkID == artwork.id {
            store.appearance.clearCustomArtworkSelection()
        }
    }

    private func playInsightAlbum(_ albumKey: String) {
        let tracksByID = Dictionary(music.player.libraryTracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if let collection = music.albums.first(where: { album in
            if let firstID = album.trackIDs.first, let track = tracksByID[firstID], track.albumKey == albumKey {
                return true
            }
            return (album.title + "\u{001F}" + album.subtitle) == albumKey
        }) {
            music.selectTrack(in: collection, startAt: collection.trackIDs.first, shuffle: false)
            withAnimation(menuAnimation) { store.navigate(to: .player) }
            return
        }
        let matching = music.player.libraryTracks.filter { $0.albumKey == albumKey }
        if let first = matching.first {
            music.player.choose(first, in: matching, autoplay: true)
            withAnimation(menuAnimation) { store.navigate(to: .player) }
        }
    }

    private func playInsightTrack(_ trackID: String) {
        if let collection = music.albums.first(where: { $0.trackIDs.contains(trackID) }) {
            music.selectTrack(in: collection, startAt: trackID, shuffle: false)
            withAnimation(menuAnimation) { store.navigate(to: .player) }
            return
        }
        if let track = music.player.libraryTracks.first(where: { $0.id == trackID }) {
            music.player.choose(track, in: music.player.libraryTracks, autoplay: true)
            withAnimation(menuAnimation) { store.navigate(to: .player) }
        }
    }
}

struct OneTapeGlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(.black.opacity(0.4)), in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 0.7))
        }
    }
}
