import SwiftUI

struct OneTapeSupportScreen: View {
    let destination: OneTapeSupportDestination
    @StateObject private var support = OneTapeSupportStore()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let document = destination.document { documentBody(document) }
                    else { contactBody }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(white: 0.065))
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .accessibilityIdentifier("support.close")
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(item: $support.mailDraft) { draft in
            OneTapeMailComposer(draft: draft, onFinish: support.completeMail)
                .ignoresSafeArea()
        }
        .alert(item: $support.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("知道了")))
        }
        .onDisappear { support.cancelPendingOpen() }
    }

    private func documentBody(_ document: OneTapeSupportDocument) -> some View {
        let content = document.content(contactEmail: support.configuration.supportEmail)
        return VStack(alignment: .leading, spacing: 24) {
            Text("更新日期：" + content.updatedOn)
                .font(.footnote).foregroundStyle(.secondary)
            ForEach(content.sections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section.title).font(.headline).accessibilityAddTraits(.isHeader)
                    Text(section.body).font(.body).lineSpacing(5).textSelection(.enabled)
                }
            }
            if let url = officialURL(document) {
                Link("查看公开版本", destination: url)
                    .accessibilityIdentifier("support.officialLink")
            }
            Button("复制全文") { support.copyDocument(document) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("support.copyDocument")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("support.document.\(document.rawValue)")
    }

    private var contactBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(destination == .feedback ? "告诉我们您的问题或建议。" : "与 One Cassette 开发者联系。")
                .font(.title3.weight(.semibold))
            if let email = support.configuration.supportEmail {
                Text(email).font(.body).textSelection(.enabled)
                    .accessibilityIdentifier("support.email")
                Button("复制邮箱", action: support.copyEmail)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("support.copyEmail")
            } else {
                Text("联系邮箱暂未公布。")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("support.emailUnavailable")
            }
            if destination == .feedback {
                Text("反馈内容").font(.headline).accessibilityAddTraits(.isHeader)
                TextEditor(text: $support.feedback)
                    .font(.body).padding(8)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
                    .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("反馈内容")
                    .accessibilityIdentifier("support.feedback.message")
            }
            Button {
                support.compose(isFeedback: destination == .feedback)
            } label: {
                Label(support.openingMail ? "正在打开邮件…" : "打开邮件撰写",
                      systemImage: "envelope")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(.black)
            .disabled(support.configuration.supportEmail == nil || support.openingMail)
            .accessibilityIdentifier("support.compose")
            Text("由您在邮件应用中确认发送。不会自动附加音乐、服务器信息或日志；请勿在反馈中填写密码。")
                .font(.footnote).foregroundStyle(.secondary)
            Text("One Cassette " + support.version).font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("support.version")
        }
    }

    private func officialURL(_ document: OneTapeSupportDocument) -> URL? {
        switch document {
        case .privacy: support.configuration.privacyURL
        case .terms: support.configuration.termsURL
        case .payment: nil
        }
    }
}
