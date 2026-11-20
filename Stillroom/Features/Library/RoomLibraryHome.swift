import SwiftUI

/// A normal library page. Collections come only from the supplied tracks and favorites;
/// playback and source access remain events handled by the existing state owner.
struct RoomLibraryHome: View {
    let tracks: [Track]
    let artworks: [String: UIImage]
    let albumArtworks: [String: UIImage]
    let favorites: Set<String>
    let currentID: String
    let playing: Bool
    let libraryReady: Bool
    var reducedMotion = false
    let onPlay: (Track, [Track]) -> Void
    let onImport: () -> Void
    let onSettings: () -> Void
    let onCrafted: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    @Namespace private var headerMotion
    @State private var section = LibrarySection.albums
    @State private var layout = LibraryLayout.grid
    @State private var sort = RoomLibrarySort.album
    @State private var favoritesOnly = false
    @State private var searching = false
    @State private var query = ""
    @State private var headerHeight: CGFloat = 62
    @FocusState private var queryFocused: Bool

    private var hasQuery: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var filteringFavorites: Bool { section == .albums && favoritesOnly }
    private var scopedTracks: [Track] { tracks.filter { !filteringFavorites || favorites.contains($0.id) } }
    private var albums: [RoomLibraryAlbum] {
        RoomLibraryCatalog.albums(tracks: tracks, favorites: favorites, query: query,
                                 favoritesOnly: filteringFavorites, sort: sort)
    }
    private var matches: [Track] { RoomLibraryCatalog.matchingTracks(tracks: scopedTracks, query: query) }
    private var playlists: [RoomSmartPlaylist] {
        RoomLibraryCatalog.playlists(tracks: tracks, favorites: favorites)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    RoomLibraryBackdrop(track: tracks.first { $0.id == currentID } ?? tracks.first,
                        artwork: artworks[currentID] ?? albumArtworks[currentID])
                    // Reserve only the initial content inset. The scroll viewport reaches
                    // behind the floating controls and status bar, as in the supplied reference.
                    content(topInset: headerHeight + geometry.safeAreaInsets.top)
                    header.frame(minHeight: 50).padding(.horizontal, 18).padding(.bottom, 12)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                        .zIndex(1)
                }
            }
            // Root owns the main navigation's safe-area inset. Do not draw a second dock or
            // compensate with a device-specific bottom margin inside the library.
            .navigationTitle("资料库")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LibraryRoute.self) { destination($0) }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("room.library")
    }

    @ViewBuilder private var header: some View {
        if searching {
            searchField
        } else if typeSize.isAccessibilitySize {
            // Move the segment below the two controls instead of shrinking the user's font.
            VStack(spacing: 12) {
                HStack { menuButton; Spacer(); searchButton }
                sectionPicker
            }
        } else {
            HStack(spacing: 12) {
                menuButton
                Spacer(minLength: 0)
                sectionPicker
                Spacer(minLength: 0)
                searchButton
            }
        }
    }

    private var menuButton: some View {
        Menu { libraryMenu } label: { headerIcon(layout.symbol) }
            .accessibilityLabel("资料库菜单").accessibilityIdentifier("room.library.menu")
            .accessibilityActivationPoint(UnitPoint.center)
    }

    private var searchButton: some View {
        Button {
            withAnimation(headerAnimation) { searching = true }
        } label: {
            headerIcon("magnifyingglass", trailing: true)
        }
            .buttonStyle(.plain).accessibilityLabel("搜索资料库")
            .accessibilityIdentifier("room.library.search")
            .accessibilityActivationPoint(UnitPoint.center)
    }

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(LibrarySection.allCases) { item in
                Button { section = item } label: {
                    Text(item.title).font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 19).frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .foregroundStyle(.black.opacity(0.9))
                        .background(section == item ? Color.white : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(section == item ? .isSelected : [])
                .accessibilityIdentifier("room.library.segment." + item.rawValue)
            }
        }
        .padding(3).background {
            headerSurface(Capsule()).matchedGeometryEffect(id: "library.header.main", in: headerMotion)
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").font(.system(size: 20)).foregroundStyle(.black.opacity(0.9))
                TextField("", text: $query, prompt: Text(section == .albums ? "搜索专辑" : "搜索音乐").foregroundStyle(.black.opacity(0.45)))
                    .font(.body).focused($queryFocused).submitLabel(.search)
                    .foregroundStyle(.black.opacity(0.9)).tint(.blue)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .accessibilityLabel("搜索专辑、歌曲或艺人")
                    .accessibilityIdentifier("room.library.query")
            }
            .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 44)
            .background {
                headerSurface(Capsule()).matchedGeometryEffect(id: "library.header.main", in: headerMotion)
            }
            Button(action: cancelSearch) {
                headerIcon("xmark", trailing: true)
            }
                .buttonStyle(.plain).accessibilityLabel("关闭搜索")
                .accessibilityIdentifier("room.library.search.cancel")
                .accessibilityActivationPoint(UnitPoint.center)
        }.onAppear { queryFocused = true }
    }

    @ViewBuilder private func content(topInset: CGFloat) -> some View {
        if !libraryReady && tracks.isEmpty {
            ProgressView("正在读取曲库").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if (hasQuery || section == .albums) && albums.isEmpty && matches.isEmpty {
            emptyAlbums
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if filteringFavorites {
                        Text("只显示喜欢的歌曲所属专辑；详情保留本次筛选。")
                            .font(.caption).foregroundStyle(RoomLibrarySurface.secondary)
                    }
                    // Search is library-wide album/song lookup in either segment. The three
                    // derived collections must not remain as misleading "matching playlists".
                    if hasQuery || section == .albums { albumContent }
                    else { playlistContent }
                    if hasQuery && !matches.isEmpty { searchSongs }
                }
                .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 24)
            }
            .contentMargins(.top, topInset, for: .scrollContent)
            .ignoresSafeArea(.container, edges: .top)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("room.library.content")
        }
    }

    @ViewBuilder private var albumContent: some View {
        if hasQuery { Text("专辑").font(.caption.weight(.semibold)).foregroundStyle(RoomLibrarySurface.secondary) }
        ZStack(alignment: .topLeading) {
            if layout == .grid {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 240 : 138), spacing: 20)],
                          alignment: .leading, spacing: 24) {
                    ForEach(albums) { album in
                        NavigationLink(value: LibraryRoute.album(album.id)) {
                            VStack(alignment: .leading, spacing: 7) {
                                cover(album).aspectRatio(1, contentMode: .fit)
                                Text(album.representative.album).font(.subheadline.weight(.medium)).lineLimit(2)
                                Text(album.representative.artist).font(.caption).foregroundStyle(RoomLibrarySurface.secondary).lineLimit(1)
                            }.foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(album.representative.album + "，" + album.representative.artist)
                        .accessibilityIdentifier("room.library.album." + album.representative.id)
                    }
                }.transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("room.library.grid")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(albums) { album in
                        NavigationLink(value: LibraryRoute.album(album.id)) {
                            HStack(spacing: 14) {
                                cover(album).frame(width: 66, height: 66)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(album.representative.album).font(.body.weight(.medium)).lineLimit(2)
                                    Text(album.representative.artist).font(.caption).foregroundStyle(RoomLibrarySurface.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Text("\(album.tracks.count) 首").font(.caption).foregroundStyle(RoomLibrarySurface.secondary)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(RoomLibrarySurface.secondary)
                            }.foregroundStyle(.white).padding(.vertical, 10).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("room.library.album." + album.representative.id)
                        Divider().overlay(.white.opacity(0.10))
                    }
                }.transition(.opacity.combined(with: .offset(y: 8)))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("room.library.list")
            }
        }.animation(layoutAnimation, value: layout)
    }

    private var playlistContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("智能歌单").font(.caption.weight(.semibold)).foregroundStyle(RoomLibrarySurface.secondary)
            ForEach(playlists) { playlist in
                NavigationLink(value: LibraryRoute.playlist(playlist.kind)) {
                    HStack(spacing: 15) {
                        Image(systemName: playlist.kind.symbol).font(.system(size: 23, weight: .regular))
                            .frame(width: 58, height: 58).background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(playlist.title).font(.body.weight(.medium))
                            Text("智能歌单 · \(playlist.tracks.count) 首").font(.caption).foregroundStyle(RoomLibrarySurface.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(RoomLibrarySurface.secondary)
                    }.foregroundStyle(.white).padding(.vertical, 4).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("room.library.smart." + playlistIdentifier(playlist.kind))
            }
            Text("根据喜欢状态与音乐来源自动整理。")
                .font(.caption).foregroundStyle(RoomLibrarySurface.secondary)
        }
    }

    private var searchSongs: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("歌曲").font(.caption.weight(.semibold)).foregroundStyle(RoomLibrarySurface.secondary)
            ForEach(matches) { track in
                RoomLibrarySongRow(track: track, artwork: artworks[track.id], currentID: currentID, playing: playing) {
                    onPlay(track, matches)
                }.disabled(!libraryReady)
            }
        }
    }

    private var emptyAlbums: some View {
        VStack(spacing: 16) {
            Image(systemName: hasQuery ? "magnifyingglass" : "square.stack").font(.system(size: 58, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.70)).accessibilityHidden(true)
            Text(hasQuery ? "没有找到音乐" : favoritesOnly ? "还没有喜欢的歌曲" : "还没有专辑")
                .font(.title3.weight(.semibold))
            Text(hasQuery ? "试试其他歌曲、专辑或艺人名称。" : favoritesOnly ? "曲库中已有的喜欢状态会自动整理到这里。" : "从文件导入自己的音乐，专辑会显示在这里。")
                .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(RoomLibrarySurface.secondary)
            if !hasQuery && !favoritesOnly {
                Button("导入音乐", action: onImport).buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
                    .disabled(!libraryReady).accessibilityIdentifier("room.library.empty.import")
            }
        }
        .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("room.library.empty")
    }

    @ViewBuilder private var libraryMenu: some View {
        Section("显示方式") {
            ForEach(LibraryLayout.allCases) { value in
                Button { withAnimation(layoutAnimation) { layout = value } } label: {
                    Label(value.title, systemImage: layout == value ? "checkmark" : value.symbol)
                }
                    .accessibilityAddTraits(layout == value ? .isSelected : [])
                    .accessibilityIdentifier("room.library.layout." + value.rawValue)
            }
        }
        Section("专辑范围") { Toggle("只看喜欢的歌曲", isOn: $favoritesOnly).accessibilityIdentifier("room.library.favorites") }
        Section("排序") {
            ForEach(RoomLibrarySort.allCases) { value in
                Button { sort = value } label: { Label(value.title, systemImage: sort == value ? "checkmark" : "textformat.abc") }
                    .accessibilityIdentifier("room.library.sort." + value.rawValue)
            }
        }
        Divider()
        Button("导入音乐", systemImage: "plus", action: onImport).disabled(!libraryReady)
            .accessibilityIdentifier("room.library.import")
        Button("制作与收藏唱片", systemImage: "square.stack.3d.up", action: onCrafted)
            .accessibilityIdentifier("room.library.crafted")
        Button("设置", systemImage: "gearshape", action: onSettings).accessibilityIdentifier("room.library.settings")
    }

    @ViewBuilder private func destination(_ route: LibraryRoute) -> some View {
        switch route {
        case .album(let id):
            if let album = albums.first(where: { $0.id == id }) {
                RoomLibraryCollectionDetail(title: album.representative.album, subtitle: album.representative.artist,
                    tracks: album.tracks, representative: album.representative,
                    cover: albumArtworks[album.representative.id] ?? artworks[album.representative.id],
                    symbol: "square.stack", smart: false, artworks: artworks, currentID: currentID,
                    playing: playing, libraryReady: libraryReady, onPlay: onPlay)
            } else { Text("这张专辑已不在当前资料库中。").foregroundStyle(.secondary) }
        case .playlist(let kind):
            if let playlist = playlists.first(where: { $0.kind == kind }) {
                RoomLibraryCollectionDetail(title: playlist.title, subtitle: playlist.detail, tracks: playlist.tracks,
                    representative: playlist.tracks.first,
                    cover: playlist.tracks.first.flatMap { artworks[$0.id] }, symbol: kind.symbol, smart: true,
                    artworks: artworks, currentID: currentID, playing: playing, libraryReady: libraryReady, onPlay: onPlay)
            }
        }
    }

    private func cover(_ album: RoomLibraryAlbum) -> some View {
        ArtworkView(track: album.representative, image: albumArtworks[album.representative.id] ?? artworks[album.representative.id])
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.13), lineWidth: 0.5))
    }

    private func headerIcon(_ name: String, trailing: Bool = false) -> some View {
        Image(systemName: name).font(.system(size: 20)).foregroundStyle(.black.opacity(0.9))
            .frame(width: 44, height: 44).background {
                if trailing {
                    headerSurface(Circle()).matchedGeometryEffect(id: "library.header.trailing", in: headerMotion)
                } else { headerSurface(Circle()) }
            }
            // Morph only the surface so the control's layout and semantic bounds remain
            // independent of the expanding material behind the glyph.
            .contentShape(Rectangle())
    }

    private func headerSurface<S: InsettableShape>(_ shape: S) -> some View {
        // Only each control diffuses the covers behind it. A light local material keeps
        // the reference's dark glyphs legible without adding an opaque full-width bar.
        shape.fill(.ultraThinMaterial).environment(\.colorScheme, .light)
            .overlay(shape.fill(.white.opacity(0.12)))
            .overlay(shape.strokeBorder(.white.opacity(0.28), lineWidth: 0.5))
    }

    private var motionReduced: Bool { reducedMotion || systemReducedMotion }
    private var headerAnimation: Animation? { motionReduced ? nil : .spring(response: 0.34, dampingFraction: 0.9) }
    private var layoutAnimation: Animation? { motionReduced ? nil : .easeInOut(duration: 0.3) }

    private func cancelSearch() {
        queryFocused = false
        withAnimation(headerAnimation) { query = ""; searching = false }
    }
    private func playlistIdentifier(_ kind: RoomSmartPlaylistKind) -> String { kind == .originals ? "demos" : kind.rawValue }
}

private enum LibrarySection: String, CaseIterable, Identifiable {
    case albums, playlists
    var id: String { rawValue }
    var title: String { self == .albums ? "专辑" : "歌单" }
}

private enum LibraryLayout: String, CaseIterable, Identifiable {
    case grid, list
    var id: String { rawValue }
    var title: String { self == .grid ? "网格" : "列表" }
    var symbol: String { self == .grid ? "square.split.2x2" : "list.bullet" }
}

private enum LibraryRoute: Hashable {
    case album(String), playlist(RoomSmartPlaylistKind)
}

enum RoomLibrarySurface {
    static let background = Color(hex: 0x292B2D)
    static let secondary = Color.white.opacity(0.65)
}

private struct RoomLibraryBackdrop: View {
    let track: Track?
    let artwork: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoomLibrarySurface.background
                if let track {
                    // Use the current real cover as static atmosphere, never a generated library
                    // image or an animated blur tied to media ticks.
                    ArtworkView(track: track, image: artwork)
                        .frame(width: max(geometry.size.width, geometry.size.height),
                               height: max(geometry.size.width, geometry.size.height))
                        .blur(radius: 65).opacity(0.45)
                    Color.black.opacity(0.34)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}
