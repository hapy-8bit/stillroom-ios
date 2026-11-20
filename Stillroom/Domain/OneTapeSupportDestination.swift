import Foundation

enum OneTapeSupportDestination: String, Identifiable {
    case privacy, terms, contact, feedback, payment

    var id: String { rawValue }
    var document: OneTapeSupportDocument? {
        switch self {
        case .privacy: .privacy
        case .terms: .terms
        case .payment: .payment
        case .contact, .feedback: nil
        }
    }
    var title: String {
        document?.title ?? (self == .contact ? "联系我们" : "问题反馈")
    }
}

struct OneTapeMailDraft: Identifiable, Equatable {
    let id = UUID()
    let recipient: String
    let subject: String
    let body: String
}

enum OneTapeMailCompletion { case sent, saved, cancelled, failed }

struct OneTapeSupportNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
