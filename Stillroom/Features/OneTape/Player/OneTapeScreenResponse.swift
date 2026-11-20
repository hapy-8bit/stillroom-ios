import Foundation

/// Render values contain measured audio features, never a synthesized sound.
/// The motion clock integrates measured energy; it is unrelated to track time.
struct OneTapeScreenResponse: Equatable {
    var rms = 0.0
    var peak = 0.0
    var bands = [Double](repeating: 0, count: 16)
    var heldPeaks = [Double](repeating: 0, count: 16)
    var waveform = [Double](repeating: 0, count: 48)
    var spectrumHistory: [[Double]] = []
    var motionTime = 0.0

    static let silent = Self()

    var intensity: Double { sqrt(rms) }
    var transient: Double { max(0, peak - rms) }
}

/// Per-band hold/decay belongs to the display, not the audio engine. Muting or
/// losing PCM clears the drawing immediately instead of inventing activity.
struct OneTapeScreenDynamics {
    private(set) var response = OneTapeScreenResponse.silent
    private var holds = [Double](repeating: 0, count: 16)

    mutating func consume(rms: Float, peak: Float, bands: [Float], waveform: [Float],
                          active: Bool, elapsed: TimeInterval) -> OneTapeScreenResponse {
        let dt = min(0.1, max(0, elapsed.isFinite ? elapsed : 0))
        guard active else {
            let clock = response.motionTime
            response = .silent
            response.motionTime = clock
            holds = [Double](repeating: 0, count: 16)
            return response
        }
        response.rms = Self.unit(rms)
        response.peak = Self.unit(peak)
        response.bands = Self.resample(bands, count: 16)
        // Waterfall rows record analyzer frames, never visual-clock ticks.
        response.spectrumHistory.insert(response.bands, at: 0)
        if response.spectrumHistory.count > 72 { response.spectrumHistory.removeLast() }
        response.waveform = waveform.isEmpty ? [Double](repeating: 0, count: 48)
            : waveform.map { $0.isFinite ? min(1, max(-1, Double($0))) : 0 }
        response.motionTime += dt * response.intensity * 3
        for index in response.bands.indices {
            let level = response.bands[index]
            if level >= response.heldPeaks[index] {
                response.heldPeaks[index] = level
                holds[index] = 0.45
            } else if holds[index] > 0 {
                holds[index] = max(0, holds[index] - dt)
            } else {
                response.heldPeaks[index] = max(level, response.heldPeaks[index] - dt * 0.7)
            }
        }
        return response
    }

    /// Area averaging retains every input bin when 24 analyzer bands become
    /// the reference's 16 columns; nearest-neighbor selection drops bins.
    static func resample(_ source: [Float], count: Int) -> [Double] {
        guard count > 0 else { return [] }
        guard !source.isEmpty else { return [Double](repeating: 0, count: count) }
        let ratio = Double(source.count) / Double(count)
        return (0..<count).map { output in
            let start = Double(output) * ratio
            let end = Double(output + 1) * ratio
            var sum = 0.0
            for input in Int(floor(start))..<min(source.count, Int(ceil(end))) {
                let overlap = max(0, min(end, Double(input + 1)) - max(start, Double(input)))
                sum += unit(source[input]) * overlap
            }
            return sum / ratio
        }
    }

    private static func unit(_ value: Float) -> Double {
        value.isFinite ? min(1, max(0, Double(value))) : 0
    }
}
