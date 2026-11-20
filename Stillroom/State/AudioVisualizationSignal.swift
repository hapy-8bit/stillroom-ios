import Combine

/// A leaf renderer observes this object directly. The music catalog and root
/// presentation do not forward analysis-frame changes through their publishers.
@MainActor
final class AudioVisualizationSignal: ObservableObject {
    @Published private(set) var frame = AudioVisualizationFrame.idle

    func update(_ frame: AudioVisualizationFrame) { self.frame = frame }
}
