import XCTest
@testable import Stillroom

final class TurntableChromeStateTests: XCTestCase {
    func testOldIdleDeadlineCannotCloseNewInteraction() {
        var state = TurntableChromeState()
        state.reveal()
        let oldDeadline = state.revision
        state.reveal()
        state.finishIdle(revision: oldDeadline)
        XCTAssertTrue(state.showsTools)
        state.finishIdle(revision: state.revision)
        XCTAssertEqual(state.mode, .collapsed)
    }

    func testEditingAndNavigationInvalidatePendingIdle() {
        var state = TurntableChromeState()
        state.reveal()
        let deadline = state.revision
        state.editAppearance()
        state.finishIdle(revision: deadline)
        XCTAssertTrue(state.showsAppearance)
        state.collapse()
        state.finishIdle(revision: deadline)
        XCTAssertEqual(state.mode, .collapsed)
    }
}
