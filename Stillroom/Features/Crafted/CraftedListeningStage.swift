import SwiftUI

/// Album artwork and sleeve text are rasterized only on edition/side change. Core Animation owns
/// the local decorative rotation, so an idle desk does not redraw Canvas at a display-rate timer.
struct CraftedListeningStage: View {
    let record: CraftedRecord
    let image: UIImage?
    let side: CraftedSide
    var fraction: Double? = nil
    let running: Bool
    let raised: Bool
    let back: Bool
    let reducedMotion: Bool
    @State private var texture: UIImage?
    @State private var printedSide: CraftedSide = .a
    @State private var flipAngle: Double = 0
    @State private var arrived = false
    @State private var placed = false
    @State private var flipping = false
    private var editionKey: String { "\(record.id)|\(record.updatedAt)|\(side.rawValue)|\(image?.hash ?? 0)" }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                CraftedSleeveFlipView(record: record, image: image, angle: back ? 180 : 0)
                    .frame(width: width * (back ? 0.88 : 0.69), height: width * (back ? 0.88 : 0.69))
                    .rotationEffect(.degrees(back ? 0 : -7)).offset(x: width * 0.025, y: width * 0.04)
                    .shadow(color: .black.opacity(0.4), radius: 14, y: 12)
                    .zIndex(back ? 2 : 0)
                ZStack {
                    if let texture { CompositedRecordSurface(image: texture, running: running) }
                    else { CraftedDiscArtwork(record: record, image: image, side: printedSide) }
                }.frame(width: width * 0.84, height: width * 0.84)
                    .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                    .offset(x: width * (arrived ? 0.07 : 0.39), y: width * 0.14)
                    .opacity(back ? 0.2 : arrived ? 1 : 0)
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 12)
                OrbitTonearm(fraction: fraction, raised: raised || !placed || flipping, reducedMotion: reducedMotion)
                    .frame(width: width * 0.26, height: width * 0.26 * 330 / 120)
                    .offset(x: width * 0.65, y: width * 0.07)
                    .opacity(back ? 0.2 : 1)
            }.frame(width: width, height: width, alignment: .topLeading).clipped()
        }.task(id: record.id) {
            if reducedMotion { arrived = true; placed = true; return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) { arrived = true }
            // This delays only the drawn needle. Audio already obeys the latest playback intent.
            do { try await Task.sleep(for: .milliseconds(480)) } catch { return }
            guard !Task.isCancelled else { return }
            placed = true
        }.task(id: editionKey) {
            let changed = texture != nil && printedSide != side
            if changed && !reducedMotion {
                flipping = true
                withAnimation(.easeIn(duration: 0.18)) { flipAngle = 88 }
                do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            printedSide = side
            let renderer = ImageRenderer(content: CraftedDiscArtwork(record: record, image: image, side: side).frame(width: 512, height: 512))
            renderer.scale = 1; texture = renderer.uiImage
            if changed && !reducedMotion {
                flipAngle = -88
                withAnimation(.easeOut(duration: 0.24)) { flipAngle = 0 }
                do { try await Task.sleep(for: .milliseconds(240)) } catch { return }
                flipping = false
            } else { flipAngle = 0; flipping = false }
        }.accessibilityHidden(true)
    }
}

private struct CraftedDiscArtwork: View {
    let record: CraftedRecord
    let image: UIImage?
    let side: CraftedSide
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                Circle().fill(Color(white: 0.035)).overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.7))
                Canvas { context, size in
                    for index in 0..<54 {
                        let inset = width * (0.03 + Double(index) * 0.0059)
                        context.stroke(Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)), with: .color(.white.opacity(index % 4 == 0 ? 0.16 : 0.07)), lineWidth: 0.55)
                    }
                }
                Circle().fill(CraftStyle.color(record.color)).frame(width: width * 0.34)
                Text("PRIVATE PRESS").font(CraftStyle.caption(width * 0.015)).tracking(width * 0.005)
                    .foregroundStyle(.white).offset(y: -width * 0.12)
                Text(record.title).font(.system(size: width * 0.033, weight: .semibold, design: .serif))
                    .lineLimit(2).minimumScaleFactor(0.5).multilineTextAlignment(.center)
                    .frame(width: width * 0.26).foregroundStyle(.white).offset(y: -width * 0.065)
                Text(side.label).font(CraftStyle.caption(width * 0.024)).foregroundStyle(.white).offset(y: width * 0.08)
                Circle().fill(.black).frame(width: width * 0.031).overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.6))
            }.frame(width: width, height: width)
        }.aspectRatio(1, contentMode: .fit)
    }
}
