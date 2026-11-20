import SwiftUI

struct LibraryScreen: View {
    @EnvironmentObject private var player: PlayerStore
    var onClose: (() -> Void)? = nil
    @State private var query = ""
    @State private var mode = 0
    @State private var favoritesOnly = false
    @State private var localOnly = false

    private var visibleTracks: [Track] {
        player.filteredTracks(query).filter {
            (!favoritesOnly || player.favorites.contains($0.id)) && (!localOnly || !$0.isDemo)
        }
    }
    private var albums: [Track] {
        var seen = Set<String>()
        return visibleTracks.filter { seen.insert($0.albumKey).inserted }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RoomBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(spacing: 10) {
                            sourceButton("全部音乐", local: false)
                            sourceButton("我的导入", local: true)
                            Spacer()
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(albums.count) 张唱片 · \(visibleTracks.count) 首音乐")
                                .font(.system(size: 12)).foregroundStyle(RoomStyle.secondary)
                            Spacer()
                            Button {
                                favoritesOnly.toggle()
                            } label: {
                                Label("喜欢", systemImage: favoritesOnly ? "heart.fill" : "heart")
                                    .font(.system(size: 12)).foregroundStyle(favoritesOnly ? RoomStyle.accent : RoomStyle.secondary)
                                    .frame(minHeight: 40)
                            }.buttonStyle(.plain).accessibilityIdentifier("library.favorites")
                        }
                        Picker("曲库显示方式", selection: $mode) {
                            Text("专辑").tag(0)
                            Text("歌曲").tag(1)
                        }.pickerStyle(.segmented)
                        if visibleTracks.isEmpty {
                            emptyLibrary
                        } else if mode == 0 {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 21), GridItem(.flexible(), spacing: 21)], spacing: 28) {
                                ForEach(albums) { track in
                                    NavigationLink {
                                        AlbumDetailScreen(track: track)
                                    } label: {
                                        AlbumCard(track: track, image: player.albumArtworks[track.id], count: player.albumTracks(track).count)
                                    }.buttonStyle(.plain).accessibilityIdentifier("album." + track.id)
                                }
                            }
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(visibleTracks) { track in
                                    TrackRow(track: track, image: player.artworks[track.id],
                                             active: track.id == player.current.id, playing: player.isPlaying) {
                                        player.choose(track, in: visibleTracks); player.showingPlayer = true
                                    }
                                }
                            }
                        }
                        Text("音乐只保存在你的 iPhone").font(.system(size: 10)).foregroundStyle(RoomStyle.muted)
                            .frame(maxWidth: .infinity).padding(.top, 8)
                    }.padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 30)
                }.scrollIndicators(.hidden)
            }
            .navigationTitle("唱片库").toolbarBackground(.hidden, for: .navigationBar)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "搜索歌曲、专辑或艺术家")
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .topBarLeading) { Button("返回播放器", action: onClose).accessibilityIdentifier("library.close") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { player.showingImport = true } label: {
                        if player.importing { ProgressView() } else { Image(systemName: "plus") }
                    }.disabled(!player.libraryReady).accessibilityLabel("导入本地音乐")
                        .accessibilityIdentifier("library.import")
                }
            }
        }
    }

    private var emptyLibrary: some View {
        VStack(spacing: 18) {
            Image(systemName: favoritesOnly ? "heart" : localOnly ? "opticaldisc" : "magnifyingglass")
                .font(.system(size: 38, weight: .ultraLight)).foregroundStyle(RoomStyle.muted)
            Text(favoritesOnly ? "还没有喜欢的音乐" : localOnly && query.isEmpty ? "收藏你的第一张唱片" : "没有找到音乐")
                .font(.system(.title3, design: .serif)).foregroundStyle(RoomStyle.paper)
            Text(favoritesOnly ? "在播放器里点亮爱心，把喜欢的声音留下。" :
                    localOnly && query.isEmpty ? "从「文件」带几首喜欢的歌进来，\n慢慢填满自己的唱片库。" : "试试其他关键词，或导入本地音乐。")
                .font(.subheadline).foregroundStyle(RoomStyle.secondary).multilineTextAlignment(.center)
            if localOnly {
                Button("导入本地音乐") { player.showingImport = true }
                    .font(.subheadline).buttonStyle(.bordered).padding(.top, 6)
                    .accessibilityIdentifier("library.empty-import")
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 30)
    }

    private func sourceButton(_ title: String, local: Bool) -> some View {
        Button { localOnly = local } label: {
            Text(title).font(.system(size: 12, weight: .medium)).padding(.horizontal, 14).padding(.vertical, 12)
                .foregroundStyle(localOnly == local ? RoomStyle.background : RoomStyle.secondary)
                .background(localOnly == local ? RoomStyle.paper : .white.opacity(0.04), in: Capsule())
        }.buttonStyle(.plain).accessibilityIdentifier(local ? "library.local" : "library.all")
            .accessibilityAddTraits(localOnly == local ? .isSelected : [])
    }
}

struct AlbumCard: View {
    let track: Track
    let image: UIImage?
    let count: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtworkView(track: track, image: image, printed: true)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 8)
            Text(track.album).font(RoomStyle.serif(18)).foregroundStyle(RoomStyle.paper).lineLimit(1)
            Text("\(track.artist) · \(count) 首").font(.system(size: 10)).foregroundStyle(RoomStyle.secondary).lineLimit(1)
        }
    }
}

struct TrackRow: View {
    let track: Track
    let image: UIImage?
    let active: Bool
    let playing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ArtworkView(track: track, image: image).frame(width: 47, height: 47).clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title).font(.system(size: 15)).foregroundStyle(active ? RoomStyle.accent : RoomStyle.paper).lineLimit(1)
                    Text(track.artist).font(.system(size: 11)).foregroundStyle(RoomStyle.secondary).lineLimit(1)
                }
                Spacer()
                if active && playing {
                    Image(systemName: "waveform").font(.system(size: 15)).foregroundStyle(RoomStyle.accent)
                } else {
                    Text(MediaTime.label(track.duration)).font(RoomStyle.caption(10)).foregroundStyle(RoomStyle.muted)
                }
            }.padding(.vertical, 11).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("播放 \(track.title)").accessibilityIdentifier("track." + track.id)
    }
}

