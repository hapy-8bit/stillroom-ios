import XCTest
@testable import Stillroom

final class CraftCompletionGateTests: XCTestCase {
    func testSameEditionIsNotAutomaticallyRetriedWhenItsCommitHasNotPublished() {
        let session = finishedSession()
        var gate = CraftCompletionGate()
        XCTAssertEqual(gate.claim(session: session, records: [session.record]), session.record.id)
        XCTAssertNil(gate.claim(session: session, records: [session.record]))
        var laterSnapshot = session.record
        laterSnapshot.updatedAt = Date(timeIntervalSince1970: 1_000)
        laterSnapshot.collectedAt = Date(timeIntervalSince1970: 1_000)
        XCTAssertNil(gate.claim(session: session, records: [laterSnapshot]), "Lifecycle timestamps do not create a new printed edition")
    }

    func testNewEditionWithTheSameIDCanClaimAfterAnOlderEditionWasAttempted() {
        let first = finishedSession()
        var gate = CraftCompletionGate()
        XCTAssertNotNil(gate.claim(session: first, records: [first.record]))
        var replacement = first
        replacement.record.title = "第二次压制"
        XCTAssertEqual(replacement.record.id, first.record.id)
        XCTAssertEqual(gate.claim(session: replacement, records: [replacement.record]), first.record.id)
        XCTAssertNil(gate.claim(session: replacement, records: [replacement.record]))
    }

    func testAnEditedArchiveCannotReceiveCompletionFromTheOldListeningEdition() {
        let oldSession = finishedSession()
        var edited = oldSession.record
        edited.sideA.reverse()
        var gate = CraftCompletionGate()
        XCTAssertNil(gate.claim(session: oldSession, records: [edited]))
        XCTAssertEqual(gate.claim(session: oldSession, records: [oldSession.record]), oldSession.record.id,
                       "A mismatched archive must not consume the old edition's eligible claim")
    }

    func testManualBoundaryWithoutEveryDecoderEndDoesNotClaim() {
        var session = finishedSession()
        session.reachedEndIDs.remove(session.record.sideA[0])
        var gate = CraftCompletionGate()
        XCTAssertFalse(session.allReachedEnd)
        XCTAssertNil(gate.claim(session: session, records: [session.record]))
    }

    func testAlreadyCompletedEditionDoesNotClaim() {
        let session = finishedSession()
        var completed = session.record
        completed.completedAt = Date()
        var gate = CraftCompletionGate()
        XCTAssertNil(gate.claim(session: session, records: [completed]))
    }

    func testListeningAndFlipBoundariesCannotClaimEvenWithAllTracksMarked() {
        var session = finishedSession()
        var gate = CraftCompletionGate()
        session.phase = .listening
        XCTAssertNil(gate.claim(session: session, records: [session.record]))
        session.phase = .awaitingFlip
        XCTAssertNil(gate.claim(session: session, records: [session.record]))
        session.phase = .finished
        XCTAssertEqual(gate.claim(session: session, records: [session.record]), session.record.id)
    }

    func testMissingSessionAndMissingArchiveRecordCannotClaim() {
        let session = finishedSession()
        var gate = CraftCompletionGate()
        XCTAssertNil(gate.claim(session: nil, records: [session.record]))
        XCTAssertNil(gate.claim(session: session, records: []))
        XCTAssertNotNil(gate.claim(session: session, records: [session.record]))
    }

    private func finishedSession() -> CraftListeningSession {
        let record = CraftedRecord(id: "completion-record", title: "第一次压制", sideA: ["first", "second"],
                                   sideB: ["third"], isDraft: false)
        return CraftListeningSession(record: record, side: .b, phase: .finished,
                                     reachedEndIDs: Set(record.allTrackIDs))
    }
}
