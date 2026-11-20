import Foundation
import Accelerate

/// Called only on the analysis worker, never on the real-time audio callback.
/// Amplitude refers to the PCM mono downmix; visual band levels use a -72 dB floor.
final class AudioPCMAnalyzer {
    static let capacity = 2_048
    private let setup: vDSP_DFT_Setup
    private var real = [Float](repeating: 0, count: capacity)
    private var imaginary = [Float](repeating: 0, count: capacity)
    private var realOutput = [Float](repeating: 0, count: capacity)
    private var imaginaryOutput = [Float](repeating: 0, count: capacity)

    init?() {
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(Self.capacity), .FORWARD) else { return nil }
        self.setup = setup
    }

    deinit { vDSP_DFT_DestroySetup(setup) }

    func analyze(_ samples: UnsafeBufferPointer<Float>, sampleRate: Double) -> AudioVisualizationFrame {
        let count = min(samples.count, Self.capacity)
        guard count > 0, sampleRate.isFinite, sampleRate > 0 else { return .unsupported }
        let upper = min(16_000, sampleRate / 2)
        let lower = min(40, upper / 2)
        // A positive subnormal rate can still underflow these divisions to zero.
        // Reject it before logarithmic bins can produce NaN and trap in Int().
        guard lower > 0, upper.isFinite, lower.isFinite else { return .unsupported }
        var energy: Double = 0
        var peak: Float = 0
        for index in 0..<Self.capacity {
            let raw = index < count ? samples[index] : 0
            let sample = raw.isFinite ? min(1, max(-1, raw)) : 0
            energy += Double(sample) * Double(sample)
            peak = max(peak, abs(sample))
            // Hann window reduces spectral leakage without changing the RMS
            // or waveform, which are derived directly from unwindowed PCM.
            let window: Float = index < count && count > 1 ?
                Float(0.5 - 0.5 * cos(2 * .pi * Double(index) / Double(count - 1))) : 0
            real[index] = sample * window
        }
        real.withUnsafeBufferPointer { input in
            imaginary.withUnsafeBufferPointer { imaginary in
                realOutput.withUnsafeMutableBufferPointer { output in
                    imaginaryOutput.withUnsafeMutableBufferPointer { imaginaryOutput in
                        vDSP_DFT_Execute(setup, input.baseAddress!, imaginary.baseAddress!,
                                         output.baseAddress!, imaginaryOutput.baseAddress!)
                    }
                }
            }
        }
        var bands = [Float](repeating: 0, count: 24)
        for index in bands.indices {
            let lowFrequency = lower * pow(upper / lower, Double(index) / Double(bands.count))
            let highFrequency = lower * pow(upper / lower, Double(index + 1) / Double(bands.count))
            let low = min(Self.capacity / 2 - 1, max(1, Int(lowFrequency * Double(Self.capacity) / sampleRate)))
            let high = min(Self.capacity / 2, max(low + 1, Int(ceil(highFrequency * Double(Self.capacity) / sampleRate))))
            var magnitude: Float = 0
            for bin in low..<high {
                magnitude = max(magnitude, hypot(realOutput[bin], imaginaryOutput[bin]) * 4 / Float(count))
            }
            let decibels = 20 * log10(max(0.000_000_1, magnitude))
            bands[index] = min(1, max(0, (decibels + 72) / 72))
        }
        var waveform = [Float](repeating: 0, count: 48)
        for index in waveform.indices {
            let source = min(count - 1, index * count / waveform.count)
            waveform[index] = samples[source].isFinite ? min(1, max(-1, samples[source])) : 0
        }
        return AudioVisualizationFrame(rms: Float(sqrt(energy / Double(count))), peak: peak,
            bands: bands, waveform: waveform, status: .active, sampleRate: sampleRate, sampleCount: count)
    }
}
