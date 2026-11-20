import XCTest
@testable import Stillroom

@MainActor
final class OneTapeSupportStoreTests: XCTestCase {
    func testMailtoKeepsChineseNewlinesAndHeaderLikeTextInsideTwoEncodedValues() throws {
        let recipient = "support+ios@example.test"
        let subject = "中文反馈 + &bcc=unexpected@example.test"
        let body = "第一行 + &cc=other@example.test\r\nBcc: third@example.test\n?#第二行"
        let draft = OneTapeMailDraft(recipient: recipient, subject: subject, body: body)

        let url = try XCTUnwrap(OneTapeMailURL.make(draft))
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try XCTUnwrap(parts.queryItems)

        XCTAssertEqual(parts.scheme, "mailto")
        XCTAssertEqual(parts.path, recipient)
        XCTAssertNil(parts.fragment)
        XCTAssertEqual(items.map(\.name), ["subject", "body"])
        XCTAssertEqual(items.first?.value, subject)
        XCTAssertEqual(items.last?.value, body)
        XCTAssertTrue(url.absoluteString.contains("%2B"), "A plus in feedback must stay a literal plus")
        XCTAssertTrue(url.absoluteString.contains("%0A"), "Newlines belong to the encoded body")
        for injected in ["support@example.test?bcc=other@example.test",
                         "support@example.test\nBcc: other@example.test",
                         "support@example.test,other@example.test"] {
            XCTAssertNil(OneTapeMailURL.make(.init(recipient: injected, subject: subject, body: body)))
        }
    }

    func testConstructionAndUnconfiguredContactNeverInvokeSystemActions() {
        let actions = SupportActionProbe(canComposeMail: true)
        let store = OneTapeSupportStore(configuration: .init(), version: "test", actions: actions)
        XCTAssertTrue(actions.openedURLs.isEmpty)
        XCTAssertTrue(actions.copiedTexts.isEmpty)
        XCTAssertNil(store.mailDraft)

        store.feedback = "仅保留在页面里的反馈"
        store.compose(isFeedback: true)
        store.compose(isFeedback: false)
        store.copyEmail()

        XCTAssertTrue(actions.openedURLs.isEmpty)
        XCTAssertTrue(actions.copiedTexts.isEmpty)
        XCTAssertNil(store.mailDraft)
        XCTAssertFalse(store.openingMail)
        XCTAssertNotNil(store.notice)
        XCTAssertEqual(store.feedback, "仅保留在页面里的反馈")
    }

    func testExplicitComposeCreatesOnlyAnEditableDraftWithFeedbackAndAppVersion() throws {
        let actions = SupportActionProbe(canComposeMail: true)
        let configuration = OneTapeSupportConfiguration(supportEmail: "support+ios@example.test")
        let version = "9.8.7 (65)"
        let store = OneTapeSupportStore(configuration: configuration, version: version, actions: actions)
        let feedback = "  我的问题 & 建议\n第二行 + 保留\n  "
        store.feedback = feedback
        XCTAssertNil(store.mailDraft)

        store.compose(isFeedback: true)

        let draft = try XCTUnwrap(store.mailDraft)
        XCTAssertEqual(draft.recipient, configuration.supportEmail)
        // The outgoing body has a deliberate allowlist: user-entered text and
        // the provided app version. There is no player/catalog attachment input.
        XCTAssertEqual(draft.body, feedback.trimmingCharacters(in: .whitespacesAndNewlines)
                       + "\n\nOne Cassette " + version)
        XCTAssertEqual(store.feedback, feedback)
        XCTAssertTrue(actions.openedURLs.isEmpty)
        XCTAssertTrue(actions.copiedTexts.isEmpty)
        XCTAssertFalse(store.openingMail)
        store.compose(isFeedback: false)
        XCTAssertEqual(store.mailDraft, draft, "A second tap must not replace an in-progress draft")
    }

    func testEveryComposerCompletionPreservesFeedbackAndSentDoesNotClaimDelivery() throws {
        for result: OneTapeMailCompletion in [.cancelled, .saved, .sent, .failed] {
            let actions = SupportActionProbe(canComposeMail: true)
            let store = OneTapeSupportStore(configuration: .init(supportEmail: "support@example.test"),
                                           version: "test", actions: actions)
            store.feedback = "取消、草稿或邮件错误后仍需保留的原文"
            store.compose(isFeedback: true)
            XCTAssertNotNil(store.mailDraft)

            store.completeMail(result)

            XCTAssertNil(store.mailDraft)
            XCTAssertEqual(store.feedback, "取消、草稿或邮件错误后仍需保留的原文")
            XCTAssertTrue(actions.openedURLs.isEmpty)
            XCTAssertTrue(actions.copiedTexts.isEmpty)
            switch result {
            case .cancelled: XCTAssertNil(store.notice)
            case .saved: XCTAssertTrue(try XCTUnwrap(store.notice).title.contains("草稿"))
            case .sent:
                let notice = try XCTUnwrap(store.notice)
                XCTAssertTrue(notice.title.contains("系统邮件"))
                XCTAssertTrue(notice.message.contains("邮件应用"))
                XCTAssertFalse((notice.title + notice.message).contains("已送达"))
            case .failed: XCTAssertNotNil(store.notice)
            }
        }
    }

    func testFailedExternalMailOpenRestoresIdleAndLeavesExplicitCopyFallback() async throws {
        let actions = SupportActionProbe(canComposeMail: false)
        let started = expectation(description: "User-requested external mail open began")
        actions.onOpen = { started.fulfill() }
        let email = "support+ios@example.test"
        let store = OneTapeSupportStore(configuration: .init(supportEmail: email),
                                       version: "test", actions: actions)
        store.feedback = "应用无法打开邮件时保留的内容"

        store.compose(isFeedback: true)
        XCTAssertTrue(store.openingMail)
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(actions.openedURLs.count, 1)
        XCTAssertTrue(actions.copiedTexts.isEmpty, "Opening mail must not silently write the clipboard")
        XCTAssertNil(store.mailDraft)
        store.compose(isFeedback: true)
        XCTAssertEqual(actions.openedURLs.count, 1, "Repeated taps cannot start a second pending open")

        actions.finishOpen(false)
        for _ in 0..<100 where store.openingMail { try await Task.sleep(for: .milliseconds(10)) }

        XCTAssertFalse(store.openingMail)
        XCTAssertEqual(store.feedback, "应用无法打开邮件时保留的内容")
        XCTAssertNotNil(store.notice)
        XCTAssertTrue(try XCTUnwrap(store.notice).message.contains("复制"))
        XCTAssertTrue(actions.copiedTexts.isEmpty)
        store.copyEmail()
        XCTAssertEqual(actions.copiedTexts, [email])
        XCTAssertEqual(store.feedback, "应用无法打开邮件时保留的内容")
    }
}

@MainActor
private final class SupportActionProbe: OneTapeSupportActions {
    let canComposeMail: Bool
    private(set) var copiedTexts: [String] = []
    private(set) var openedURLs: [URL] = []
    var onOpen: (() -> Void)?
    private var openContinuation: CheckedContinuation<Bool, Never>?

    init(canComposeMail: Bool) { self.canComposeMail = canComposeMail }

    func copy(_ text: String) { copiedTexts.append(text) }

    func openMail(_ url: URL) async -> Bool {
        openedURLs.append(url)
        onOpen?()
        return await withCheckedContinuation { openContinuation = $0 }
    }

    func finishOpen(_ result: Bool) {
        let continuation = openContinuation
        openContinuation = nil
        continuation?.resume(returning: result)
    }
}
