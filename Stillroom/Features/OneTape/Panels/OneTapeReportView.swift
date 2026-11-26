import SwiftUI

/// Concise, scannable iOS complaint & report form modeled after the HarmonyOS
/// One Cassette compliance flow (category, target, details, optional evidence,
/// reply email, prefilled mail draft & clipboard copy) without verbose essays.
struct OneTapeReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = OneTapeReportDraft()
    @State private var mailDraft: OneTapeMailDraft?
    @State private var notice: OneTapeSupportNotice?
    @State private var openingMail = false
    @State private var mailTask: Task<Void, Never>?

    private let actions: any OneTapeSupportActions = SystemOneTapeSupportActions()
    private let configuration = OneTapeSupportConfiguration.bundled()
    private let version = OneTapeMailURL.version()
    private let accent = Color(red: 0.89, green: 0.57, blue: 0.35)

    private var recipientEmail: String {
        configuration.supportEmail ?? "hapy8bit@163.com"
    }

    private let chipColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerStrip
                    categoryGrid
                    formCard
                    actionButtons
                    safetyNote
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .background(Color(white: 0.065).ignoresSafeArea())
            .navigationTitle("投诉举报")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(.white.opacity(0.85))
                        .accessibilityIdentifier("report.close")
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(item: $mailDraft) { item in
            OneTapeMailComposer(draft: item, onFinish: handleMailCompletion)
                .ignoresSafeArea()
        }
        .alert(item: $notice) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("知道了"))
            )
        }
        .onDisappear {
            mailTask?.cancel()
            mailTask = nil
            openingMail = false
        }
    }

    // MARK: - Subviews

    private var headerStrip: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("核查反馈邮箱")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                Text(recipientEmail)
                    .font(.custom("GeistMono-Regular", fixedSize: 13))
                    .foregroundStyle(accent)
                    .textSelection(.enabled)
            }
            Spacer()
            Button {
                actions.copy(recipientEmail)
                notice = .init(title: "已复制邮箱", message: recipientEmail)
            } label: {
                Text("复制邮箱")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("report.copyEmail")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("举报类型")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Text("*")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }

            LazyVGrid(columns: chipColumns, spacing: 8) {
                ForEach(OneTapeReportCategory.allCases) { category in
                    let selected = draft.category == category
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            draft.category = category
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selected ? accent : .white.opacity(0.32))
                            Text(category.chipTitle)
                                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? .white.opacity(0.95) : .white.opacity(0.72))
                                .lineLimit(1)
                                .minimumScaleFactor(0.84)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                        .background(
                            selected ? accent.opacity(0.14) : Color.white.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    selected ? accent.opacity(0.62) : Color.white.opacity(0.08),
                                    lineWidth: selected ? 1.0 : 0.5
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("report.category.\(category.rawValue)")
                }
            }
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Target (Required)
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("投诉或举报对象", required: true)
                TextField("歌曲、艺人、专辑或应用功能", text: $draft.target)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.92))
                    .tint(accent)
                    .accessibilityIdentifier("report.target")
            }
            .padding(16)

            hairline

            // Details (Required, max 1000 chars)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    fieldLabel("详细说明", required: true)
                    Spacer()
                    Text("\(draft.details.count)/\(OneTapeReportDraft.maxDetailsLength)")
                        .font(.custom("GeistMono-Regular", fixedSize: 11))
                        .foregroundStyle(.white.opacity(0.36))
                }
                ZStack(alignment: .topLeading) {
                    if draft.details.isEmpty {
                        Text("说明具体情况、发现时间与原因")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.28))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $draft.details)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.92))
                        .tint(accent)
                        .frame(minHeight: 112)
                        .scrollContentBackground(.hidden)
                        .onChange(of: draft.details) { _, newValue in
                            if newValue.count > OneTapeReportDraft.maxDetailsLength {
                                draft.details = String(newValue.prefix(OneTapeReportDraft.maxDetailsLength))
                            }
                        }
                        .accessibilityIdentifier("report.details")
                }
            }
            .padding(16)

            hairline

            // Optional Evidence
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("证据或线索（选填）", required: false)
                TextField("链接或线索说明，截图可在邮件中添加", text: $draft.evidence, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2...4)
                    .tint(accent)
                    .accessibilityIdentifier("report.evidence")
            }
            .padding(16)

            hairline

            // Optional Reply Email
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("回复邮箱（选填）", required: false)
                TextField("留空时默认回复发件邮箱", text: $draft.replyEmail)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.88))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .tint(accent)
                    .accessibilityIdentifier("report.replyEmail")
            }
            .padding(16)
        }
        .background(.white.opacity(0.038), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: openMailDraft) {
                HStack(spacing: 8) {
                    if openingMail {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(openingMail ? "正在打开邮件…" : "打开邮件草稿")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(draft.isReady ? Color.black.opacity(0.90) : .white.opacity(0.40))
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    draft.isReady ? accent : Color.white.opacity(0.10),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .disabled(openingMail)
            .accessibilityIdentifier("report.openMail")

            Button(action: copyReport) {
                HStack(spacing: 7) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                    Text("复制举报内容")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.82))
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(.white.opacity(0.07), in: Capsule())
                .overlay { Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.5) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("report.copy")
        }
    }

    private var safetyNote: some View {
        Text("提交前将在邮件中由你核对并发送；请勿填写服务器密码、令牌或敏感隐私信息。")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.36))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var hairline: some View {
        Rectangle()
            .fill(.white.opacity(0.07))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private func fieldLabel(_ title: String, required: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
            if required {
                Text("*")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }
        }
    }

    // MARK: - Actions

    private func openMailDraft() {
        if let error = draft.validationError {
            notice = .init(title: "请完善必填项", message: error)
            return
        }
        let prepared = draft.mailDraft(recipient: recipientEmail, version: version)
        if actions.canComposeMail {
            mailDraft = prepared
            return
        }
        guard let url = OneTapeMailURL.make(prepared) else {
            notice = .init(title: "无法创建邮件链接", message: "请使用下方“复制举报内容”后手动发送至 \(recipientEmail)。")
            return
        }
        openingMail = true
        mailTask = Task {
            let opened = await actions.openMail(url)
            guard !Task.isCancelled else { return }
            openingMail = false
            mailTask = nil
            if !opened {
                notice = .init(
                    title: "未找到可用邮件应用",
                    message: "可点击“复制举报内容”，手动粘贴并发送至 \(recipientEmail)。"
                )
            }
        }
    }

    private func copyReport() {
        if let error = draft.validationError {
            notice = .init(title: "请完善必填项", message: error)
            return
        }
        actions.copy(draft.clipboardText(recipient: recipientEmail, version: version))
        notice = .init(title: "已复制举报内容", message: "收件邮箱与表单内容已复制到剪贴板。")
    }

    private func handleMailCompletion(_ result: OneTapeMailCompletion) {
        mailDraft = nil
        switch result {
        case .sent:
            notice = .init(title: "已交给系统邮件", message: "核查结果将通过邮件回复。")
        case .saved:
            notice = .init(title: "已保存草稿", message: "可在系统邮件中继续编辑发送。")
        case .cancelled:
            break
        case .failed:
            notice = .init(title: "邮件发送未完成", message: "表单内容已保留，可重试或复制举报内容。")
        }
    }
}
