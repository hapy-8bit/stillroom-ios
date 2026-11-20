import AVFoundation
import XCTest
@testable import Stillroom

final class OneTapeTransportSoundServiceTests: XCTestCase {
    @MainActor
    func testNewCueStopsOldAndStaleCallbacksCannotStopReplacement() throws {
        let first = CueVoice(), second = CueVoice()
        var voices = [first, second]
        let service = OneTapeTransportSoundService(makePlayer: { _ in voices.removeFirst() })
        try service.play(.playLatch)
        let staleFinish = first.onFinish, staleFailure = first.onFailure
        try service.play(.pauseRelease)
        XCTAssertEqual(first.stops, 1)
        XCTAssertEqual(second.starts, 1)
        staleFinish?()
        staleFailure?()
        XCTAssertEqual(second.stops, 0)
        second.onFinish?()
        XCTAssertEqual(second.stops, 1)
        XCTAssertNil(second.onFinish)
        XCTAssertNil(second.onFailure)
    }

    @MainActor
    func testStopReleasesVoiceAndDoesNotReplayOnLaterCallbacks() throws {
        let voice = CueVoice()
        var failures: [OneTapeTransportSoundError] = []
        let service = OneTapeTransportSoundService(onFailure: { failures.append($0) },
                                                  makePlayer: { _ in voice })
        try service.play(.playLatch)
        let staleFailure = voice.onFailure
        service.stop()
        staleFailure?()
        XCTAssertEqual(voice.starts, 1)
        XCTAssertEqual(voice.stops, 1)
        XCTAssertNil(voice.onFinish)
        XCTAssertNil(voice.onFailure)
        XCTAssertTrue(failures.isEmpty)
    }

    @MainActor
    func testDecodeFailureIsReportedOnceAndReleasesVoice() throws {
        let voice = CueVoice()
        var failures: [OneTapeTransportSoundError] = []
        let service = OneTapeTransportSoundService(onFailure: { failures.append($0) },
                                                  makePlayer: { _ in voice })
        try service.play(.playLatch)
        let callback = voice.onFailure
        callback?()
        callback?()
        XCTAssertEqual(failures, [.decoding])
        XCTAssertEqual(voice.stops, 1)
        XCTAssertNil(voice.onFailure)
    }

    @MainActor
    func testStartAndMissingResourceFailuresAreExplicitAndDoNotRetainVoice() {
        let voice = CueVoice()
        voice.startSucceeds = false
        let service = OneTapeTransportSoundService(makePlayer: { _ in voice })
        XCTAssertThrowsError(try service.play(.playLatch)) {
            XCTAssertEqual($0 as? OneTapeTransportSoundError, .cannotStart)
        }
        XCTAssertEqual(voice.stops, 1)
        XCTAssertNil(voice.onFailure)
        let missing = OneTapeTransportSoundService(makePlayer: { _ in
            throw OneTapeTransportSoundError.missingResource
        })
        XCTAssertThrowsError(try missing.play(.pauseRelease)) {
            XCTAssertEqual($0 as? OneTapeTransportSoundError, .missingResource)
        }
    }

    @MainActor
    func testBundledNativeVoiceCompletesAsynchronouslyWithoutChangingSessionConfiguration() async throws {
        let session = AVAudioSession.sharedInstance()
        let category = session.category, mode = session.mode
        for cue in OneTapeTransportCue.allCases {
            let voice = try OneTapeTransportSoundService.bundledPlayer(cue)
            let completion = expectation(description: "Native \(cue.rawValue) voice reports completion")
            var didFail = false
            voice.onFinish = { completion.fulfill() }
            voice.onFailure = { didFail = true; completion.fulfill() }
            XCTAssertTrue(voice.play())
            await fulfillment(of: [completion], timeout: 10)
            XCTAssertFalse(didFail)
            XCTAssertEqual(session.category, category)
            XCTAssertEqual(session.mode, mode)
            voice.stop()
        }
    }

    @MainActor
    func testBundledNativeVoiceImmediateCancelCannotProduceLateCallbacks() async throws {
        let session = AVAudioSession.sharedInstance()
        let category = session.category, mode = session.mode
        let voice = try OneTapeTransportSoundService.bundledPlayer(.playLatch)
        let callback = expectation(description: "Canceled preparation remains silent")
        callback.isInverted = true
        voice.onFinish = { callback.fulfill() }
        voice.onFailure = { callback.fulfill() }
        XCTAssertTrue(voice.play())
        // stop() runs before the main actor can receive the preparation result.
        voice.stop()
        await fulfillment(of: [callback], timeout: 1.2)
        XCTAssertEqual(session.category, category)
        XCTAssertEqual(session.mode, mode)
    }

    func testBundledEffectsAreShortBoundedValidPCMWithSilentEndpoints() throws {
        for cue in OneTapeTransportCue.allCases {
            let url = try XCTUnwrap(Bundle.main.url(forResource: cue.resourceName, withExtension: "wav"))
            let file = try AVAudioFile(forReading: url)
            XCTAssertEqual(file.processingFormat.channelCount, 1)
            XCTAssertEqual(file.processingFormat.sampleRate, 44_100)
            let duration = Double(file.length) / file.processingFormat.sampleRate
            XCTAssertGreaterThan(duration, 0.1)
            XCTAssertLessThan(duration, 1)
            let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                    frameCapacity: AVAudioFrameCount(file.length)))
            try file.read(into: pcm)
            let channel = try XCTUnwrap(pcm.floatChannelData?[0])
            let count = Int(pcm.frameLength)
            XCTAssertEqual(channel[0], 0)
            XCTAssertEqual(channel[count - 1], 0)
            var peak: Float = 0
            var energy: Float = 0
            var allFinite = true
            for index in 0..<count {
                allFinite = allFinite && channel[index].isFinite
                peak = max(peak, abs(channel[index]))
                energy += channel[index] * channel[index]
            }
            XCTAssertTrue(allFinite)
            XCTAssertGreaterThan(peak, 0.1)
            XCTAssertLessThan(peak, 0.7)
            XCTAssertGreaterThan(energy, 0.01)
        }
    }
}

@MainActor
private final class CueVoice: OneTapeTransportCuePlaying {
    var onFinish: (() -> Void)?
    var onFailure: (() -> Void)?
    var starts = 0
    var stops = 0
    var startSucceeds = true
    func play() -> Bool { starts += 1; return startSucceeds }
    func stop() { stops += 1 }
}
