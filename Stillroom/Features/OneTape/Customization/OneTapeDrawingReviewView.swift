import SwiftUI
import UIKit

struct OneTapeDrawingReviewView: View {
    let imported: OneTapeImportedPaper
    let tapeStyle: OneTapeAppearance.TapeStyle
    var cassetteReadout: OneTapeCassetteReadout = .empty
    let onCancel: () -> Void
    let onDrawOnTop: (OneTapeDrawingInkMode) -> Void
    let onKeep: (OneTapeDrawingInkMode) -> Void

    @State private var inkMode: OneTapeDrawingInkMode

    init(
        imported: OneTapeImportedPaper,
        tapeStyle: OneTapeAppearance.TapeStyle,
        cassetteReadout: OneTapeCassetteReadout = .empty,
        initialInkMode: OneTapeDrawingInkMode,
        onCancel: @escaping () -> Void,
        onDrawOnTop: @escaping (OneTapeDrawingInkMode) -> Void,
        onKeep: @escaping (OneTapeDrawingInkMode) -> Void
    ) {
        self.imported = imported
        self.tapeStyle = tapeStyle
        self.cassetteReadout = cassetteReadout
        self.onCancel = onCancel
        self.onDrawOnTop = onDrawOnTop
        self.onKeep = onKeep
        _inkMode = State(initialValue: initialInkMode)
    }

    private var previewAppearance: OneTapeAppearance {
        var copy = OneTapeAppearance()
        copy.tapeStyle = tapeStyle
        copy.printStyle = .blank
        copy.doodleStyle = .none
        return copy
    }

    private var previewPrint: OneTapeResolvedPrint {
        OneTapeResolvedPrint(
            drawingID: UUID(),
            revision: 0,
            image: imported.image,
            inkMode: inkMode
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if imported.recognizedPaper {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text("已根据画纸识别。")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.84))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.08), in: Capsule())
                }

                OneTapeTapeThumbnail(
                    tilt: 0,
                    appearance: previewAppearance,
                    cassetteReadout: cassetteReadout,
                    customPrint: previewPrint
                )
                .frame(height: 220)
                .frame(maxWidth: .infinity)

                inkModePicker
                    .padding(.horizontal, 20)

                Spacer(minLength: 8)

                HStack(spacing: 12) {
                    Button {
                        onDrawOnTop(inkMode)
                    } label: {
                        Text("在上面画")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.white.opacity(0.11), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                    }
                    .accessibilityIdentifier("drawingReview.drawOnTop")

                    Button {
                        onKeep(inkMode)
                    } label: {
                        Text("留下它")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.white, in: Capsule())
                    }
                    .accessibilityIdentifier("drawingReview.keep")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .padding(.top, 12)
            .background(Color(red: 0.08, green: 0.08, blue: 0.09).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                        .foregroundStyle(.white.opacity(0.8))
                        .accessibilityIdentifier("drawingReview.cancel")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var inkModePicker: some View {
        HStack(spacing: 8) {
            ForEach(OneTapeDrawingInkMode.allCases, id: \.rawValue) { mode in
                let selected = inkMode == mode
                Button {
                    inkMode = mode
                } label: {
                    Text(mode.title)
                        .font(.caption.weight(selected ? .semibold : .medium))
                        .foregroundStyle(selected ? .black : .white.opacity(0.76))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? .white : .white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct OneTapeActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
