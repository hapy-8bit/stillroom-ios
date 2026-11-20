import SwiftUI

/// The page owns the resting expansion. GestureState is only a transient, cancellable drag preview.
struct CollectionFolds: View {
    let localCount: Int
    let albumCount: Int
    let favoriteCount: Int
    let demoCount: Int
    @Binding var expansion: Double
    let reducedMotion: Bool
    let onImport: () -> Void
    let onAlbums: () -> Void
    let onFavorites: () -> Void
    let onSamples: () -> Void
    // GestureState may reset before onEnded commits the resting value. Animate that reset too,
    // so release/cancellation never renders a single frame at the old folded endpoint.
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.42, dampingFraction: 0.86)))
    private var drag: CGFloat = 0

    private let faceHeight = 56.0
    private var travel: Double { faceHeight * 2 }
    private var pose: CollectionFoldPose {
        CollectionFoldPose(CollectionFoldPose.dragged(base: expansion, translation: Double(drag), travel: travel))
    }
    private var values: [(String, Int, String)] {
        [("本地", localCount, "TRACKS"), ("本地专辑", albumCount, "ALBUMS"),
         ("喜欢", favoriteCount, "LOVED"), ("内置试听", demoCount, "SAMPLES")]
    }

    var body: some View {
        VStack(spacing: 0) {
            statistics
            CollectionFoldWings(progress: pose.progress, faceHeight: faceHeight, reducedMotion: reducedMotion,
                                onImport: onImport, onAlbums: onAlbums, onFavorites: onFavorites, onSamples: onSamples)
            Button { settle(expansion < 0.5 ? 1 : 0) } label: {
                HStack(spacing: 7) {
                    Text(expansion < 0.5 ? "下拉展开收藏" : "上推收起")
                    Image(systemName: "chevron.down").rotationEffect(.degrees(180 * pose.progress))
                }.font(.system(size: 9)).tracking(1).foregroundStyle(RoomStyle.secondary)
                    .frame(maxWidth: .infinity).frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel(expansion < 0.5 ? "展开唱片收藏" : "收起唱片收藏")
                .accessibilityIdentifier("home.fold-toggle")
        }
        .contentShape(Rectangle())
        // Starting a drag on the paper manipulates the folds; drags elsewhere still browse the home.
        .highPriorityGesture(DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .updating($drag) { value, state, transaction in
                transaction.animation = nil
                state = value.translation.height
            }
            .onEnded { value in
                settle(CollectionFoldPose.settled(base: expansion, translation: value.translation.height,
                                                  predicted: value.predictedEndTranslation.height, travel: travel))
            })
        .accessibilityElement(children: .contain).accessibilityIdentifier("home.collection-folds")
        .accessibilityValue(expansion < 0.5 ? "已收起" : "已展开")
        .accessibilityAction(named: "展开") { settle(1) }
        .accessibilityAction(named: "收起") { settle(0) }
        .transaction { if reducedMotion { $0.animation = nil } }
    }

    private var statistics: some View {
        HStack(spacing: 0) {
            ForEach(values.indices, id: \.self) { index in
                VStack(spacing: 8) {
                    Text(String(format: "%02d", values[index].1))
                        .font(.system(size: 28, weight: .light, design: .monospaced)).foregroundStyle(RoomStyle.paper)
                    Text(values[index].0).font(.system(size: 10)).foregroundStyle(RoomStyle.secondary)
                    Rectangle().fill(RoomStyle.paper.opacity(0.12)).frame(width: 18, height: 0.5).padding(.top, 5)
                    Text(values[index].2).font(RoomStyle.caption(6)).tracking(1.4).foregroundStyle(RoomStyle.muted)
                }
                .frame(maxWidth: .infinity).frame(height: 126)
                .background {
                    ZStack {
                        LinearGradient(colors: index.isMultiple(of: 2) ?
                            [RoomStyle.surface, RoomStyle.dock, RoomStyle.background] :
                            [RoomStyle.background, RoomStyle.surface, RoomStyle.dock],
                                       startPoint: .leading, endPoint: .trailing)
                        RoomStyle.surface.opacity(pose.progress * 0.75)
                    }
                }
                .overlay(alignment: .leading) {
                    Rectangle().fill(RoomStyle.paper.opacity(0.08)).frame(width: 0.5).padding(.vertical, 9)
                }
                .clipShape(CollectionFoldFace(rising: index.isMultiple(of: 2), depth: 8 * (1 - pose.progress)))
                .accessibilityElement(children: .ignore).accessibilityLabel("\(values[index].0)，\(values[index].1)")
            }
        }.shadow(color: .black.opacity(0.25 * (1 - pose.progress)), radius: 10, y: 10)
    }

    private func settle(_ value: Double) {
        withAnimation(reducedMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) { expansion = value }
    }
}

private struct CollectionFoldFace: Shape {
    let rising: Bool
    var depth: CGFloat
    var animatableData: CGFloat { get { depth } set { depth = newValue } }
    func path(in rect: CGRect) -> Path {
        let left: CGFloat = rising ? 0 : depth
        let right: CGFloat = rising ? depth : 0
        return Path { path in
            path.move(to: CGPoint(x: rect.minX, y: left))
            path.addLine(to: CGPoint(x: rect.maxX, y: right))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth + right))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - depth + left))
            path.closeSubpath()
        }
    }
}
