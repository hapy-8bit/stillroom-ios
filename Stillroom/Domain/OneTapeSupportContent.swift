import Foundation

struct OneTapeSupportSection: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let body: String
}

struct OneTapeSupportContent: Equatable, Sendable {
    let title: String
    let updatedOn: String
    let sections: [OneTapeSupportSection]

    var plainText: String {
        ([title, "更新日期：" + updatedOn] + sections.map { $0.title + "\n" + $0.body })
            .joined(separator: "\n\n")
    }
}

/// Product descriptions follow the implemented local/remote data flows. They
/// do not depend on a live website, an account, or a payment/analytics SDK.
enum OneTapeSupportDocument: String, CaseIterable, Identifiable, Sendable {
    case privacy, terms, payment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: "隐私政策"
        case .terms: "用户服务协议"
        case .payment: "付费说明"
        }
    }

    func content(contactEmail: String?) -> OneTapeSupportContent {
        let sections: [OneTapeSupportSection]
        switch self {
        case .privacy: sections = privacySections(contactEmail: contactEmail)
        case .terms: sections = termsSections(contactEmail: contactEmail)
        case .payment: sections = paymentSections(contactEmail: contactEmail)
        }
        return OneTapeSupportContent(title: title, updatedOn: "2026年11月8日", sections: sections)
    }

    private func privacySections(contactEmail: String?) -> [OneTapeSupportSection] {
        [
            .init(id: "scope", title: "适用范围", body:
                "本政策说明 One Cassette 当前版本在本地音乐、Navidrome 播放及反馈联系中的信息处理方式。开发者通过设置中的“联系我们”提供支持。"),
            .init(id: "local-library", title: "本地音乐与资料", body:
                "您主动通过系统“文件”选择音频、目录、封面或歌词后，应用读取已授权的项目，用于预览、导入、播放和展示专辑。确认导入的音频与配套资料复制到应用存储，原文件保留；应用读取曲名、艺人、专辑、时长和内嵌封面等可用信息，不会将本地曲库自动上传给开发者。"),
            .init(id: "preferences", title: "收藏、历史与设置", body:
                "收藏、实际开始播放的歌曲顺序、续听队列和位置、外观及屏幕常亮偏好保存在本机，用于下次打开时恢复体验。当前没有独立的 One Cassette 开发者云同步服务；iOS 系统备份和文件提供商的同步由您及相应服务的设置管理。"),
            .init(id: "navidrome", title: "您连接的音乐服务器", body:
                "连接 Navidrome 后，应用向您填写的服务器发送登录验证、目录、专辑、歌单、封面及音乐流请求。服务器会收到用户名、所请求的资源、请求时间及网络连接信息，并可能按其规则记录日志。应用使用请求令牌验证，建议连接 HTTPS 服务。服务器的运营者、可用性和数据规则由您选择的服务决定。"),
            .init(id: "credentials", title: "凭据与缓存", body:
                "服务器密码保存在此设备的系统钥匙串中，不会随曲库目录一起保存，也不由应用同步到 iCloud 钥匙串。已读取的服务器地址、用户名和曲库目录保存在应用存储；远端封面可缓存在本机。钥匙串与应用存储按 iOS 的保护机制管理。"),
            .init(id: "device", title: "音频、方向与系统功能", body:
                "动态屏幕在设备上分析当前播放引擎的音频信号，不请求麦克风或录制环境声音。方向感知用于调整播放器内部显示。播放标题、艺人、封面、时长及进度可交给 iOS 系统媒体控制，用于锁屏和控制中心显示。当前版本没有接入广告、跨应用跟踪或第三方行为分析服务。"),
            .init(id: "purchases", title: "App Store 购买与恢复", body:
                "One Cassette Pro 的商品、价格、付款及恢复购买由 Apple App Store 和 StoreKit 处理。应用读取并验证 Apple 返回的交易和有效购买状态，用于显示 Pro 状态并响应退款或撤销；不会把本地预览设置当作订单。应用不向开发者服务器上传交易信息，也不读取您的支付密码、银行卡或完整付款资料。付款账户与账单由 Apple 按其规则处理。"),
            .init(id: "retention", title: "保留、断开与本机管理", body:
                "本地曲库、封面、歌词及偏好会留在应用存储供以后使用；导入临时文件按事务清理，缓存可能由系统回收。您可在音乐来源中断开 Navidrome，移除此设备上的连接和远端目录并尝试清理凭据，服务器音乐与本地音乐保留；凭据删除暂时失败时会在后续启动重试。断开不表示所有封面缓存已立即清空。如需管理或移除本机应用数据，请通过 iOS 系统设置操作并先保留所需原件；系统备份和钥匙串有各自的保留机制。"),
            .init(id: "feedback", title: "您主动发出的反馈", body:
                "您选择通过邮箱反馈时，邮件地址、您编辑的文字和自选附件将由所用邮件服务发送给开发者。反馈草稿包含应用版本，您可自行补充系统版本和问题详情，发送前可编辑或取消；应用不会自动发送邮件、音乐文件、服务器密码或带认证的播放链接。浏览外部协议网页时，相应网站也会按其规则处理网络请求。"),
            .init(id: "contact", title: "联系与更新", body:
                contactText(contactEmail) + "如信息处理方式随功能变化，开发者会更新本说明并标明更新日期。")
        ]
    }

    private func termsSections(contactEmail: String?) -> [OneTapeSupportSection] {
        [
            .init(id: "service", title: "服务内容", body:
                "One Cassette 提供本地音频导入、资料库浏览、Navidrome 连接、音乐播放与播放器外观设置。无需创建 One Cassette 开发者账户即可使用本地音乐；远端内容需要您有权使用的音乐服务器账户。本协议按当前实际可用功能说明服务。"),
            .init(id: "rights", title: "音乐与资料的使用权", body:
                "请只导入、连接和使用您拥有或已获许可使用的音乐、封面及歌词，并遵守相关内容许可和服务器规则。您保有自有内容的权利；导入与播放不会向您转让第三方音乐或美术的版权。应用不提供绕过数字版权保护或订阅曲库保护的服务。"),
            .init(id: "import", title: "导入与数据保存", body:
                "导入先预览再确认，保存到应用中的副本与原文件分开。相同音频可复用已有歌曲身份，封面或歌词按您确认的目标关联。请在应用外保留重要音乐原件与资料；本版本不是独立备份服务。文件损坏、授权失效、设备空间及系统可解码格式会影响可用性。"),
            .init(id: "server", title: "第三方来源与网络", body:
                "您负责选择可访问且有权使用的服务器、保管账号及核对连接地址。服务器、文件提供商、网络与移动数据的费用、权限和可用性由相应服务决定。当前应用读取目录并播放音乐，不发起服务器收藏、歌单编辑或删除音乐等操作；服务器自身仍可能记录访问和播放请求。"),
            .init(id: "previews", title: "预览与后续功能", body:
                "标明为预览或尚未接入的入口只代表页面所说明的当前能力，不代表已获得系统组件、遥控、环境录音或购买权益。后续功能、兼容范围与商业化安排以实际发布版本及明确说明为准。请同时查看“付费说明”和“隐私政策”。"),
            .init(id: "support", title: "问题反馈与版本更新", body:
                "发生导入、播放或连接问题时，请保留原文件，并记录复现步骤、应用版本及系统版本后联系开发者。避免在反馈中发送密码、私人音乐或带认证的链接。开发者会根据实际复现情况处理反馈；文件兼容性以 iOS 实际解码结果为准，第三方来源的可用性由相应服务决定。"),
            .init(id: "contact", title: "联系我们", body: contactText(contactEmail))
        ]
    }

    private func paymentSections(contactEmail: String?) -> [OneTapeSupportSection] {
        [
            .init(id: "current", title: "当前版本", body:
                "本地音乐、Navidrome 播放及浏览外观不会自动发起付款。Studio 付费弹窗提供 One Cassette Pro 购买，只有主动点击购买并在 App Store 系统页面确认后才会完成交易。本轮现有功能的使用方式保持不变；Pro 状态不代表承诺所有未来功能。"),
            .init(id: "pricing", title: "价格与权益", body:
                OneTapePaymentPlan.summary + "请在确认付款前核对系统页面显示的商品名称、价格和账户。商品暂不可用或订单未验证时，应用不会显示为购买成功。"),
            .init(id: "restore", title: "恢复与订单", body:
                "已购买用户可在设置中点击“恢复购买”，使用购买时的 App Store 账户同步并验证有效订单。没有找到有效订单会明确提示；取消、待批准或验证失败不会当作恢复成功。启动和返回应用时会检查当前有效购买，退款或撤销后会相应更新 Pro 状态。应用不请求支付密码或银行卡信息，系统认证由 Apple 处理。"),
            .init(id: "third-party", title: "第三方费用", body:
                "Navidrome 服务器、文件提供商、网络接入及移动数据可能有独立费用。这些费用不由 One Cassette 的外观预览收取，适用范围与价格请向相应服务提供方核对。"),
            .init(id: "contact", title: "付费问题联系", body:
                contactText(contactEmail) + "请说明遇到的页面与问题；不要发送支付密码、服务器密码或完整敏感支付资料。")
        ]
    }

    private func contactText(_ email: String?) -> String {
        if let email, !email.isEmpty { return "如需咨询或提出数据处理请求，可联系开发者：\(email)。" }
        return "如需咨询或提出数据处理请求，请查看设置中的“联系我们”。"
    }
}
