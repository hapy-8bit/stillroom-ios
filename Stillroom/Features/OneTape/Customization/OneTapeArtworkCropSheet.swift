import SwiftUI

struct OneTapeArtworkCropSheet: View {
    let sourceImage: UIImage
    let initialCrop: OneTapeNormalizedRect
    let onCancel: () -> Void
    let onApply: (OneTapeNormalizedRect) -> Void

    @State private var crop: OneTapeNormalizedRect
    @State private var dragStartCrop: OneTapeNormalizedRect?

    init(
        sourceImage: UIImage,
        initialCrop: OneTapeNormalizedRect,
        onCancel: @escaping () -> Void,
        onApply: @escaping (OneTapeNormalizedRect) -> Void
    ) {
        self.sourceImage = sourceImage
        self.initialCrop = initialCrop
        self.onCancel = onCancel
        self.onApply = onApply
        _crop = State(initialValue: initialCrop.clamped)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let stageSize = CGSize(
                    width: max(1, proxy.size.width - 32),
                    height: max(1, proxy.size.height - 32)
                )
                let fitted = fittedImageRect(in: CGRect(x: 16, y: 16, width: stageSize.width, height: stageSize.height))
                let box = CGRect(
                    x: fitted.minX + crop.x * fitted.width,
                    y: fitted.minY + crop.y * fitted.height,
                    width: crop.width * fitted.width,
                    height: crop.height * fitted.height
                )

                ZStack(alignment: .topLeading) {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: sourceImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: fitted.width, height: fitted.height)
                        .position(x: fitted.midX, y: fitted.midY)

                    // Dim exterior outside crop box using even-odd cutout.
                    Path { path in
                        path.addRect(fitted)
                        path.addRect(box)
                    }
                    .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)

                    // Crop box frame and corner drag handles.
                    Rectangle()
                        .strokeBorder(.white, lineWidth: 1.5)
                        .frame(width: box.width, height: box.height)
                        .position(x: box.midX, y: box.midY)
                        .contentShape(Rectangle())
                        .gesture(moveGesture(fittedWidth: fitted.width, fittedHeight: fitted.height))

                    cornerHandle(x: box.minX, y: box.minY, dxSign: 1, dySign: 1, fitted: fitted)
                    cornerHandle(x: box.maxX, y: box.minY, dxSign: -1, dySign: 1, fitted: fitted)
                    cornerHandle(x: box.minX, y: box.maxY, dxSign: 1, dySign: -1, fitted: fitted)
                    cornerHandle(x: box.maxX, y: box.maxY, dxSign: -1, dySign: -1, fitted: fitted)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Text("留下你想印出的部分。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.vertical, 8)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("裁剪图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                        .foregroundStyle(.white.opacity(0.8))
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("重置") {
                        crop = .full
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("使用裁剪") {
                        onApply(crop.clamped)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func moveGesture(fittedWidth: CGFloat, fittedHeight: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStartCrop ?? crop
                if dragStartCrop == nil { dragStartCrop = crop }
                let dx = value.translation.width / max(1, fittedWidth)
                let dy = value.translation.height / max(1, fittedHeight)
                crop.x = min(1.0 - start.width, max(0.0, start.x + dx))
                crop.y = min(1.0 - start.height, max(0.0, start.y + dy))
            }
            .onEnded { _ in
                dragStartCrop = nil
            }
    }

    private func cornerHandle(x: CGFloat, y: CGFloat, dxSign: CGFloat, dySign: CGFloat, fitted: CGRect) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 22, height: 22)
            .shadow(color: .black.opacity(0.4), radius: 3)
            .position(x: x, y: y)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStartCrop ?? crop
                        if dragStartCrop == nil { dragStartCrop = crop }
                        let dx = value.translation.width / max(1, fitted.width)
                        let dy = value.translation.height / max(1, fitted.height)
                        let minExtent = 0.18

                        var x0 = start.x
                        var y0 = start.y
                        var w = start.width
                        var h = start.height

                        if dxSign > 0 {
                            let newX = min(start.x + start.width - minExtent, max(0.0, start.x + dx))
                            w = (start.x + start.width) - newX
                            x0 = newX
                        } else {
                            w = min(1.0 - start.x, max(minExtent, start.width + dx))
                        }

                        if dySign > 0 {
                            let newY = min(start.y + start.height - minExtent, max(0.0, start.y + dy))
                            h = (start.y + start.height) - newY
                            y0 = newY
                        } else {
                            h = min(1.0 - start.y, max(minExtent, start.height + dy))
                        }

                        crop = OneTapeNormalizedRect(x: x0, y: y0, width: w, height: h).clamped
                    }
                    .onEnded { _ in
                        dragStartCrop = nil
                    }
            )
    }

    private func fittedImageRect(in container: CGRect) -> CGRect {
        let iw = max(1, sourceImage.size.width)
        let ih = max(1, sourceImage.size.height)
        let scale = min(container.width / iw, container.height / ih)
        let w = iw * scale
        let h = ih * scale
        return CGRect(x: container.midX - w / 2, y: container.midY - h / 2, width: w, height: h)
    }
}
