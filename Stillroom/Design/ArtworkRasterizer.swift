import SwiftUI
import CoreImage

/// Small immutable textures replace live full-screen blur and per-frame SwiftUI label drawing.
/// Call only when track/artwork identity changes; this renderer never reads files or audio state.
@MainActor
enum ArtworkRasterizer {
    static func label(track: Track, artwork: UIImage?) -> UIImage? {
        let renderer = ImageRenderer(content: ArtworkView(track: track, image: artwork).frame(width: 256, height: 256))
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: 256, height: 256)
        return renderer.uiImage
    }

    static func atmosphere(track: Track, artwork: UIImage?) async -> UIImage? {
        let renderer = ImageRenderer(content: ArtworkView(track: track, image: artwork).frame(width: 128, height: 128))
        renderer.scale = 1
        guard let source = renderer.uiImage?.cgImage else { return nil }
        let result = await Task.detached(priority: .userInitiated) {
            let input = CIImage(cgImage: source)
            // Nine texture pixels approximate the former 80-point blur on the oversized backdrop.
            let blurred = input.clampedToExtent().applyingGaussianBlur(sigma: 9).cropped(to: input.extent)
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.65])
            // Keep filter setup off the UI actor, especially on the first track change.
            let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
            return context.createCGImage(blurred, from: input.extent)
        }.value
        return result.map { UIImage(cgImage: $0) }
    }
}
