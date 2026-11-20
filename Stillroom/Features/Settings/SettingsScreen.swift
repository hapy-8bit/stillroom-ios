import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var player: PlayerStore
    var onClose: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                RoomBackground()
                Form {
                    Section {
                        Button { player.showingImport = true } label: {
                            settingsLabel("导入本地音乐", detail: player.importing ? "正在保存音乐…" : "从文件 App 选择音频", icon: "arrow.down.doc")
                        }.disabled(!player.libraryReady).accessibilityIdentifier("settings.import")
                        Button { player.importRequest = .lyrics(trackID: player.current.id) } label: {
                            settingsLabel("导入歌词", detail: "关联到《\(player.current.title)》", icon: "text.alignleft")
                        }.disabled(player.importing).accessibilityIdentifier("settings.lyrics")
                        Button { player.importRequest = .cover(trackID: player.current.id, album: false) } label: {
                            settingsLabel("导入当前歌曲封面", detail: "仅此曲；保留专辑封套", icon: "photo")
                        }.disabled(player.importing).accessibilityIdentifier("settings.cover")
                    } header: { Text("音乐与歌词") } footer: {
                        Text("当前有 \(player.libraryTracks.count) 首音乐。导入文件会复制到应用内，原文件不受影响。支持系统可解码的 MP3、M4A、AAC、WAV 等音频；不支持受 DRM 保护的订阅下载。")
                    }
                    Section {
                        Toggle(isOn: $player.reducedMotion) {
                            settingsLabel("减少动效", detail: "停止唱片旋转，使用淡入淡出", icon: "circle.dotted")
                        }.accessibilityIdentifier("settings.reduceMotion")
                    } header: { Text("显示与动效") } footer: {
                        Text("也会遵循 iPhone 的系统“减弱动态效果”设置。音频播放与进度控制保持可用。")
                    }
                    Section {
                        settingsLabel("后台与锁屏播放", detail: "离开 App 继续听，锁屏也能控制播放", icon: "lock.rectangle")
                        settingsLabel("只在本机", detail: "不上传音乐，无需注册账号", icon: "iphone")
                    } header: { Text("听音体验") }
                    Section {
                        VStack(alignment: .leading, spacing: 13) {
                            Text("Stillroom").font(.custom("Damion", size: 38)).foregroundStyle(RoomStyle.paper)
                            Text("给音乐一个房间，也给自己一点时间。").font(.system(size: 12)).foregroundStyle(RoomStyle.secondary)
                            Text("iOS 原生体验版 · " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"))
                                .font(RoomStyle.caption(10)).foregroundStyle(RoomStyle.muted)
                            Text("随附 \(BundledAlbumCatalog.tracks.count) 张真实专辑的选曲，音乐来源与署名见下方。")
                                .font(.system(size: 10)).foregroundStyle(RoomStyle.muted).lineSpacing(5)
                        }.padding(.vertical, 12)
                    } header: { Text("关于") }
                    Section("音乐来源") {
                        ForEach(BundledAlbumCatalog.tracks) { track in ReferenceAlbumCreditView(track: track) }
                    }
                }.scrollContentBackground(.hidden).foregroundStyle(RoomStyle.paper)
                    .listRowSpacing(4).accessibilityIdentifier("settings.form")
            }.navigationTitle("设置").toolbarBackground(.hidden, for: .navigationBar)
                .toolbar { if let onClose { ToolbarItem(placement: .topBarLeading) {
                    Button("返回", action: onClose).accessibilityIdentifier("settings.close")
                } } }
        }
    }

    private func settingsLabel(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 19, weight: .light)).foregroundStyle(RoomStyle.accent).frame(width: 27)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 15)).foregroundStyle(RoomStyle.paper)
                Text(detail).font(.system(size: 10)).foregroundStyle(RoomStyle.secondary)
            }.padding(.vertical, 7)
        }
    }
}

