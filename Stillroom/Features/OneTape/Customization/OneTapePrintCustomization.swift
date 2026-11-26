import SwiftUI

struct OneTapePrintCustomization: View {
    @Binding var appearance: OneTapeAppearance
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var drawings: [OneTapeCustomDrawing] = []
    var artworks: [OneTapeCustomArtwork] = []
    var thumbnailForDrawing: (OneTapeCustomDrawing) -> UIImage? = { _ in nil }
    var titleForDrawing: (OneTapeCustomDrawing) -> String = { _ in "画作" }
    var thumbnailForArtwork: (OneTapeCustomArtwork) -> UIImage? = { _ in nil }
    var titleForArtwork: (OneTapeCustomArtwork) -> String = { _ in "照片" }
    var onStartNewDrawing: () -> Void = {}
    var onStartHalftone: () -> Void = {}
    var onEditDrawing: (OneTapeCustomDrawing) -> Void = { _ in }
    var onToggleInkMode: (OneTapeCustomDrawing) -> Void = { _ in }
    var onDeleteDrawing: (OneTapeCustomDrawing) -> Void = { _ in }
    var onEditArtwork: (OneTapeCustomArtwork) -> Void = { _ in }
    var onReprintArtwork: (OneTapeCustomArtwork) -> Void = { _ in }
    var onDeleteArtwork: (OneTapeCustomArtwork) -> Void = { _ in }
    var onGetPaper: () -> Void = {}
    var onImportFromPhotos: () -> Void = {}
    var onImportFromFiles: () -> Void = {}

    @State private var pendingDeleteDrawing: OneTapeCustomDrawing?
    @State private var pendingDeleteArtwork: OneTapeCustomArtwork?

