import Foundation
import Combine

@MainActor
final class OneTapeSupportStore: ObservableObject {
    let configuration: OneTapeSupportConfiguration
    let version: String
    @Published var feedback = ""
    @Published var mailDraft: OneTapeMailDraft?
    @Published var notice: OneTapeSupportNotice?
    @Published private(set) var openingMail = false
    private let actions: OneTapeSupportActions
    private var mailTask: Task<Void, Never>?

    init(configuration: OneTapeSupportConfiguration = .bundled(),
         version: String = OneTapeMailURL.version(), actions: OneTapeSupportActions? = nil) {
        self.configuration = configuration
        self.version = version
        self.actions = actions ?? SystemOneTapeSupportActions()
    }

    deinit { mailTask?.cancel() }

    func copyEmail() {
        guard let email = configuration.supportEmail else { unavailable(); return }
        actions.copy(email)
        notice = .init(title: "已复制邮箱", message: "可粘贴到您使用的邮件应用中。")
    }

    func copyDocument(_ document: OneTapeSupportDocument) {
        actions.copy(document.content(contactEmail: configuration.supportEmail).plainText)
        notice = .init(title: "已复制全文", message: document.title + "已复制到剪贴板。")
    }

    func compose(isFeedback: Bool) {
        guard !openingMail, mailDraft == nil else { return }
        guard let email = configuration.supportEmail else { unavailable(); return }
        let text = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        if isFeedback && text.isEmpty {
            notice = .init(title: "请填写反馈", message: "请描述遇到的问题或建议，再打开邮件。")
            return
        }
        guard text.count <= 8_000 else {
            notice = .init(title: "反馈内容过长", message: "请将内容控制在 8000 字以内。")
            return
        }
        let draft = OneTapeMailDraft(recipient: email,
            subject: isFeedback ? "One Cassette 问题反馈" : "联系 One Cassette",
            body: (isFeedback ? text : "您好，One Cassette 开发者：\n\n") + "\n\nOne Cassette " + version)
        if actions.canComposeMail { mailDraft = draft; return }
        guard let url = OneTapeMailURL.make(draft) else { unavailable(); return }
        openingMail = true
        mailTask = Task { [weak self, actions] in
            let opened = await actions.openMail(url)
            guard !Task.isCancelled, let self else { return }
            self.openingMail = false
            if !opened {
                self.notice = .init(title: "无法打开邮件应用",
                    message: "请先设置邮件应用，或复制联系邮箱后自行发送。反馈内容仍保留在当前页面。")
            }
            self.mailTask = nil
        }
    }

    func completeMail(_ result: OneTapeMailCompletion) {
        mailDraft = nil
        switch result {
        case .sent: notice = .init(title: "已交给系统邮件", message: "后续发送状态请在邮件应用中查看。")
        case .saved: notice = .init(title: "已保存邮件草稿", message: "可在系统邮件中继续编辑和发送。")
        case .cancelled: break
        case .failed: notice = .init(title: "邮件未能完成", message: "反馈内容仍保留在当前页面，可稍后重试或复制邮箱。")
        }
    }

    func cancelPendingOpen() {
        mailTask?.cancel(); mailTask = nil; openingMail = false
    }

    private func unavailable() {
        notice = .init(title: "联系邮箱暂不可用", message: "当前版本尚未提供联系邮箱，请稍后查看更新。")
    }
}
