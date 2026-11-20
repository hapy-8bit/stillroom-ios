import Foundation
import AVFoundation
import MediaToolbox
import Synchronization

/// Single-slot handoff: audio claims 0→1→2, worker claims 2→3→0.
/// Busy display frames are dropped; the audio thread never waits or allocates.
/// Source audio remains untouched: developer.apple.com/documentation/mediatoolbox/mtaudioprocessingtapprocesscallback
private final class PCMAnalysisSlot: @unchecked Sendable {
    let state = Atomic<Int>(0)
    let availability = Atomic<Int>(0)
    let samples = UnsafeMutablePointer<Float>.allocate(capacity: AudioPCMAnalyzer.capacity)
    var count = 0
    var sampleRate: Double = 0
    var format = AudioStreamBasicDescription()

    init() { samples.initialize(repeating: 0, count: AudioPCMAnalyzer.capacity) }
    deinit { samples.deinitialize(count: AudioPCMAnalyzer.capacity); samples.deallocate() }

    func configure(_ format: AudioStreamBasicDescription) {
        self.format = format
        let separate = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        let expectedStride = format.mBitsPerChannel / 8 * (separate ? 1 : format.mChannelsPerFrame)
        let supported = format.mFormatID == kAudioFormatLinearPCM && format.mChannelsPerFrame > 0 &&
            format.mChannelsPerFrame <= 8 && format.mSampleRate.isFinite && format.mSampleRate / 4 > 0 &&
            ((format.mFormatFlags & kAudioFormatFlagIsFloat != 0 && format.mBitsPerChannel == 32) ||
             (format.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0 && [16, 32].contains(format.mBitsPerChannel))) &&
            format.mFormatFlags & kAudioFormatFlagIsBigEndian == 0 && format.mBytesPerFrame == expectedStride
        availability.store(supported ? 1 : 2, ordering: .releasing)
    }

    func consume(_ list: UnsafeMutablePointer<AudioBufferList>, frames: Int) {
        guard availability.load(ordering: .acquiring) == 1, frames > 0 else { return }
        guard state.compareExchange(expected: 0, desired: 1, ordering: .acquiringAndReleasing).exchanged else { return }
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        let channels = Int(format.mChannelsPerFrame)
        let separate = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        let width = Int(format.mBitsPerChannel / 8)
        let stride = separate ? 1 : channels
        guard buffers.count >= (separate ? channels : 1), width > 0 else {
            state.store(0, ordering: .releasing); return
        }
        for channel in 0..<(separate ? channels : 1) {
            guard buffers[channel].mData != nil,
                  Int(buffers[channel].mDataByteSize) / width / stride >= frames else {
                state.store(0, ordering: .releasing); return
            }
        }
        let count = min(frames, AudioPCMAnalyzer.capacity)
        let offset = frames - count
        for frame in 0..<count {
            var mono: Float = 0
            for channel in 0..<channels {
                let pointer = buffers[separate ? channel : 0].mData!
                let index = (offset + frame) * stride + (separate ? 0 : channel)
                let value: Float
                if format.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                    value = pointer.assumingMemoryBound(to: Float.self)[index]
                } else if width == 2 {
                    value = Float(pointer.assumingMemoryBound(to: Int16.self)[index]) / 32_768
                } else {
                    value = Float(pointer.assumingMemoryBound(to: Int32.self)[index]) / 2_147_483_648
                }
                mono += value.isFinite ? value / Float(channels) : 0
            }
            samples[frame] = min(1, max(-1, mono))
        }
        self.count = count
        sampleRate = format.mSampleRate
        state.store(2, ordering: .releasing)
    }
}

final class AudioPCMProcessingTap: @unchecked Sendable {
    let tap: MTAudioProcessingTap
    private let slot: PCMAnalysisSlot
    private let analyzer: AudioPCMAnalyzer
    private let worker: DispatchSourceTimer
    private let onFrame: @Sendable (AudioVisualizationFrame) -> Void
    private let playbackStarted = Atomic<Bool>(false)
    private var beganWaiting: ContinuousClock.Instant?
    private var scratch = [Float](repeating: 0, count: AudioPCMAnalyzer.capacity)
    private var hadPCM = false
    private var unsupportedSent = false

    init(onFrame: @escaping @Sendable (AudioVisualizationFrame) -> Void) throws {
        let slot = PCMAnalysisSlot()
        var callbacks = MTAudioProcessingTapCallbacks(version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passUnretained(slot).toOpaque(),
            init: { _, client, storage in
                guard let client else { return }
                _ = Unmanaged<PCMAnalysisSlot>.fromOpaque(client).retain()
                storage.pointee = client
            }, finalize: { tap in
                Unmanaged<PCMAnalysisSlot>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
            }, prepare: { tap, _, format in
                let slot = Unmanaged<PCMAnalysisSlot>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
                slot.configure(format.pointee)
            }, unprepare: { _ in }, process: { tap, requested, _, buffers, produced, flags in
                let status = MTAudioProcessingTapGetSourceAudio(tap, requested, buffers, flags, nil, produced)
                guard status == noErr, produced.pointee > 0 else { return }
                let slot = Unmanaged<PCMAnalysisSlot>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
                slot.consume(buffers, frames: produced.pointee)
            })
        var created: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks,
                                               kMTAudioProcessingTapCreationFlag_PostEffects, &created)
        guard status == noErr, let tap = created else { throw PCMAnalysisError.unavailable }
        guard let analyzer = AudioPCMAnalyzer() else { throw PCMAnalysisError.unavailable }
        self.tap = tap
        self.slot = slot
        self.analyzer = analyzer
        self.onFrame = onFrame
        worker = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "OneTape.audio-analysis", qos: .utility))
        worker.schedule(deadline: .now() + .milliseconds(65), repeating: .milliseconds(65), leeway: .milliseconds(10))
        worker.setEventHandler { [weak self] in self?.analyzePending() }
        worker.resume()
    }

    deinit { worker.cancel() }

    func markPlaybackStarted() { playbackStarted.store(true, ordering: .releasing) }

    private func analyzePending() {
        if beganWaiting == nil, playbackStarted.load(ordering: .acquiring) { beganWaiting = .now }
        if slot.state.compareExchange(expected: 2, desired: 3, ordering: .acquiringAndReleasing).exchanged {
            let count = slot.count
            let rate = slot.sampleRate
            scratch.withUnsafeMutableBufferPointer { destination in
                destination.baseAddress!.update(from: slot.samples, count: count)
            }
            slot.state.store(0, ordering: .releasing)
            let frame = scratch.withUnsafeBufferPointer { pointer in
                analyzer.analyze(UnsafeBufferPointer(start: pointer.baseAddress, count: count), sampleRate: rate)
            }
            hadPCM = true
            unsupportedSent = false
            onFrame(frame)
        } else if !unsupportedSent && (slot.availability.load(ordering: .acquiring) == 2 ||
                    (!hadPCM && beganWaiting.map { $0.duration(to: .now) > .seconds(3) } == true)) {
            unsupportedSent = true
            onFrame(.unsupported)
        }
    }
}

enum PCMAnalysisError: Error { case unavailable }
