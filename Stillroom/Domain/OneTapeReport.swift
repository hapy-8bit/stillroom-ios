import Foundation

/// Pure domain rules for the Settings "投诉举报" (Report & Complaint) workflow.
enum OneTapeReportCategory: String, CaseIterable, Identifiable, Sendable {
    case illegal = "违法违规内容"
    case copyright = "版权或其他侵权"
    case harmful = "色情、暴力或危害未成年人的内容"
    case spam = "诈骗或其他不良信息"
    case service = "应用或服务投诉"
    case other = "其他问题"

    var id: String { rawValue }

    /// Concise display chip title to keep the iOS form scannable.
    var chipTitle: String {
        switch self {
        case .illegal: return "违法违规"
        case .copyright: return "版权侵权"
        case .harmful: return "色情暴力 / 涉未成年人"
        case .spam: return "诈骗 / 不良信息"
        case .service: return "应用或服务投诉"
        case .other: return "其他问题"
        }
    }
}

struct OneTapeReportDraft: Equatable, Sendable {
    static let maxDetailsLength = 1000

    var category: OneTapeReportCategory?
    var target: String = ""
    var details: String = ""
    var evidence: String = ""
    var replyEmail: String = ""

    var trimmedTarget: String { target.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedDetails: String { details.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedEvidence: String { evidence.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedReplyEmail: String { replyEmail.trimmingCharacters(in: .whitespacesAndNewlines) }

    var validationError: String? {
        guard category != nil else { return "请先选择举报类型。" }
        guard !trimmedTarget.isEmpty else { return "请填写投诉或举报对象。" }
        guard !trimmedDetails.isEmpty else { return "请填写详细说明。" }
        if !trimmedReplyEmail.isEmpty,
           OneTapeSupportConfiguration(supportEmail: trimmedReplyEmail).supportEmail == nil {
            return "回复邮箱格式不正确，请核对或留空。"
        }
        return nil
    }

    var isReady: Bool { validationError == nil }

    func mailDraft(recipient: String, version: String) -> OneTapeMailDraft {
        let categoryTitle = category?.rawValue ?? "未分类"
        let subject = "[One Cassette 投诉举报] \(categoryTitle) - \(trimmedTarget)"
        var lines: [String] = [
            "举报类型：\(categoryTitle)",
            "投诉或举报对象：\(trimmedTarget)",
            "",
            "详细说明：",
            trimmedDetails
        ]
        if !trimmedEvidence.isEmpty {
            lines.append("")
            lines.append("证据或线索：")
            lines.append(trimmedEvidence)
        }
        if !trimmedReplyEmail.isEmpty {
            lines.append("")
            lines.append("回复邮箱：\(trimmedReplyEmail)")
        }
        lines.append("")
        lines.append("应用版本：One Cassette \(version)")
        return OneTapeMailDraft(
            recipient: recipient,
            subject: subject,
            body: lines.joined(separator: "\n")
        )
    }

    func clipboardText(recipient: String, version: String) -> String {
        let mail = mailDraft(recipient: recipient, version: version)
        return "收件人：\(mail.recipient)\n主题：\(mail.subject)\n\n\(mail.body)"
    }
}
