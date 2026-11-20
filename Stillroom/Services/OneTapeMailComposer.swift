import SwiftUI
import MessageUI

/// Presenting a draft never sends it. The system composer owns the final Send,
/// save or cancel action, and no music files/logs are attached automatically.
struct OneTapeMailComposer: UIViewControllerRepresentable {
    let draft: OneTapeMailDraft
    let onFinish: (OneTapeMailCompletion) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([draft.recipient])
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: (OneTapeMailCompletion) -> Void
        init(onFinish: @escaping (OneTapeMailCompletion) -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            if error != nil { onFinish(.failed); return }
            switch result {
            case .sent: onFinish(.sent)
            case .saved: onFinish(.saved)
            case .cancelled: onFinish(.cancelled)
            case .failed: onFinish(.failed)
            @unknown default: onFinish(.failed)
            }
        }
    }
}
