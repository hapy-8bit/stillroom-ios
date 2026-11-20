import UIKit
import MessageUI

@MainActor
protocol OneTapeSupportActions: AnyObject {
    var canComposeMail: Bool { get }
    func copy(_ text: String)
    func openMail(_ url: URL) async -> Bool
}

@MainActor
final class SystemOneTapeSupportActions: OneTapeSupportActions {
    var canComposeMail: Bool { MFMailComposeViewController.canSendMail() }
    func copy(_ text: String) { UIPasteboard.general.string = text }

    func openMail(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { opened in
                continuation.resume(returning: opened)
            }
        }
    }
}

enum OneTapeMailURL {
    static func make(_ draft: OneTapeMailDraft) -> URL? {
        guard OneTapeSupportConfiguration(supportEmail: draft.recipient).supportEmail != nil else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = draft.recipient
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?#")
        // Encode feedback as RFC 6068 query values. An ampersand or newline in
        // the user's text must never become an extra recipient/header field.
        guard let subject = draft.subject.addingPercentEncoding(withAllowedCharacters: allowed),
              let body = draft.body.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        components.percentEncodedQuery = "subject=" + subject + "&body=" + body
        return components.url
    }

    static func version(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return version + " (" + build + ")"
    }
}
