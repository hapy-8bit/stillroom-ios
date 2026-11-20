import XCTest
@testable import Stillroom

final class OneTapePlaybackModeTests: XCTestCase {
    func testPlaybackModeCycleFollowsListSingleShuffleOrder() {
        XCTAssertEqual(OneTapePlaybackMode(shuffled: false, repeatMode: .off), .listLoop)
        XCTAssertEqual(OneTapePlaybackMode(shuffled: false, repeatMode: .all), .listLoop)
        XCTAssertEqual(OneTapePlaybackMode(shuffled: false, repeatMode: .one), .singleLoop)
        XCTAssertEqual(OneTapePlaybackMode(shuffled: true, repeatMode: .all), .shuffle)
        XCTAssertEqual(OneTapePlaybackMode(shuffled: true, repeatMode: .one), .shuffle)

        XCTAssertEqual(OneTapePlaybackMode.listLoop.next, .singleLoop)
        XCTAssertEqual(OneTapePlaybackMode.singleLoop.next, .shuffle)
        XCTAssertEqual(OneTapePlaybackMode.shuffle.next, .listLoop)
    }

    @MainActor
    func testPlayerStoreCyclePlaybackModeReconcilesQueueState() {
        let store = PlayerStore(emptyLibrary: true)
        XCTAssertEqual(store.playbackMode, .listLoop)

        store.cyclePlaybackMode()
        XCTAssertEqual(store.playbackMode, .singleLoop)
        XCTAssertFalse(store.queue.shuffled)
        XCTAssertEqual(store.queue.repeatMode, .one)

        store.cyclePlaybackMode()
        XCTAssertEqual(store.playbackMode, .shuffle)
        XCTAssertTrue(store.queue.shuffled)
        XCTAssertEqual(store.queue.repeatMode, .all)

        store.cyclePlaybackMode()
        XCTAssertEqual(store.playbackMode, .listLoop)
        XCTAssertFalse(store.queue.shuffled)
        XCTAssertEqual(store.queue.repeatMode, .all)
    }

    @MainActor
    func testOrientationAcceptsOnlyLeftwardTurnAndPortrait() {
        XCTAssertEqual(OneTapeOrientationMonitor.supportedTurn(for: .portrait, retaining: 0), 0)
        XCTAssertEqual(OneTapeOrientationMonitor.supportedTurn(for: .landscapeLeft, retaining: 0), 1)
        XCTAssertEqual(OneTapeOrientationMonitor.supportedTurn(for: .landscapeRight, retaining: 1), 0)
        XCTAssertEqual(OneTapeOrientationMonitor.supportedTurn(for: .portraitUpsideDown, retaining: 1), 0)
        XCTAssertEqual(OneTapeOrientationMonitor.supportedTurn(for: .faceUp, retaining: 1), 1)
    }
}
