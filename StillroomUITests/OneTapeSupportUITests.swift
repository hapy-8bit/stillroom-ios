import XCTest

/// Exercises app-local documents and contact controls on a dedicated QA
/// simulator. It never opens an external website, mail app or payment flow.
final class OneTapeSupportUITests: XCTestCase {
    @MainActor
    func testPrivacyTermsAndPaymentDocumentsCopyAndReturnToSettings() {
        continueAfterFailure = false
        let app = launchSettings()
        for (kind, title) in [("privacy", "隐私政策"), ("terms", "用户服务协议"), ("payment", "付费说明")] {
            let row = button("settings." + kind, app: app)
            makeVisible(row, app: app)
            tap(row, app: app)
            let document = app.descendants(matching: .any)
                .matching(identifier: "support.document." + kind).firstMatch
            XCTAssertTrue(document.waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertTrue(app.navigationBars[title].exists)
            if kind == "payment" { assertCurrentPaymentExplanation(app) }
            screenshot("support-01-\(kind)-document")

            let copy = button("support.copyDocument", app: app)
            makeVisible(copy, app: app)
            tap(copy, app: app)
            dismissNotice("已复制全文", app: app)
            closeSupport(app)
            XCTAssertTrue(row.waitForExistence(timeout: 8), "Closing \(title) returns to the existing settings page.")
        }
    }

    @MainActor
    func testContactFeedbackAndStudioPaymentInformationWithoutSending() {
        continueAfterFailure = false
        let app = launchSettings()
        let contact = button("settings.contact", app: app)
        makeVisible(contact, app: app)
        tap(contact, app: app)
        XCTAssertTrue(app.navigationBars["联系我们"].waitForExistence(timeout: 10))
        let email = app.staticTexts.matching(identifier: "support.email").firstMatch
        let emailConfigured = email.waitForExistence(timeout: 2)
        if emailConfigured {
            XCTAssertTrue(email.label.contains("@"))
            tap(button("support.copyEmail", app: app), app: app)
            dismissNotice("已复制邮箱", app: app)
        } else {
            XCTAssertTrue(app.staticTexts.matching(identifier: "support.emailUnavailable").firstMatch.exists)
            XCTAssertFalse(button("support.compose", app: app).isEnabled,
                           "An unpublished address must not invent a recipient or start mail.")
        }
        XCTAssertTrue(app.staticTexts.matching(identifier: "support.version").firstMatch.exists)
        screenshot("support-02-contact-configuration-state")
        closeSupport(app)

        let feedback = button("settings.feedback", app: app)
        makeVisible(feedback, app: app)
        tap(feedback, app: app)
        XCTAssertTrue(app.navigationBars["问题反馈"].waitForExistence(timeout: 10))
        let editor = app.textViews.matching(identifier: "support.feedback.message").firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 8), app.debugDescription)
        let compose = button("support.compose", app: app)
        makeVisible(compose, app: app)
        if emailConfigured {
            tap(compose, app: app)
            dismissNotice("请填写反馈", app: app)
        } else {
            XCTAssertFalse(compose.isEnabled)
        }
        makeVisible(editor, app: app, towardTop: true)
        tap(editor, app: app)
        let feedbackText = "独立 QA 验证：专辑封面与设置页面操作建议。"
        editor.typeText(feedbackText)
        XCTAssertTrue((editor.value as? String ?? "").contains(feedbackText))
        screenshot("support-03-feedback-editable-without-send")
        // Do not tap Compose after entering text: no email is opened or sent.
        closeSupport(app)

        let studio = button("settings.studio", app: app)
        makeVisible(studio, app: app, towardTop: true)
        tap(studio, app: app)
        let paymentExplanation = button("studio.preview", app: app)
        makeVisible(paymentExplanation, app: app)
        XCTAssertEqual(paymentExplanation.label, "付费说明")
        XCTAssertTrue(app.staticTexts.matching(identifier: "studio.price").firstMatch.label.contains("一次性买断"))
        tap(paymentExplanation, app: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "support.document.payment")
            .firstMatch.waitForExistence(timeout: 10), app.debugDescription)
        assertCurrentPaymentExplanation(app)
        screenshot("support-04-studio-opens-payment-document")
        closeSupport(app)
        XCTAssertTrue(paymentExplanation.waitForExistence(timeout: 8))
        tap(button("studio.close", app: app), app: app)
        XCTAssertTrue(app.buttons["tape.play"].waitForExistence(timeout: 8))
    }

    @MainActor
    private func launchSettings() -> XCUIApplication {
        let app = XCUIApplication()
        // Skip account/music restoration without clearing any persisted data.
        app.launchArguments = ["--one-tape-empty", "--one-tape-appearance-fixture"]
        app.launch()
        tap(button("tape.glass", app: app), app: app)
        tap(button("nav.settings", app: app), app: app)
        XCTAssertTrue(app.staticTexts["设置"].waitForExistence(timeout: 8))
        return app
    }

    @MainActor
    private func assertCurrentPaymentExplanation(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:
            "label CONTAINS %@ AND label CONTAINS %@", "不会自动发起付款", "系统页面确认")).firstMatch.exists,
            "Reading the payment explanation must not start checkout.")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "OneVinyl_1")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
            "一次性买断", "不自动续费")).firstMatch.exists,
            "Both settings and Studio must describe a one-time purchase rather than an undecided billing period.")
        XCTAssertTrue(app.navigationBars["付费说明"].exists)
        XCTAssertTrue(button("support.close", app: app).isHittable)
    }

    @MainActor
    private func closeSupport(_ app: XCUIApplication) {
        let close = button("support.close", app: app)
        tap(close, app: app)
        waitUntil("The nested support sheet is dismissed") { !close.exists }
        // The parent sheet's AX controls can return before the native dismissal
        // animation finishes releasing its modal touch surface.
        Thread.sleep(forTimeInterval: 0.4)
    }

    @MainActor
    private func dismissNotice(_ title: String, app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 8), app.debugDescription)
        let dismiss = app.buttons.matching(NSPredicate(format: "label == %@", "知道了")).firstMatch
        tap(dismiss, app: app)
        waitUntil("The local confirmation notice is dismissed") { !app.staticTexts[title].exists }
    }

    @MainActor
    private func button(_ identifier: String, app: XCUIApplication) -> XCUIElement {
        // iOS 27 sometimes exposes a native action as nested AX buttons.
        app.buttons.matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func makeVisible(_ element: XCUIElement, app: XCUIApplication, towardTop: Bool = false) {
        for _ in 0..<16 where !(element.exists && element.isHittable) {
            if towardTop { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable, app.debugDescription)
    }

    @MainActor
    private func tap(_ element: XCUIElement, app: XCUIApplication) {
        waitUntil("Expected a hittable control. \(element)") {
            element.exists && element.isHittable && element.isEnabled
        }
        element.tap()
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    private func waitUntil(_ message: String, timeout: TimeInterval = 8, condition: @escaping () -> Bool) {
        if condition() { return }
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed, message)
    }

    @MainActor
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
