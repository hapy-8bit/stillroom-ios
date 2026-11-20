import SwiftUI

enum OneTapePhotoFrameMode: Equatable, Sendable {
    case immediate
    case playback(running: Bool)
}

private struct OneTapePhotoFrameModeKey: EnvironmentKey {
    static let defaultValue = OneTapePhotoFrameMode.immediate
}

extension EnvironmentValues {
    var oneTapePhotoFrameMode: OneTapePhotoFrameMode {
        get { self[OneTapePhotoFrameModeKey.self] }
        set { self[OneTapePhotoFrameModeKey.self] = newValue }
    }
}

/// The visual clock chooses phase; the worker only renders that requested pose.
/// One in-flight job and one latest request prevent queued animation backlogs.
@MainActor
final class OneTapePhotoFrameStore: ObservableObject {
    struct Request: Equatable, Sendable {
        let style: OneTapeAppearance.ScreenStyle
        let phase: Double
        let size: CGSize
        let scale: CGFloat
        let running: Bool

        func sharesSurface(with other: Self) -> Bool {
            style == other.style && size == other.size && scale == other.scale
        }
    }

    typealias Render = @Sendable (Request) -> CGImage?
    @Published private(set) var image: CGImage?
    private static let worker = DispatchQueue(label: "OneTape.PhotoFrames", qos: .userInitiated)
    private let render: Render
    private var latest: Request?
    private var pending: Request?
    private var inFlight = false
    private var generation = 0

    init(render: @escaping Render = { request in
        OneTapeLivePhotoRasterizer.renderForPlayback(style: request.style, phase: request.phase,
            size: request.size, displayScale: request.scale)
    }) {
        self.render = render
    }

    func request(_ request: Request) {
        guard request.phase.isFinite, request.size.width.isFinite, request.size.height.isFinite,
              request.size.width > 0, request.size.height > 0, request.scale.isFinite,
              request.scale > 0, request != latest else { return }
        if let latest {
            if !request.sharesSurface(with: latest) || request.running != latest.running || request.phase < latest.phase {
                generation += 1
            }
            if !request.sharesSurface(with: latest) { image = nil }
        }
        latest = request
        pending = request
        startNext()
    }

    func cancel() {
        generation += 1
        latest = nil
        pending = nil
        // An executing CG draw may finish. Weak ownership and the generation
        // check prevent publication after disappearance, pause or replacement.
    }

    private func startNext() {
        guard !inFlight, let request = pending else { return }
        pending = nil
        inFlight = true
        let revision = generation
        let render = render
        Self.worker.async { [weak self] in
            let image = autoreleasepool { render(request) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.inFlight = false
                if revision == self.generation, let latest = self.latest,
                   latest.sharesSurface(with: request), latest.phase - request.phase <= 0.15, let image {
                    self.image = image
                }
                self.startNext()
            }
        }
    }
}

struct OneTapePlaybackPhotoFrame: View {
    let request: OneTapePhotoFrameStore.Request
    @StateObject private var frames = OneTapePhotoFrameStore()

    var body: some View {
        Group {
            if let image = frames.image {
                Image(decorative: image, scale: 1).resizable().interpolation(.high)
            } else {
                // Show the correct asset while the first field prepares off-main.
                // Input/media labels never wait for a heavy zero-pose Canvas.
                Image(request.style == .rain ? "OneTapeScreenRainPhoto" : "OneTapeScreenTrailsPhoto")
                    .resizable().scaledToFill()
            }
        }
        .frame(width: request.size.width, height: request.size.height)
        .clipped()
        .onAppear { frames.request(request) }
        .onChange(of: request) { _, request in frames.request(request) }
        .onDisappear { frames.cancel() }
    }
}
