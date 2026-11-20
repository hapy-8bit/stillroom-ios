import SwiftUI

struct LyricsPanel: View {
    let lines: [LyricLine]
    let plainText: String
    let activeIndex: Int?
    let isDemo: Bool
    let onSeek: (Double) -> Void
    @State private var following = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionEyebrow(text: "THE INNER SLEEVE")
                Spacer()
                if isDemo { Text("文字演示 · 器乐无演唱").font(.system(size: 9)).foregroundStyle(RoomStyle.muted) }
            }
            if !lines.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 27) {
                            ForEach(lines) { line in
                                Button { onSeek(line.time); following = true } label: {
                                    Text(line.text).font(RoomStyle.serif(25)).multilineTextAlignment(.leading)
                                        .foregroundStyle(activeIndex == line.id ? RoomStyle.paper : RoomStyle.muted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain).id(line.id)
                            }
                        }.padding(.vertical, 70)
                    }.scrollIndicators(.hidden)
                        .onScrollPhaseChange { _, phase in if phase == .interacting { following = false } }
                        .onChange(of: activeIndex) { _, index in
                            if following, let index { withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(index, anchor: .center) } }
                        }
                        .onAppear { if let activeIndex { proxy.scrollTo(activeIndex, anchor: .center) } }
                    if !following {
                        Button("跟随当前歌词") {
                            following = true
                            if let activeIndex { withAnimation { proxy.scrollTo(activeIndex, anchor: .center) } }
                        }.font(.caption).foregroundStyle(RoomStyle.accent)
                    }
                }
            } else if !plainText.isEmpty {
                ScrollView { Text(plainText).font(RoomStyle.serif(23)).lineSpacing(15).padding(.vertical, 30) }
            } else {
                VStack(alignment: .leading, spacing: 15) {
                    Spacer()
                    Text("让音乐自己说话").font(RoomStyle.serif(28))
                    Text("这首音乐还没有歌词。\n可从右上角菜单导入 LRC 或文本歌词。")
                        .font(.system(size: 12)).lineSpacing(7).foregroundStyle(RoomStyle.secondary)
                    Spacer()
                }
            }
        }
    }
}
