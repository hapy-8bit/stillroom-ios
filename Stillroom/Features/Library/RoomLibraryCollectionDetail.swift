import SwiftUI

/// Shared album/smart-collection content. The parent supplies actual membership and queue order;
/// changing the navigation page never starts audio by itself.
struct RoomLibraryCollectionDetail: View {
    let title: String
    let subtitle: String
    let tracks: [Track]
    let representative: Track?
    let cover: UIImage?
    let symbol: String
    let smart: Bool
    let artworks: [String: UIImage]
    let currentID: String
    let playing: Bool
    let libraryReady: Bool
    let onPlay: (Track, [Track]) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 18) {
                    if let representative {
                        ArtworkView(track: representative, image: cover)
                            .frame(width: 104, height: 104).clipShape(RoundedRectangle(cornerRadius: 4))
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: symbol).font(.system(size: 32, weight: .light))
                            .frame(width: 104, height: 104).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title).font(.title3.weight(.semibold)).accessibilityIdentifier("room.library.detail.title")
                        Text(subtitle).font(.subheadline).foregroundStyle(RoomLibrarySurface.secondary)
                        Text("\(smart ? "智能歌单 · " : "")\(tracks.count) 首")
                            .font(.caption).foregroundStyle(RoomLibrarySurface.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Button {
                    if let first = tracks.first { onPlay(first, tracks) }
                } label: {
                    Label("播放", systemImage: "play.fill").font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(.white, in: Capsule()).foregroundStyle(.black)
                }
                .buttonStyle(.plain).disabled(!libraryReady || tracks.isEmpty)
                .accessibilityLabel("播放" + title).accessibilityIdentifier("room.library.detail.play")
                if tracks.isEmpty {
                    Text("这里还没有音乐。\n\(smart ? subtitle : "导入音乐后，歌曲会显示在这里。")")
                        .font(.body).foregroundStyle(RoomLibrarySurface.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
                        .multilineTextAlignment(.center).accessibilityIdentifier("room.library.detail.empty")
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(tracks) { track in
                            RoomLibrarySongRow(track: track, artwork: artworks[track.id], currentID: currentID,
                                               playing: playing) { onPlay(track, tracks) }
                                .disabled(!libraryReady)
                            Divider().overlay(.white.opacity(0.10))
                        }
                    }
                }
                if let representative, !smart, BundledAlbumCatalog.isReferenceID(representative.id) {
                    ReferenceAlbumCreditView(track: representative)
                }
            }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(RoomLibrarySurface.background.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(RoomLibrarySurface.background, for: .navigationBar)
        .accessibilityElement(children: .contain).accessibilityIdentifier("room.library.detail")
    }
}

struct RoomLibrarySongRow: View {
    let track: Track
    let artwork: UIImage?
    let currentID: String
    let playing: Bool
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                ArtworkView(track: track, image: artwork)
                    .frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 3))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title).font(.body).foregroundStyle(.white).lineLimit(2)
                    Text(track.artist).font(.caption).foregroundStyle(RoomLibrarySurface.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                if track.id == currentID && playing {
                    Image(systemName: "waveform").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                        .accessibilityHidden(true)
                }
                Text(track.duration > 0 ? MediaTime.label(track.duration) : "—:—")
                    .font(.caption.monospacedDigit()).foregroundStyle(RoomLibrarySurface.secondary)
            }
            .padding(.vertical, 10).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("播放 " + track.title + "，" + track.artist)
        .accessibilityValue(track.id == currentID && playing ? "正在播放" : "")
        .accessibilityIdentifier("room.library.track." + track.id)
    }
}
