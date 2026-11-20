import SwiftUI
import UIKit

/// Reuses the same compositor clock for a prepared custom-disc bitmap. It never samples media time.
struct CompositedRecordSurface: View {
    let image: UIImage?
    let running: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.roomMotionVisible) private var visible
    var body: some View { NativeRecordLabel(image: image, running: running && visible && scenePhase == .active) }
}

struct RecordLabelSurface: View {
    let track: Track
    let artwork: UIImage?
    let running: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.roomMotionVisible) private var motionVisible
    @State private var texture: UIImage?

    var body: some View {
        ZStack {
            if texture == nil { ArtworkView(track: track, image: artwork) }
            NativeRecordLabel(image: texture, running: running && motionVisible && scenePhase == .active)
        }.task(id: "\(track.id)-\(artwork?.hash ?? 0)") {
            texture = ArtworkRasterizer.label(track: track, artwork: artwork)
        }.accessibilityHidden(true)
    }
}

private struct NativeRecordLabel: UIViewRepresentable {
    let image: UIImage?
    let running: Bool

    func makeUIView(context: Context) -> RecordLabelImageView { RecordLabelImageView() }
    func updateUIView(_ view: RecordLabelImageView, context: Context) { view.update(image: image, running: running) }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: RecordLabelImageView, context: Context) -> CGSize? {
        // The cache is 512 pixels; that is not a 512-point layout preference. Honor the disc's
        // proposed logical frame instead of UIImageView's bitmap-derived intrinsic dimensions.
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }
    static func dismantleUIView(_ view: RecordLabelImageView, coordinator: ()) { view.layer.removeAllAnimations() }
}

/// Core Animation rotates the bitmap on the compositor; no 30 Hz SwiftUI body/Canvas clock.
private final class RecordLabelImageView: UIImageView {
    private var wantsMotion = false
    private var paused = false

    init() {
        super.init(frame: .zero)
        contentMode = .scaleAspectFill
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        clipsToBounds = true
    }
    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }
    override func didMoveToWindow() { super.didMoveToWindow(); synchronize() }

    func update(image: UIImage?, running: Bool) {
        if self.image !== image {
            self.image = image
            layer.removeAllAnimations()
            layer.speed = 1
            layer.timeOffset = 0
            layer.beginTime = 0
            paused = false
        }
        wantsMotion = running
        synchronize()
    }

    private func synchronize() {
        let active = wantsMotion && window != nil && image != nil
        if active && layer.animation(forKey: "record.spin") == nil {
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = Double.pi * 2
            spin.duration = 8
            spin.repeatCount = .infinity
            layer.add(spin, forKey: "record.spin")
        }
        // Preserve the local visual phase on pause, backgrounding and temporary gallery cover.
        if active && paused {
            let heldTime = layer.timeOffset
            layer.speed = 1
            layer.timeOffset = 0
            layer.beginTime = 0
            layer.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - heldTime
            paused = false
        } else if !active && !paused {
            let time = layer.convertTime(CACurrentMediaTime(), from: nil)
            layer.speed = 0
            layer.timeOffset = time
            paused = true
        }
    }
}
