import SwiftUI

/// Concise brand & compliance "关于我们" screen matching HarmonyOS One Cassette's
/// capabilities (brand hero, version, privacy policy, user agreement, payment
/// terms, APP ICP filing link, privacy authorization reset, and contact email).
struct OneTapeAboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var supportDestination: OneTapeSupportDestination?
    @State private var showRevokeConfirm = false
    @State private var notice: OneTapeSupportNotice?

    private let actions: any OneTapeSupportActions = SystemOneTapeSupportActions()
    private let version = OneTapeMailURL.version()
    private let supportEmail = OneTapeSupportConfiguration.bundled().supportEmail ?? "hapy8bit@163.com"
    private let icpNumber = "京ICP备2026048583号-3A"
    private let icpURL = URL(string: "https://beian.miit.gov.cn/")
    private let accent = Color(red: 0.89, green: 0.57, blue: 0.35)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    brandHero
                    complianceCard
                    footerEmail
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .background(Color(white: 0.065).ignoresSafeArea())
            .navigationTitle("关于我们")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(.white.opacity(0.85))
                        .accessibilityIdentifier("about.close")
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(item: $supportDestination) { destination in
            OneTapeSupportScreen(destination: destination)
        }
        .confirmationDialog(
            "撤销隐私授权",
            isPresented: $showRevokeConfirm,
            titleVisibility: .visible
        ) {
            Button("清除本机隐私偏好标记", role: .destructive) {
                resetLocalPrivacyConsentFlags()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("One Cassette 不上传本地曲库也不设云端账号。本操作将重置本机启动提示与可选隐私偏好，不会删除你的本地音乐。")
        }
        .alert(item: $notice) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }

    // MARK: - Brand Hero

    private var brandHero: some View {
        VStack(spacing: 12) {
            // Minimalist dark-obsidian cassette deck emblem echoing the Braun splash.
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.14), Color(white: 0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 76, height: 76)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(.white.opacity(0.11), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 14, y: 8)

                AboutMiniDeckGlyph(accent: accent)
                    .frame(width: 44, height: 34)
            }

            Text("One Cassette")
                .font(.custom("InstrumentSerif-Italic", size: 32))
                .foregroundStyle(.white.opacity(0.94))

            Text(version)
                .font(.custom("GeistMono-Regular", fixedSize: 12))
                .foregroundStyle(.white.opacity(0.42))
                .accessibilityIdentifier("about.version")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Compliance & Info Card

    private var complianceCard: some View {
        VStack(spacing: 0) {
            // Version row
            HStack {
                Text("版本")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Text(version)
                    .font(.custom("GeistMono-Regular", fixedSize: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 54)

            hairline

            linkRow("隐私政策", identifier: "about.privacy") {
                supportDestination = .privacy
            }

            hairline

            linkRow("用户协议", identifier: "about.terms") {
                supportDestination = .terms
            }

            hairline

            linkRow("付费说明", identifier: "about.payment") {
                supportDestination = .payment
            }

            hairline

            // ICP Filing row with external arrow & long-press/copy support
            Button {
                if let icpURL { openURL(icpURL) }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("APP 备案号")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.88))
                        Text(icpNumber)
                            .font(.custom("GeistMono-Regular", fixedSize: 12))
                            .foregroundStyle(.white.opacity(0.44))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.40))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("复制备案号") {
                    actions.copy(icpNumber)
                    notice = .init(title: "已复制备案号", message: icpNumber)
                }
            }
            .accessibilityIdentifier("about.icp")

            hairline

            // Revoke local privacy authorization
            Button {
                showRevokeConfirm = true
            } label: {
                HStack {
                    Text("撤销隐私授权")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.36))
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("about.revokePrivacy")
        }
        .background(.white.opacity(0.038), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var footerEmail: some View {
        VStack(spacing: 8) {
            Button {
                actions.copy(supportEmail)
                notice = .init(title: "已复制联系邮箱", message: supportEmail)
            } label: {
                HStack(spacing: 6) {
                    Text(supportEmail)
                        .font(.custom("GeistMono-Regular", fixedSize: 13))
                        .foregroundStyle(.white.opacity(0.54))
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.32))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.04), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("about.email")

            Text("把自己的音乐装进一盘磁带")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.30))
        }
        .frame(maxWidth: .infinity)
    }

    private var hairline: some View {
        Rectangle()
            .fill(.white.opacity(0.07))
            .frame(height: 0.5)
            .padding(.horizontal, 18)
    }

    private func linkRow(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func resetLocalPrivacyConsentFlags() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: OneTapeOpeningPreferences.completionKey)
        defaults.set(true, forKey: OneTapeOpeningPreferences.splashEnabledKey)
        notice = .init(
            title: "已重置本机授权偏好",
            message: "已重置本机引导状态；如需管理相册或系统权限，可前往 iOS「设置 → One Cassette」。"
        )
    }
}

/// Crisp vector line-art cassette deck glyph used on the About hero badge.
private struct AboutMiniDeckGlyph: View {
    let accent: Color

    var body: some View {
        VStack(spacing: 2.5) {
            HStack(spacing: 4) {
                Spacer()
                Capsule().fill(.white.opacity(0.75)).frame(width: 6, height: 2.6)
                Capsule().fill(.white.opacity(0.75)).frame(width: 6, height: 2.6)
                Capsule().fill(accent).frame(width: 10, height: 3.2)
            }
            .padding(.trailing, 5)

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.white.opacity(0.90), lineWidth: 1.8)
                HStack(spacing: 9) {
                    Circle()
                        .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
                        .frame(width: 9, height: 9)
                    Rectangle()
                        .fill(.white.opacity(0.55))
                        .frame(width: 7, height: 1.5)
                    Circle()
                        .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
                        .frame(width: 9, height: 9)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .overlay {
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .strokeBorder(.white.opacity(0.45), lineWidth: 1.0)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
            .frame(height: 26)
        }
    }
}
