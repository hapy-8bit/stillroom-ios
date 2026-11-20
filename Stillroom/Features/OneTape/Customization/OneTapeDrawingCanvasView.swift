import PencilKit
import SwiftUI
import UIKit

struct OneTapeDrawingCanvasView: View {
    let tapeStyle: OneTapeAppearance.TapeStyle
    let initialDrawing: PKDrawing
    var underlayImage: UIImage? = nil
    var cassetteReadout: OneTapeCassetteReadout = .empty
    var editingTitle: String? = nil
    let onCancel: () -> Void
    let onSave: (PKDrawing) -> Void

    @State private var drawing: PKDrawing
    @State private var undoManager: UndoManager?
    @State private var canUndo = false
    @State private var canRedo = false

    private let logicalSize = OneTapeDrawingGeometry.cassettePortraitSize

    private let paperBlue = Color(red: 208.0 / 255.0, green: 217.0 / 255.0, blue: 233.0 / 255.0)
    private let paperOutlineBlue = Color(red: 154.0 / 255.0, green: 171.0 / 255.0, blue: 209.0 / 255.0)
    private let paperCream = Color(red: 250.0 / 255.0, green: 247.0 / 255.0, blue: 241.0 / 255.0)

    init(
        tapeStyle: OneTapeAppearance.TapeStyle,
        initialDrawing: PKDrawing = PKDrawing(),
        underlayImage: UIImage? = nil,
        cassetteReadout: OneTapeCassetteReadout = .empty,
        editingTitle: String? = nil,
        onCancel: @escaping () -> Void,
        onSave: @escaping (PKDrawing) -> Void
    ) {
        self.tapeStyle = tapeStyle
        self.initialDrawing = initialDrawing
        self.underlayImage = underlayImage
        self.cassetteReadout = cassetteReadout
        self.editingTitle = editingTitle
        self.onCancel = onCancel
        self.onSave = onSave
        _drawing = State(initialValue: initialDrawing)
    }

    private var hasInk: Bool {
        !drawing.strokes.isEmpty || underlayImage != nil
    }

    var body: some View {
        ZStack {
            Color(red: 20.0 / 255.0, green: 20.0 / 255.0, blue: 20.0 / 255.0).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 10)

                GeometryReader { proxy in
                    let availableWidth = max(1, proxy.size.width - 32)
                    let availableHeight = max(1, proxy.size.height - 20)
                    let scale = min(availableWidth / logicalSize.width, availableHeight / logicalSize.height)
                    let fittedSize = CGSize(width: logicalSize.width * scale, height: logicalSize.height * scale)

                    ZStack {
                        blueprintPaperSheet
                            .frame(width: logicalSize.width, height: logicalSize.height)
                            .scaleEffect(scale)
                            .frame(width: fittedSize.width, height: fittedSize.height)
                            .allowsHitTesting(false)

                        if let underlayImage {
                            Image(uiImage: underlayImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: logicalSize.width, height: logicalSize.height)
                                .compositingGroup()
                                .mask {
                                    OneTapeShellPrintMask(tapeStyle: tapeStyle)
                                }
                                .scaleEffect(scale)
                                .frame(width: fittedSize.width, height: fittedSize.height)
                                .allowsHitTesting(false)
                        }

                        OneTapePencilKitRepresentable(
                            drawing: $drawing,
                            logicalSize: logicalSize,
                            scale: scale,
                            onUndoManagerChanged: { manager in
                                undoManager = manager
                                refreshUndoState()
                            },
                            onDrawingEdited: {
                                refreshUndoState()
                            }
                        )
                        .frame(width: fittedSize.width, height: fittedSize.height)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Reserve clear room for PencilKit's docked tool palette on iPhone.
                Spacer()
                    .frame(height: 88)
            }
        }
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
        .onAppear {
            refreshUndoState()
        }
    }

