import Foundation

/// Optional publisher-owned contact details. Reading a configuration never
/// opens a webpage or sends feedback; only a user action may do so.
struct OneTapeSupportConfiguration: Equatable, Sendable {
    let supportEmail: String?
    let privacyURL: URL?
    let termsURL: URL?

    init(supportEmail: String? = nil, privacyURL: URL? = nil, termsURL: URL? = nil) {
        self.supportEmail = Self.validEmail(supportEmail)
        self.privacyURL = Self.validWebURL(privacyURL?.absoluteString)
        self.termsURL = Self.validWebURL(termsURL?.absoluteString)
    }

    init(infoDictionary: [String: Any]) {
        supportEmail = Self.validEmail(infoDictionary["OneTapeSupportEmail"] as? String)
        privacyURL = Self.validWebURL(infoDictionary["OneTapePrivacyURL"] as? String)
        termsURL = Self.validWebURL(infoDictionary["OneTapeTermsURL"] as? String)
    }

    static func bundled(bundle: Bundle = .main) -> OneTapeSupportConfiguration {
        OneTapeSupportConfiguration(infoDictionary: bundle.infoDictionary ?? [:])
    }

    private static func validEmail(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.utf8.count <= 254,
              value.range(of: "^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9](?:[A-Za-z0-9\\-]*[A-Za-z0-9])?(?:\\.[A-Za-z0-9](?:[A-Za-z0-9\\-]*[A-Za-z0-9])?)+$",
                          options: .regularExpression) != nil,
              let local = value.split(separator: "@").first, local.utf8.count <= 64,
              !local.hasPrefix("."), !local.hasSuffix("."), !local.contains("..") else { return nil }
        return value
    }

    private static func validWebURL(_ value: String?) -> URL? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let parts = URLComponents(string: value), parts.scheme?.lowercased() == "https",
              parts.host?.isEmpty == false, parts.user == nil, parts.password == nil else { return nil }
        return parts.url
    }
}
