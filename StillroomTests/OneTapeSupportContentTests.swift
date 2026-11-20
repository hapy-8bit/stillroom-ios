import XCTest
@testable import Stillroom

final class OneTapeSupportContentTests: XCTestCase {
    func testNoConfigurationDoesNotInventPublicContactOrAgreementLinks() {
        let configuration = OneTapeSupportConfiguration(infoDictionary: [:])
        XCTAssertNil(configuration.supportEmail)
        XCTAssertNil(configuration.privacyURL)
        XCTAssertNil(configuration.termsURL)
        for kind in OneTapeSupportDocument.allCases {
            let content = kind.content(contactEmail: configuration.supportEmail)
            XCTAssertEqual(Set(content.sections.map(\.id)).count, content.sections.count)
        }
    }

    func testConfiguredContactIsAvailableInEveryOfflineDocumentAndCopyText() throws {
        let configuration = OneTapeSupportConfiguration(infoDictionary: [
            "OneTapeSupportEmail": " support+ios@example.test ",
            "OneTapePrivacyURL": "https://example.test/privacy?language=zh#contact",
            "OneTapeTermsURL": "https://example.test/terms"
        ])
        XCTAssertEqual(configuration.supportEmail, "support+ios@example.test")
        XCTAssertEqual(configuration.privacyURL?.host, "example.test")
        XCTAssertEqual(configuration.termsURL?.path, "/terms")
        for kind in OneTapeSupportDocument.allCases {
            let content = kind.content(contactEmail: configuration.supportEmail)
            XCTAssertTrue(content.plainText.contains(try XCTUnwrap(configuration.supportEmail)))
        }
    }

    func testMalformedContactAndUnsafeAgreementSchemesStayUnavailable() {
        for email in ["", "not-an-email", "user@example.test\nBcc: other@example.test",
                      "user@example.test?subject=secret", "user@-bad.test", ".user@example.test",
                      "user..name@example.test"] {
            XCTAssertNil(OneTapeSupportConfiguration(supportEmail: email).supportEmail)
        }
        for text in ["javascript:alert(1)", "file:///privacy.html", "http://example.test/privacy",
                     "https://user:password@example.test/privacy", "https:///privacy"] {
            let configuration = OneTapeSupportConfiguration(infoDictionary: [
                "OneTapePrivacyURL": text, "OneTapeTermsURL": text
            ])
            XCTAssertNil(configuration.privacyURL)
            XCTAssertNil(configuration.termsURL)
        }
    }
}
