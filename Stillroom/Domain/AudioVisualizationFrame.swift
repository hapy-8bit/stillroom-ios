import Foundation

enum AudioAnalysisStatus: String, Equatable, Sendable {
    case idle, preparing, active, unsupported
}

struct AudioVisualizationFrame: Equatable, Sendable {
    let rms: Float
    let peak: Float
    let bands: [Float]
    let waveform: [Float]
    let status: AudioAnalysisStatus
    let sampleRate: Double
    let sampleCount: Int

    init(rms: Float = 0, peak: Float = 0, bands: [Float] = Array(repeating: 0, count: 24),
         waveform: [Float] = Array(repeating: 0, count: 48), status: AudioAnalysisStatus = .idle,
         sampleRate: Double = 0, sampleCount: Int = 0) {
        self.rms = rms
        self.peak = peak
        self.bands = bands
        self.waveform = waveform
        self.status = status
        self.sampleRate = sampleRate
        self.sampleCount = sampleCount
    }

    static let idle = AudioVisualizationFrame()
    static let preparing = AudioVisualizationFrame(status: .preparing)
    static let unsupported = AudioVisualizationFrame(status: .unsupported)
}
