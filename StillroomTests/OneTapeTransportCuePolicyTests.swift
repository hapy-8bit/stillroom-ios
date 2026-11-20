import XCTest
@testable import Stillroom

final class OneTapeTransportCuePolicyTests: XCTestCase {
    func testRestoredAndRemoteSnapshotsDoNotCreateCues() {
        var policy = OneTapeTransportCuePolicy()
        XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: false, isPreparing: false,
                                      isForeground: true, now: 1))
        XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: true, isPreparing: false,
                                      isForeground: true, now: 2))
        XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: false, isPreparing: false,
                                      isForeground: true, now: 3))
    }

    func testExplicitPlayAcknowledgesActualPlaybackOnlyOnce() {
        var policy = OneTapeTransportCuePolicy()
        policy.userToggleRequested(trackID: "song", isPlaying: false, isPreparing: false, now: 1)
        XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: false, isPreparing: false,
                                      isForeground: true, now: 1.01))
        XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: false, isPreparing: true,
                                      isForeground: true, now: 1.1))
        XCTAssertEqual(policy.reconcile(trackID: "song", isPlaying: true, isPreparing: false,
                                        isForeground: true, now: 1.2), .playLatch)
        XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: true, isPreparing: false,
                                      isForeground: true, now: 1.3))
    }

    func testExplicitPauseWaitsForStoppedSnapshot() {
        var policy = OneTapeTransportCuePolicy()
        policy.userToggleRequested(trackID: "song", isPlaying: true, isPreparing: false, now: 1)
        XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: true, isPreparing: false,
                                      isForeground: true, now: 1.01))
        XCTAssertEqual(policy.reconcile(trackID: "song", isPlaying: false, isPreparing: false,
                                        isForeground: true, now: 1.1), .pauseRelease)
        XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: false, isPreparing: false,
                                      isForeground: true, now: 1.2))
    }

    func testEmptyAndPreparationCancellationStaySilent() {
        var policy = OneTapeTransportCuePolicy()
        policy.userToggleRequested(trackID: nil, isPlaying: false, isPreparing: false, now: 1)
        XCTAssertNil(policy.reconcile(trackID: nil, isPlaying: false, isPreparing: false,
                                      isForeground: true, now: 1.1))
        policy.userToggleRequested(trackID: "song", isPlaying: false, isPreparing: false, now: 2)
        policy.userToggleRequested(trackID: "song", isPlaying: false, isPreparing: true, now: 2.1)
        XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: false, isPreparing: false,
                                      isForeground: true, now: 2.2))
        XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: true, isPreparing: false,
                                      isForeground: true, now: 2.3))
    }

    func testFailureAndAbandonedPreparationCancelPendingCue() {
        for explicitError in [false, true] {
            var policy = OneTapeTransportCuePolicy()
            policy.userPlayRequested(trackID: "song", isPlaying: false, now: 1)
            XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: false, isPreparing: true,
                                          isForeground: true, now: 1.1))
            XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: false, isPreparing: false,
                                          hasError: explicitError, isForeground: true, now: 1.2))
            XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: true, isPreparing: false,
                                          isForeground: true, now: 2))
        }
    }

    func testBackgroundTrackChangeExpiryAndExplicitCancelDoNotLeakCue() {
        for cancellation in 0..<4 {
            var policy = OneTapeTransportCuePolicy(intentLifetime: 2)
            policy.userPlayRequested(trackID: "song", isPlaying: false, now: 1)
            switch cancellation {
            case 0:
                XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: true, isPreparing: false,
                                              isForeground: false, now: 1.1))
            case 1:
                XCTAssertNil(policy.reconcile(trackID: "other", isPlaying: true, isPreparing: false,
                                              isForeground: true, now: 1.1))
            case 2:
                XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: true, isPreparing: false,
                                              isForeground: true, now: 3.1))
            default: policy.cancel()
            }
            XCTAssertNil(policy.reconcile(trackID: "song", isPlaying: true, isPreparing: false,
                                          isForeground: true, now: 3.2))
        }
    }

    func testNewUserRequestReplacesEarlierIntentAndPlayingSelectionStaysSilent() {
        var policy = OneTapeTransportCuePolicy()
        policy.userPlayRequested(trackID: "first", isPlaying: false, now: 1)
        policy.userPlayRequested(trackID: "second", isPlaying: false, now: 1.1)
        XCTAssertEqual(policy.reconcile(trackID: "second", isPlaying: true, isPreparing: false,
                                        isForeground: true, now: 1.2), .playLatch)
        policy.userPlayRequested(trackID: "third", isPlaying: true, now: 2)
        XCTAssertNil(policy.reconcile(trackID: "third", isPlaying: true, isPreparing: false,
                                      isForeground: true, now: 2.1))
    }
}