    private var blueprintPaperSheet: some View {
        let maskShape = OneTapeShellPrintMask(tapeStyle: tapeStyle)
            .frame(width: logicalSize.width, height: logicalSize.height)
        let offsets: [(CGFloat, CGFloat)] = [
            (-1.2, 0), (1.2, 0), (0, -1.2), (0, 1.2),
            (-0.85, -0.85), (0.85, -0.85), (-0.85, 0.85), (0.85, 0.85)
        ]

        return ZStack {
            paperBlue
                .frame(width: logicalSize.width, height: logicalSize.height)
            ForEach(0..<offsets.count, id: \.self) { index in
                paperOutlineBlue
                    .frame(width: logicalSize.width, height: logicalSize.height)
                    .mask {
                        maskShape.offset(x: offsets[index].0, y: offsets[index].1)
                    }
            }
            paperCream
                .frame(width: logicalSize.width, height: logicalSize.height)
                .mask { maskShape }
        }
        .frame(width: logicalSize.width, height: logicalSize.height)
        .drawingGroup()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button("取消", action: onCancel)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.92))
                .frame(minHeight: 44)
                .accessibilityIdentifier("drawingCanvas.cancel")

            Spacer()

            HStack(spacing: 20) {
                Button {
                    undoManager?.undo()
                    refreshUndoState()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16, weight: .medium))
                }
                .disabled(!canUndo)
                .foregroundStyle(canUndo ? .white.opacity(0.92) : .white.opacity(0.28))
                .frame(minWidth: 32, minHeight: 44)
                .accessibilityLabel("撤销")
                .accessibilityIdentifier("drawingCanvas.undo")

                Button {
                    undoManager?.redo()
                    refreshUndoState()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 16, weight: .medium))
                }
                .disabled(!canRedo)
                .foregroundStyle(canRedo ? .white.opacity(0.92) : .white.opacity(0.28))
                .frame(minWidth: 32, minHeight: 44)
                .accessibilityLabel("重做")
                .accessibilityIdentifier("drawingCanvas.redo")
            }

            Spacer()

            Button("完成") {
                onSave(drawing)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(hasInk ? .white : .white.opacity(0.32))
            .disabled(!hasInk)
            .frame(minHeight: 44)
            .accessibilityIdentifier("drawingCanvas.done")
        }
        .overlay {
            if let editingTitle {
                Text(editingTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.42))
                    .offset(y: 26)
                    .allowsHitTesting(false)
            }
        }
    }

    private func refreshUndoState() {
        canUndo = undoManager?.canUndo ?? false
        canRedo = undoManager?.canRedo ?? false
    }
}

private struct OneTapePencilKitRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let logicalSize: CGSize
    let scale: CGFloat
    let onUndoManagerChanged: (UndoManager?) -> Void
    let onDrawingEdited: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> CanvasStageView {
        let stage = CanvasStageView()
        stage.backgroundColor = .clear
        stage.clipsToBounds = false

        let canvas = stage.canvasView
        canvas.bounds = CGRect(origin: .zero, size: logicalSize)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawingPolicy = .anyInput
        canvas.drawing = drawing
        canvas.delegate = context.coordinator

        let inkColor = UIColor(white: 0.12, alpha: 1)
        canvas.tool = PKInkingTool(.pen, color: inkColor, width: 4.0)

        stage.onWindowAttached = { window in
            context.coordinator.attachToolPicker(to: canvas, window: window, defaultColor: inkColor)
            DispatchQueue.main.async {
                onUndoManagerChanged(canvas.undoManager)
            }
        }
        return stage
    }

    func updateUIView(_ stage: CanvasStageView, context: Context) {
        context.coordinator.parent = self
        stage.logicalSize = logicalSize
        stage.canvasScale = scale

        if stage.canvasView.drawing != drawing && !context.coordinator.isUpdatingFromCanvas {
            stage.canvasView.drawing = drawing
        }
        DispatchQueue.main.async {
            onUndoManagerChanged(stage.canvasView.undoManager)
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: OneTapePencilKitRepresentable
        var isUpdatingFromCanvas = false
        private var toolPicker: PKToolPicker?

        init(_ parent: OneTapePencilKitRepresentable) {
            self.parent = parent
        }

        func attachToolPicker(to canvas: PKCanvasView, window: UIWindow?, defaultColor: UIColor) {
            guard window != nil else { return }
            let picker: PKToolPicker
            if let existing = toolPicker {
                picker = existing
            } else {
                let items: [PKToolPickerItem] = [
                    PKToolPickerInkingItem(type: .pen, color: defaultColor, width: 4),
                    PKToolPickerInkingItem(type: .monoline, color: defaultColor, width: 3),
                    PKToolPickerInkingItem(type: .marker, color: .systemYellow, width: 20),
                    PKToolPickerEraserItem(type: .vector),
                    PKToolPickerInkingItem(type: .crayon, color: defaultColor, width: 8)
                ]
                picker = PKToolPicker(toolItems: items)
                picker.stateAutosaveName = "StillroomOneTapeToolPicker"
                picker.overrideUserInterfaceStyle = .dark
                picker.colorUserInterfaceStyle = .light
                picker.selectedToolItem = items[0]
                toolPicker = picker
            }
            picker.setVisible(true, forFirstResponder: canvas)
            picker.addObserver(canvas)
            if !canvas.isFirstResponder {
                canvas.becomeFirstResponder()
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            isUpdatingFromCanvas = true
            parent.drawing = canvasView.drawing
            isUpdatingFromCanvas = false
            parent.onDrawingEdited()
        }
    }

    final class CanvasStageView: UIView {
        let canvasView = PKCanvasView()
        var logicalSize: CGSize = OneTapeDrawingGeometry.cassettePortraitSize {
            didSet { setNeedsLayout() }
        }
        var canvasScale: CGFloat = 1 {
            didSet { setNeedsLayout() }
        }
        var onWindowAttached: ((UIWindow?) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            addSubview(canvasView)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowAttached?(window)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            canvasView.bounds = CGRect(origin: .zero, size: logicalSize)
            canvasView.center = CGPoint(x: bounds.midX, y: bounds.midY)
            canvasView.transform = CGAffineTransform(scaleX: canvasScale, y: canvasScale)
        }
    }
}