    private var displayedDoodles: [OneTapeAppearance.DoodleStyle] {
        OneTapeDoodleCatalog.supportedStyles(for: appearance.tapeStyle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            drawingTools
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("印花")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(displayedDoodles) { style in
                        OneTapeCustomizationTile(
                            title: style.customizationTitle,
                            selected: style == .none
                                ? (appearance.doodleStyle == .none
                                    && appearance.customDrawingID == nil
                                    && appearance.customArtworkID == nil)
                                : appearance.doodleStyle == style,
                            studioMarker: style != .none,
                            identifier: "customization.doodle.\(style.rawValue)"
                        ) {
                            var next = appearance
                            next.selectIllustration(style)
                            appearance = next
                        } thumbnail: {
                            if style == .none {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 39.0 / 255.0, green: 39.0 / 255.0, blue: 44.0 / 255.0),
                                                Color(red: 29.0 / 255.0, green: 29.0 / 255.0, blue: 33.0 / 255.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            } else {
                                ZStack {
                                    Color(red: 29.0 / 255.0, green: 29.0 / 255.0, blue: 33.0 / 255.0)
                                    Image(style.customizationThumbnailAsset)
                                        .resizable()
                                        .interpolation(.high)
                                        .aspectRatio(contentMode: .fit)
                                }
                            }
                        }
                    }
                }
            }
            OneTapeSurfaceEffectsSection(appearance: $appearance)
        }
        .alert("删除这幅画？", isPresented: Binding(
            get: { pendingDeleteDrawing != nil },
            set: { if !$0 { pendingDeleteDrawing = nil } }
        )) {
            Button("取消", role: .cancel) {
                pendingDeleteDrawing = nil
            }
            Button("删除", role: .destructive) {
                if let target = pendingDeleteDrawing {
                    pendingDeleteDrawing = nil
                    onDeleteDrawing(target)
                }
            }
        } message: {
            Text("你导入的原图会保留在原处。")
        }
        .alert("删除这张照片印花？", isPresented: Binding(
            get: { pendingDeleteArtwork != nil },
            set: { if !$0 { pendingDeleteArtwork = nil } }
        )) {
            Button("取消", role: .cancel) {
                pendingDeleteArtwork = nil
            }
            Button("删除", role: .destructive) {
                if let target = pendingDeleteArtwork {
                    pendingDeleteArtwork = nil
                    onDeleteArtwork(target)
                }
            }
        } message: {
            Text("照片仍会保留在你的图库中。")
        }
    }

    private var drawingTools: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        return VStack(alignment: .leading, spacing: 14) {
            sectionTitle("你的绘画与照片")
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                drawingToolButton("画画", identifier: "customization.draw", action: onStartNewDrawing) {
                    OneTapePencilSquiggleIcon()
                        .frame(width: 34, height: 34)
                }
                drawingToolButton("网点", identifier: "customization.halftone", action: onStartHalftone) {
                    OneTapeHalftoneIcon()
                        .frame(width: 30, height: 30)
                }
                ForEach(drawings) { item in
                    customDrawingTile(item)
                }
                ForEach(artworks) { item in
                    customArtworkTile(item)
                }
            }
            Text("在磁带上画画，或印上网点照片。")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func customArtworkTile(_ item: OneTapeCustomArtwork) -> some View {
        let selected = appearance.customArtworkID == item.id
        let title = titleForArtwork(item)
        let thumb = thumbnailForArtwork(item)
        let matchesCurrentShell = item.shellRawValue == appearance.tapeStyle.rawValue
        let usesDarkSurface = appearance.tapeStyle.usesLightInk && item.recipe.primaryInk == .tapeInk
        return OneTapeCustomizationTile(
            title: title,
            selected: selected,
            studioMarker: true,
            identifier: "customization.customArtwork.\(item.id.uuidString)"
        ) {
            var next = appearance
            next.selectCustomArtwork(item.id)
            appearance = next
        } thumbnail: {
            cassetteMaskedTileThumbnail(usesDarkPaper: usesDarkSurface) {
                if let thumb {
                    Image(uiImage: thumb)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                }
            }
        }
        .contextMenu {
            if !matchesCurrentShell {
                Button {
                    onReprintArtwork(item)
                } label: {
                    Label("为这盘磁带重新印制", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            Button {
                onEditArtwork(item)
            } label: {
                Label("编辑", systemImage: "slider.horizontal.3")
            }
            Button(role: .destructive) {
                pendingDeleteArtwork = item
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func customDrawingTile(_ item: OneTapeCustomDrawing) -> some View {
        let selected = appearance.customDrawingID == item.id
        let title = titleForDrawing(item)
        let thumb = thumbnailForDrawing(item)
        return OneTapeCustomizationTile(
            title: title,
            selected: selected,
            studioMarker: true,
            identifier: "customization.customDrawing.\(item.id.uuidString)"
        ) {
            var next = appearance
            next.selectCustomDrawing(item.id)
            appearance = next
        } thumbnail: {
            customDrawingThumbnail(thumb: thumb, inkMode: item.inkMode)
        }
        .contextMenu {
            Button {
                onEditDrawing(item)
            } label: {
                Label(item.canEditStrokes ? "编辑" : "在上面画", systemImage: "pencil.and.scribble")
            }
            Button {
                onToggleInkMode(item)
            } label: {
                Label(item.inkMode == .tapeInk ? "改为保留原色" : "改为使用磁带墨色",
                      systemImage: "paintpalette")
            }
            Button(role: .destructive) {
                pendingDeleteDrawing = item
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func customDrawingThumbnail(thumb: UIImage?, inkMode: OneTapeDrawingInkMode) -> some View {
        let usesDarkPaper = inkMode == .tapeInk && appearance.tapeStyle.usesLightInk
        cassetteMaskedTileThumbnail(usesDarkPaper: usesDarkPaper) {
            if let thumb {
                if inkMode == .tapeInk {
                    Image(uiImage: thumb)
                        .renderingMode(.template)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .foregroundStyle(
                            appearance.tapeStyle.usesLightInk
                                ? Color(red: 0.93, green: 0.91, blue: 0.87)
                                : Color(red: 0.14, green: 0.14, blue: 0.15)
                        )
                } else {
                    Image(uiImage: thumb)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                }
            }
        }
    }

    private func cassetteMaskedTileThumbnail<Overlay: View>(
        usesDarkPaper: Bool,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) -> some View {
        GeometryReader { proxy in
            let scale = min((proxy.size.width - 8) / 576.0, (proxy.size.height - 6) / 376.33)
            let paperColor = usesDarkPaper
                ? Color(white: 0.19)
                : Color(red: 0.945, green: 0.933, blue: 0.902)
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(white: 0.115))
                ZStack {
                    paperColor
                    overlay()
                        .frame(width: 576, height: 376.33)
                }
                .frame(width: 576, height: 376.33)
                .mask {
                    OneTapeShellPrintMask(tapeStyle: appearance.tapeStyle)
                        .frame(width: 376.33, height: 576)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 576, height: 376.33)
                }
                .scaleEffect(scale)
                .frame(width: 576 * scale, height: 376.33 * scale)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func drawingToolButton<Icon: View>(
        _ title: String,
        identifier: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                icon()
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .frame(height: 63)
                    .background(Color(white: 0.135), in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.08), lineWidth: 0.8) }
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))
            .accessibilityAddTraits(.isHeader)
    }
}

private struct OneTapePencilSquiggleIcon: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 34.0
            let stroke = StrokeStyle(lineWidth: 1.75 * s, lineCap: .round, lineJoin: .round)
            let ink = Color.white.opacity(0.84)

            // 45° diagonal pencil pointing down-left toward the squiggle start.
            var pencil = Path()
            pencil.move(to: CGPoint(x: 6.8 * s, y: 24.4 * s))
            pencil.addLine(to: CGPoint(x: 8.6 * s, y: 18.2 * s))
            pencil.addLine(to: CGPoint(x: 21.8 * s, y: 5.0 * s))
            pencil.addLine(to: CGPoint(x: 26.2 * s, y: 9.4 * s))
            pencil.addLine(to: CGPoint(x: 13.0 * s, y: 22.6 * s))
            pencil.closeSubpath()
            // Eraser collar & tip collar lines.
            pencil.move(to: CGPoint(x: 19.2 * s, y: 7.6 * s))
            pencil.addLine(to: CGPoint(x: 23.6 * s, y: 12.0 * s))
            pencil.move(to: CGPoint(x: 8.8 * s, y: 18.4 * s))
            pencil.addLine(to: CGPoint(x: 12.8 * s, y: 22.4 * s))
            context.stroke(pencil, with: .color(ink), style: stroke)

            // Wavy hand-drawn squiggle along bottom edge matching Mirror 01 icon.
            var squiggle = Path()
            squiggle.move(to: CGPoint(x: 10.6 * s, y: 26.5 * s))
            squiggle.addCurve(
                to: CGPoint(x: 14.5 * s, y: 26.5 * s),
                control1: CGPoint(x: 11.9 * s, y: 24.5 * s),
                control2: CGPoint(x: 13.2 * s, y: 28.5 * s)
            )
            squiggle.addCurve(
                to: CGPoint(x: 18.5 * s, y: 26.5 * s),
                control1: CGPoint(x: 15.8 * s, y: 24.5 * s),
                control2: CGPoint(x: 17.2 * s, y: 28.5 * s)
            )
            squiggle.addCurve(
                to: CGPoint(x: 22.5 * s, y: 26.5 * s),
                control1: CGPoint(x: 19.8 * s, y: 24.5 * s),
                control2: CGPoint(x: 21.2 * s, y: 28.5 * s)
            )
            squiggle.addCurve(
                to: CGPoint(x: 26.2 * s, y: 26.2 * s),
                control1: CGPoint(x: 23.8 * s, y: 24.6 * s),
                control2: CGPoint(x: 25.0 * s, y: 27.6 * s)
            )
            context.stroke(squiggle, with: .color(ink), style: stroke)
        }
        .accessibilityHidden(true)
    }
}

private struct OneTapeHalftoneIcon: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            let outerRadius = s * 0.43
            let clipRadius = outerRadius - s * 0.08
            let ink = Color.white.opacity(0.84)

            let ring = Path(ellipseIn: CGRect(
                x: center.x - outerRadius,
                y: center.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            ))
            context.stroke(ring, with: .color(ink), lineWidth: max(1.6, s * 0.068))

            // Tapered clustered halftone dots inside ring (matching HalftoneIcon in Mirror 01).
            let spacing = s * 0.112
            let angle: CGFloat = -0.36
            let cosA = cos(angle)
            let sinA = sin(angle)
            for gy in -4...4 {
                for gx in -4...4 {
                    let ux = CGFloat(gx) * spacing
                    let uy = CGFloat(gy) * spacing
                    let dx = ux * cosA - uy * sinA
                    let dy = ux * sinA + uy * cosA
                    let dist = hypot(dx, dy)
                    guard dist <= clipRadius - s * 0.025 else { continue }

                    // Larger dots toward bottom-left (-x, +y), tapering fine toward upper-right (+x, -y).
                    let gradient = (dx - dy) / max(1, clipRadius * 1.6)
                    let t = min(1, max(0, 0.55 - gradient * 0.48))
                    let dotR = s * (0.015 + t * 0.032)
                    let dot = Path(ellipseIn: CGRect(
                        x: center.x + dx - dotR,
                        y: center.y + dy - dotR,
                        width: dotR * 2,
                        height: dotR * 2
                    ))
                    context.fill(dot, with: .color(ink))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
