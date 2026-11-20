import SwiftUI

struct OneTapeAlbumDetail: View {
    let collection: MusicCollection
    let tracks: [Track]
    let artwork: UIImage?
    let currentTrackID: String?
    let isPlaying: Bool
    var isActive = true
    var openingStage: OneTapeAlbumOpeningStage = .revealed
    var openingOrigin: CGRect = .zero
    var openingPitch: CGFloat = 0
    var openingLayout: OneTapeLibraryLayout = .shelf
    var favourites: Set<String> = []
    let onPlay: (Int, Bool) -> Void
    var onToggleFavourite: (Track) -> Void = { _ in }
    var onSetAlbumCover: (() -> Void)? = nil
    let onTogglePlayback: () -> Void
    let onBack: () -> Void

    private var isCurrentCollection: Bool {
        guard let currentTrackID else { return false }
        return collection.trackIDs.contains(currentTrackID)
    }
    private var palette: OneTapeCasePalette { OneTapeCasePalette(artwork: artwork) }
    private var ready: Bool { openingStage == .revealing || openingStage == .revealed }
    private var interactive: Bool { openingStage == .revealed }

    var body: some View {
        GeometryReader { geometry in
            let width = min(max(0, geometry.size.width - 64), 470)
            let scale = width / 329
            let cover = OneTapeCaseGeometry.dockedFrame(in: geometry.size, layout: openingLayout)
            ZStack(alignment: .topLeading) {
                ScrollView {
                    VStack(spacing: 0) {
                        Button(action: onBack) {
                            ZStack {
                                // Artwork is intentionally display-only. The
                                // button owns an independent full-cover hit area.
                                Color.clear
                                OneTapeCaseArtwork(collection: collection, artwork: artwork, layout: openingLayout)
                            }
                            .frame(width: cover.width, height: cover.height)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityLabel("\(collection.title)，\(collection.subtitle)。轻点放回")
                        .accessibilityValue(artwork == nil ? "未设置专辑封面" : "有专辑封面")
                        .accessibilityHint(onSetAlbumCover == nil ? "" : "长按可设置专辑封面")
                        .accessibilityIdentifier("album.hero")
                        .disabled(!interactive)
                        .contextMenu {
                            if let onSetAlbumCover {
                                Button("设置专辑封面", systemImage: "photo", action: onSetAlbumCover)
                                    .accessibilityIdentifier("album.setCover")
                            }
                        }
                        .accessibilityActions {
                            if let onSetAlbumCover {
                                Button("设置专辑封面", action: onSetAlbumCover)
                            }
                        }
                        if openingLayout == .grid {
                            VStack(spacing: 5 * scale) {
                                Text(collection.title)
                                    .font(.system(size: 19 * scale, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.94))
                                    .lineLimit(2)
                                Text(collection.subtitle)
                                    .font(.system(size: 12 * scale))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .lineLimit(1)
                            }
                            .padding(.top, 16 * scale)
                        }
                        controls(scale: scale)
                            .padding(.top, 18 * scale)
                        VStack(spacing: 0) {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                song(track, index: index, scale: scale)
                            }
                        }
                        .padding(.top, 10 * scale)
                    }
                    .frame(width: width)
                    .padding(.top, 53 * scale)
                    .padding(.bottom, 124)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .opacity(ready ? 1 : 0)
                .allowsHitTesting(interactive)
                .accessibilityHidden(!interactive)
                .accessibilityIdentifier("album.songs")
                if openingStage != .revealed {
                    // Release the projected transition layers after the
                    // crossfade; the native cover owns interaction from here.
                    floatingCase(in: geometry.size)
                }
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 42, height: 42)
                        .background(.black.opacity(0.3), in: Circle())
                        .overlay { Circle().stroke(.white.opacity(0.1), lineWidth: 0.75) }
                        .contentShape(Circle())
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .buttonStyle(.plain)
                .accessibilityLabel("放回磁带")
                .accessibilityIdentifier("album.back")
                .disabled(!interactive)
                .padding(.leading, 21)
                .padding(.top, 3)
                .opacity(ready ? 1 : 0)
                .allowsHitTesting(interactive)
                .accessibilityHidden(!interactive)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            // Paint behind the safe area after foreground layout. Clipping an
            // ignoresSafeArea child here exposed the shelf's gray strip above it.
            .background {
                background.opacity(ready ? 1 : 0)
            }
        }
    }

    private func floatingCase(in size: CGSize) -> some View {
        let pose = OneTapeAlbumOpeningPose(stage: openingStage, viewport: size,
                                          origin: openingOrigin, pitch: openingPitch, layout: openingLayout)
        return Group {
            if openingLayout == .shelf {
                OneTapeSpatialCase(collection: collection, artwork: artwork, angle: pose.angle)
            } else {
                OneTapeCaseArtwork(collection: collection, artwork: artwork, layout: openingLayout)
            }
        }
            .frame(width: pose.frame.width, height: pose.frame.height)
            .position(x: pose.frame.midX, y: pose.frame.midY)
            .opacity(ready ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var background: some View {
        ZStack {
            Color.black
            if let artwork {
                Image(uiImage: artwork).resizable().scaledToFill()
                    .scaleEffect(1.2)
                    .blur(radius: 75).opacity(0.58)
                    .overlay(.black.opacity(0.45))
            }
            LinearGradient(colors: [palette.atmosphere.opacity(0.7), .black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func controls(scale: CGFloat) -> some View {
        HStack(spacing: 12 * scale) {
            Button {
                if isCurrentCollection { onTogglePlayback() } else { onPlay(0, false) }
            } label: {
                Label {
                    Text(isCurrentCollection && isPlaying ? "暂停" : "播放")
                } icon: {
                    Image(systemName: isCurrentCollection && isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15.5 * scale, weight: .bold))
                }
                    .frame(maxWidth: .infinity).frame(height: 48 * scale)
                    .background(Color(red: 0.90, green: 0.30, blue: 0), in: Capsule())
            }
            .accessibilityIdentifier("album.play")
            Button { onPlay(0, true) } label: {
                Label {
                    Text("随机播放")
                } icon: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 15.5 * scale, weight: .bold))
                }
                    .frame(maxWidth: .infinity).frame(height: 48 * scale)
                    .background(.black.opacity(0.12), in: Capsule())
                    .overlay { Capsule().stroke(.white.opacity(0.15), lineWidth: 0.9) }
            }
            .accessibilityIdentifier("album.shuffle")
        }
        .font(.system(size: 17 * scale, weight: .bold))
        .foregroundStyle(.white.opacity(0.9))
        .buttonStyle(.plain)
        .disabled(tracks.isEmpty || !interactive)
    }

    private func activateSong(_ track: Track, index: Int) {
        guard interactive else { return }
        // The selected identity toggles the existing engine without replacing
        // its queue or elapsed time; other rows select through the shared store.
        if track.id == currentTrackID { onTogglePlayback() }
        else { onPlay(index, false) }
    }

    private func song(_ track: Track, index: Int, scale: CGFloat) -> some View {
        let current = currentTrackID == track.id
        let favourite = favourites.contains(track.id)
        let showArtist = collection.kind == .playlist || track.artist != collection.subtitle
        let actionHint = current ? (isPlaying ? "轻点暂停" : "轻点继续播放") : "轻点播放"
        return Button {
            activateSong(track, index: index)
        } label: {
            HStack(spacing: 18 * scale) {
                Group {
                    if current {
                        OneTapeSongPlaybackIcon(isPlaying: isPlaying, isActive: isActive && interactive)
                            .frame(width: 38 * scale, height: 31 * scale)
                    } else {
                        Text(String(format: "%02d", index + 1))
                            .font(.custom("GeistMono-Regular", size: 12 * scale))
                    }
                }
                .foregroundStyle(.white.opacity(current ? (isPlaying ? 0.92 : 0.48) : 0.24))
                .frame(width: current ? 45 * scale : 20 * scale)
                VStack(alignment: .leading, spacing: 3 * scale) {
                    Text(track.title)
                        .font(.system(size: (current ? 20 : 15) * scale,
                                      weight: current ? .bold : .regular))
                        .foregroundStyle(.white.opacity(current ? 0.97 : 0.67))
                        .lineLimit(1)
                    if showArtist {
                        Text(track.artist).font(.system(size: 12 * scale))
                            .foregroundStyle(.white.opacity(0.36)).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(MediaTime.label(track.duration))
                    .font(.custom("GeistMono-Regular", size: 12 * scale))
                    .foregroundStyle(.white.opacity(0.43))
            }
            .frame(minHeight: (showArtist ? 64.3 : 50) * scale)
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.05)).frame(height: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(favourite ? "取消收藏" : "收藏到此设备", systemImage: favourite ? "heart.slash" : "heart") {
                onToggleFavourite(track)
            }
            .accessibilityIdentifier("album.favourite.\(index)")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(format: "%02d", index + 1))、\(track.title)、\(showArtist ? track.artist + "、" : "")\(MediaTime.label(track.duration))")
        .accessibilityValue(([current ? (isPlaying ? "正在播放" : "已暂停") : nil,
                              favourite ? "已收藏到此设备" : nil].compactMap { $0 }).joined(separator: "，"))
        .accessibilityHint("\(actionHint)，长按可\(favourite ? "取消收藏" : "收藏到此设备")")
        .accessibilityAddTraits(current ? [.isSelected] : [])
        .accessibilityIdentifier("album.song.\(index)")
        .disabled(!interactive)
        .accessibilityAction(named: favourite ? "取消收藏" : "收藏到此设备") {
            if interactive { onToggleFavourite(track) }
        }
    }
}
