import SwiftUI

/// Two hinged horizontal faces project into the height occupied by the real page layout.
struct CollectionFoldWings: View {
    let progress: Double
    let faceHeight: Double
    let reducedMotion: Bool
    let onImport: () -> Void
    let onAlbums: () -> Void
    let onFavorites: () -> Void
    let onSamples: () -> Void

    private var pose: CollectionFoldPose { CollectionFoldPose(progress) }

    var body: some View {
        VStack(spacing: 0) {
            face(direction: -1) {
                HStack(spacing: 0) {
                    description("把自己的\n声音收进来")
                    description("从一张\n唱片开始")
                    description("留住想\n再听的歌")
                    description("随附参考\n音乐")
                }
            }
            face(direction: 1) {
                HStack(spacing: 0) {
                    action("导入", symbol: "plus", identifier: "fold.import", onImport)
                    action("唱片架", symbol: "square.stack", identifier: "fold.albums", onAlbums)
                    action("喜欢", symbol: "heart", identifier: "fold.favorites", onFavorites)
                    action("试听", symbol: "play", identifier: "fold.samples", onSamples)
                }
            }
        }
        .opacity(progress > 0.001 ? 1 : 0)
        .clipped().allowsHitTesting(progress > 0.98)
        .accessibilityHidden(progress < 0.98)
    }

    private func face<Content: View>(direction: Double, @ViewBuilder content: () -> Content) -> some View {
        content().frame(height: faceHeight)
            .background(RoomStyle.surface)
            .overlay(alignment: .top) {
                Rectangle().fill(.black.opacity(0.15 + 0.45 * (1 - progress))).frame(height: 0.5)
            }
            .overlay(LinearGradient(colors: [.black.opacity((1 - progress) * 0.45), .clear],
                                    startPoint: direction < 0 ? .top : .bottom,
                                    endPoint: direction < 0 ? .bottom : .top))
            .rotation3DEffect(.degrees(reducedMotion ? 0 : direction * pose.angle),
                              axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0)
            .frame(height: pose.projectedHeight(faceHeight), alignment: .top)
    }

    private func description(_ text: String) -> some View {
        Text(text).font(.system(size: 10)).foregroundStyle(RoomStyle.secondary).lineSpacing(4)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }

    private func action(_ title: String, symbol: String, identifier: String, _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 15, weight: .light))
                Text(title).font(.system(size: 9))
            }.foregroundStyle(RoomStyle.paper).frame(maxWidth: .infinity).frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
    }
}
