import XCTest
import Combine
import CoreGraphics
@testable import Stillroom

@MainActor
final class OneTapePhotoFrameStoreTests: XCTestCase {
    func testDrawRunsOffMainAndCoalescesToOnlyTheLatestPendingFrame() async throws {
        let started = expectation(description: "First worker started")
        let release = DispatchSemaphore(value: 0)
        let probe = FrameProbe()
        let store = OneTapePhotoFrameStore { request in
            XCTAssertFalse(Thread.isMainThread)
            probe.append(request.phase)
            if request.phase == 1 {
                started.fulfill()
                _ = release.wait(timeout: .now() + 3)
            }
            return Self.pixel(UInt8(request.phase))
        }
        store.request(request(1))
        await fulfillment(of: [started], timeout: 2)
        for phase in 2...30 { store.request(request(Double(phase))) }
        release.signal()
        await wait { Self.value(store.image) == 30 }
        XCTAssertEqual(probe.values, [1, 30])
        store.cancel()
    }

    func testPauseInvalidatesRunningCompletionAndPublishesOnlyFrozenPose() async throws {
        let started = expectation(description: "Running draw began")
        let release = DispatchSemaphore(value: 0)
        let store = OneTapePhotoFrameStore { request in
            if request.running {
                started.fulfill()
                _ = release.wait(timeout: .now() + 3)
            }
            return Self.pixel(UInt8(request.phase))
        }
        var published: [UInt8] = []
        let observation = store.$image.sink { image in
            if let value = Self.value(image) { published.append(value) }
        }
        store.request(request(10))
        await fulfillment(of: [started], timeout: 2)
        store.request(request(11, running: false))
        release.signal()
        await wait { Self.value(store.image) == 11 }
        XCTAssertEqual(published, [11])
        observation.cancel()
        store.cancel()
    }

    func testCancelDiscardsCompletionAndSurfaceReplacementCanResume() async throws {
        let started = expectation(description: "Old draw began")
        let release = DispatchSemaphore(value: 0)
        let store = OneTapePhotoFrameStore { request in
            if request.phase == 1 {
                started.fulfill()
                _ = release.wait(timeout: .now() + 3)
            }
            return Self.pixel(UInt8(request.phase))
        }
        store.request(request(1))
        await fulfillment(of: [started], timeout: 2)
        store.cancel()
        store.request(.init(style: .rain, phase: 8, size: CGSize(width: 50, height: 100),
                            scale: 1, running: false))
        release.signal()
        await wait { Self.value(store.image) == 8 }
        store.request(.init(style: .rain, phase: .nan, size: .zero, scale: 1, running: false))
        XCTAssertEqual(Self.value(store.image), 8)
        store.cancel()
    }

    private func request(_ phase: Double, running: Bool = true) -> OneTapePhotoFrameStore.Request {
        .init(style: .trails, phase: phase, size: CGSize(width: 100, height: 50), scale: 1, running: running)
    }

    private func wait(_ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertTrue(condition())
    }

    nonisolated private static func pixel(_ value: UInt8) -> CGImage? {
        let data = Data([value, 0, 0, 255]) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    nonisolated private static func value(_ image: CGImage?) -> UInt8? {
        guard let image, let data = image.dataProvider?.data else { return nil }
        return CFDataGetBytePtr(data)[0]
    }
}

private final class FrameProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var phases: [Double] = []
    var values: [Double] { lock.lock(); defer { lock.unlock() }; return phases }
    func append(_ phase: Double) { lock.lock(); defer { lock.unlock() }; phases.append(phase) }
}
