import SwiftUI

/// The sleeve is rendered from a saved record or an editor draft, never from audio or file state.
/// Ratios below are in the sleeve's logical square, so thumbnails and the full-size print agree.
struct CraftedSleeveView: View {
    let record: CraftedRecord
    var image: UIImage? = nil
    var back = false

    private var title: String { record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "给这一刻，\n起个名字。" : record.title }
    private var ink: Color { CraftStyle.color(record.color) }

    var body: some View {
        GeometryReader { geometry in
            // Keyboard and presentation transitions may briefly collapse a host. The square's
            // drawing dimensions are logical points; a missing proposal is not a printable size.
            let side = geometry.size.width.isFinite ? max(0, geometry.size.width) : 0
            if side > 0 {
                ZStack(alignment: .leading) {
                    CraftStyle.paper
                    if back { reverse(side: side) }
                    else {
                        switch record.design {
                        case .typographic: letterpress(side: side)
                        case .photo: photographic(side: side)
                        case .split: splitPrint(side: side)
                        }
                    }
                    // A narrow folded spine and uncoated stock grain remain static during playback.
                    Rectangle().fill(.black.opacity(0.12)).frame(width: side * 0.014)
                    Rectangle().fill(.white.opacity(0.45)).frame(width: side * 0.004).offset(x: side * 0.015)
                    stockGrain(side: side).allowsHitTesting(false)
                    Rectangle().strokeBorder(.black.opacity(0.10), lineWidth: 0.75)
                }.frame(width: side, height: side).clipped()
            }
        }.aspectRatio(1, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(record.title.isEmpty ? "未命名唱片" : record.title)，封套\(back ? "背面" : "正面")")
    }

    private func brand(_ side: CGFloat, color: Color) -> some View {
        HStack(alignment: .top) {
            Text("STILLROOM\nPRIVATE PRESS").font(CraftStyle.caption(max(6, side * 0.023))).lineSpacing(side * 0.006).tracking(side * 0.003)
            Spacer(minLength: 4)
            Image(systemName: "asterisk").font(.system(size: side * 0.055, weight: .light))
        }.foregroundStyle(color)
    }

    private func letterpress(side: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Circle().strokeBorder(ink.opacity(0.15), lineWidth: side * 0.024)
                .frame(width: side * 0.76, height: side * 0.76).offset(x: side * 0.47, y: side * 0.47)
            Circle().fill(ink).frame(width: side * 0.43, height: side * 0.43).offset(x: side * 0.65, y: side * 0.65)
            VStack(alignment: .leading, spacing: 0) {
                brand(side, color: ink)
                Spacer(minLength: 0)
                Text(title).font(.system(size: side * 0.133, weight: .bold, design: .serif))
                    .tracking(-side * 0.003).lineSpacing(side * 0.015).lineLimit(4).minimumScaleFactor(0.45)
                    .frame(maxWidth: side * 0.8, alignment: .leading).foregroundStyle(ink)
                Spacer(minLength: 0)
                footer(side: side, color: ink)
            }.padding(side * 0.085)
        }
    }

    private func photographic(side: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(uiImage: image).resizable().scaledToFill().frame(width: side, height: side).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
            } else {
                ink
                Circle().strokeBorder(CraftStyle.paper.opacity(0.5), lineWidth: 1)
                    .frame(width: side * 0.48, height: side * 0.48).position(x: side * 0.5, y: side * 0.44)
                Image(systemName: "viewfinder").font(.system(size: side * 0.14, weight: .ultraLight))
                    .foregroundStyle(CraftStyle.paper.opacity(0.75)).position(x: side * 0.5, y: side * 0.44)
            }
            VStack(alignment: .leading, spacing: side * 0.025) {
                brand(side, color: CraftStyle.paper)
                Spacer(minLength: 0)
                Text(title).font(.system(size: side * 0.10, weight: .semibold, design: .serif))
                    .lineLimit(3).minimumScaleFactor(0.5).foregroundStyle(CraftStyle.paper)
                footer(side: side, color: CraftStyle.paper)
            }.padding(side * 0.085)
        }
    }

    private func splitPrint(side: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ink.frame(height: side * 0.65)
            Circle().fill(CraftStyle.paper).frame(width: side * 0.44, height: side * 0.44)
                .offset(x: side * 0.66, y: side * 0.45)
            VStack(alignment: .leading, spacing: 0) {
                brand(side, color: CraftStyle.paper)
                Spacer(minLength: 0)
                Text(title).font(.system(size: side * 0.125, weight: .black))
                    .lineLimit(3).minimumScaleFactor(0.5).foregroundStyle(CraftStyle.paper)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }.padding(side * 0.085).frame(height: side * 0.65)
            VStack(alignment: .leading, spacing: side * 0.025) {
                Text("A / B").font(.system(size: side * 0.12, weight: .light, design: .monospaced)).foregroundStyle(ink)
                footer(side: side, color: ink)
            }.padding(.horizontal, side * 0.085).offset(y: side * 0.72)
        }
    }

    private func reverse(side: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: side * 0.05) {
            brand(side, color: ink)
            Rectangle().fill(ink.opacity(0.3)).frame(height: 0.75)
            Text(record.dedication.isEmpty ? "封套背面，\n留给你想说的话。" : record.dedication)
                .font(.system(size: side * 0.043, weight: .regular, design: .serif)).lineSpacing(side * 0.018)
                .lineLimit(9).minimumScaleFactor(0.5).foregroundStyle(ink)
            Spacer(minLength: 0)
            HStack(alignment: .top) {
                sideMark("A", count: record.sideA.count, size: side)
                Spacer()
                sideMark("B", count: record.sideB.count, size: side)
            }.foregroundStyle(ink)
            Rectangle().fill(ink.opacity(0.3)).frame(height: 0.75)
            footer(side: side, color: ink)
        }.padding(side * 0.085)
    }

    private func sideMark(_ label: String, count: Int, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.025) {
            Text(label).font(.system(size: size * 0.13, weight: .light, design: .serif))
            Text("\(count) TRACKS").font(CraftStyle.caption(max(6, size * 0.023)))
        }
    }

    private func footer(side: CGFloat, color: Color) -> some View {
        HStack(alignment: .bottom) {
            Text("A · \(record.sideA.count)   B · \(record.sideB.count)").font(CraftStyle.caption(max(6, side * 0.024)))
            Spacer(minLength: 4)
            Text("SR / " + record.id.prefix(6).uppercased()).font(CraftStyle.caption(max(5, side * 0.019)))
        }.foregroundStyle(color)
    }

    private func stockGrain(side: CGFloat) -> some View {
        Canvas { context, size in
            for index in 0..<70 {
                let x = CGFloat((index * 173 + 29) % 997) / 997 * size.width
                let y = CGFloat((index * 97 + 47) % 991) / 991 * size.height
                context.fill(Path(CGRect(x: x, y: y, width: max(0.4, side * 0.002), height: 0.5)), with: .color(.black.opacity(0.06)))
            }
        }.blendMode(.multiply)
    }
}

/// Visibility changes only as the animated leaf passes edge-on, avoiding a mirrored back face.
struct CraftedSleeveFlipView: View, Animatable {
    let record: CraftedRecord
    var image: UIImage?
    var angle: Double
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    var body: some View {
        CraftedSleeveView(record: record, image: image, back: angle > 90)
            .rotation3DEffect(.degrees(angle > 90 ? angle - 180 : angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}
