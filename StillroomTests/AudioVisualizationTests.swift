import XCTest
@testable import Stillroom

@MainActor
final class AudioVisualizationTests: XCTestCase {
    func testPCMAmplitudeSpectrumAndWaveformComeFromActualSamples() throws {
        let analyzer = try XCTUnwrap(AudioPCMAnalyzer())
        let samples = (0..<2_048).map { Float(0.5 * sin(2 * .pi * 1_500 * Double($0) / 48_000)) }
        let frame = samples.withUnsafeBufferPointer { analyzer.analyze($0, sampleRate: 48_000) }
        XCTAssertEqual(frame.status, .active)
        XCTAssertEqual(frame.rms, 0.35355, accuracy: 0.005)
        XCTAssertEqual(frame.peak, 0.5, accuracy: 0.001)
        XCTAssertEqual(frame.bands.count, 24)
        XCTAssertEqual(frame.waveform.count, 48)
        XCTAssertGreaterThan(frame.bands[14], frame.bands[0] + 0.4)
        XCTAssertTrue(frame.waveform.contains { $0 < -0.1 })
        XCTAssertTrue(frame.waveform.contains { $0 > 0.1 })
    }

    func testSilentPCMIsSupportedSilenceAndInvalidRateIsUnsupported() throws {
        let analyzer = try XCTUnwrap(AudioPCMAnalyzer())
        let samples = [Float](repeating: 0, count: 1_024)
        let silence = samples.withUnsafeBufferPointer { analyzer.analyze($0, sampleRate: 44_100) }
        XCTAssertEqual(silence.status, .active)
        XCTAssertEqual(silence.rms, 0)
        XCTAssertEqual(silence.peak, 0)
        XCTAssertTrue(silence.bands.allSatisfy { $0 == 0 })
        XCTAssertTrue(silence.waveform.allSatisfy { $0 == 0 })
        let unsupported = samples.withUnsafeBufferPointer { analyzer.analyze($0, sampleRate: 0) }
        XCTAssertEqual(unsupported, .unsupported)
    }

    func testInvalidSamplesNeverEscapeAsNonFiniteDisplayValues() throws {
        let analyzer = try XCTUnwrap(AudioPCMAnalyzer())
        let samples: [Float] = [.nan, .infinity, 0.5, -0.5]
        let frame = samples.withUnsafeBufferPointer { analyzer.analyze($0, sampleRate: 44_100) }
        XCTAssertTrue(frame.rms.isFinite)
        XCTAssertTrue(frame.peak.isFinite)
        XCTAssertTrue(frame.bands.allSatisfy { $0.isFinite && (0...1).contains($0) })
        XCTAssertTrue(frame.waveform.allSatisfy { $0.isFinite && (-1...1).contains($0) })
    }

    func testSubnormalRateCannotTrapDuringSpectrumIntegerConversion() throws {
        let analyzer = try XCTUnwrap(AudioPCMAnalyzer())
        let samples: [Float] = [0.25, -0.25, 0.5, -0.5]
        for rate in [Double.leastNonzeroMagnitude, Double.leastNonzeroMagnitude * 2] {
            let frame = samples.withUnsafeBufferPointer { analyzer.analyze($0, sampleRate: rate) }
            XCTAssertEqual(frame, .unsupported)
        }
        for rate in [1.0, 8_000, 44_100, 192_000] {
            let frame = samples.withUnsafeBufferPointer { analyzer.analyze($0, sampleRate: rate) }
            XCTAssertEqual(frame.status, .active)
            XCTAssertTrue(frame.bands.allSatisfy { $0.isFinite && (0...1).contains($0) })
        }
    }

    func testSameLocalEngineProducesPCMAndPauseReplacementRejectLateFrames() async throws {
        let engine = AudioPlayback()
        defer { engine.stop() }
        let produced = expectation(description: "The playing local engine delivers nonzero PCM")
        var latest = AudioVisualizationFrame.idle
        var fulfilled = false
        engine.onAnalysis = { frame in
            latest = frame
            if frame.status == .active, frame.rms > 0.000_01, !fulfilled {
                fulfilled = true
                produced.fulfill()
            }
        }
        let source = try XCTUnwrap(Bundle.main.url(forResource: "sea.wav", withExtension: nil))
        try engine.load(source)
        try engine.play()
        await fulfillment(of: [produced], timeout: 12)
        XCTAssertGreaterThan(latest.sampleCount, 0)
        XCTAssertGreaterThan(latest.sampleRate, 0)
        engine.pause()
        XCTAssertEqual(latest, .idle)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(latest, .idle, "Canceled worker frames cannot revive a paused visualization")
        let resumed = expectation(description: "Resuming the same engine rebuilds its PCM tap")
        fulfilled = false
        engine.onAnalysis = { frame in
            latest = frame
            if frame.status == .active, frame.rms > 0.000_01, !fulfilled {
                fulfilled = true
                resumed.fulfill()
            }
        }
        try engine.play()
        await fulfillment(of: [resumed], timeout: 12)
        let replacement = try XCTUnwrap(Bundle.main.url(forResource: "window.wav", withExtension: nil))
        try engine.load(replacement)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(latest, .idle)
        engine.stop()
        XCTAssertEqual(latest, .idle)
    }

    func testAuthorizedLiveNavidromeRawStreamProducesNonzeroPCM() async throws {
        guard let path = ProcessInfo.processInfo.environment["ONETAPE_LIVE_CONNECTION_FILE"] else {
            throw XCTSkip("Live server verification requires the external private connection file.")
        }
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [String: String]
        let connection = NavidromeConnection(id: "xctest-live", baseURL: try NavidromeClient.normalizedAddress(json["address"]!),
            username: json["username"]!, credentialID: "test-only-no-keychain")
        let client = NavidromeClient(connection: connection, password: json["password"]!)
        let catalog = try await client.fetchCatalog()
        let track = try XCTUnwrap(catalog.tracks.first)
        let remote = try XCTUnwrap(track.remote)
        let engine = AudioPlayback()
        defer { engine.stop() }
        let produced = expectation(description: "The sole streaming engine yields real nonzero PCM")
        var fulfilled = false
        var maximumRMS: Float = 0
        engine.onAnalysis = { frame in
            maximumRMS = max(maximumRMS, frame.rms)
            if frame.status == .active, frame.rms > 0.000_01, !fulfilled {
                fulfilled = true
                produced.fulfill()
            }
        }
        try engine.load(client.streamURL(songID: remote.songID), durationHint: track.duration)
        try engine.play()
        await fulfillment(of: [produced], timeout: 25)
        XCTAssertGreaterThan(maximumRMS, 0.000_01)
    }
}
