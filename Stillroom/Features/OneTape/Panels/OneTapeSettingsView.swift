import SwiftUI
import UIKit

struct OneTapeSettingsView: View {
    let connectionName: String?
    let onStudio: () -> Void
    let onAddMusic: () -> Void
    let onReplayOpening: () -> Void
    var onReplaySplash: () -> Void = {}
    var splashEnabled: Binding<Bool> = .constant(true)
    var isPro: Bool = false
    var proPrice: String? = nil
    let proStatus: String
    let purchaseIssue: String?
    let purchasesBusy: Bool
    let isRestoringPurchases: Bool
    let onRestorePurchases: () -> Void
    @Binding var keepAwake: Bool
    var widgetSnapshot: OneTapeWidgetSnapshot = .empty
    var widgetArtwork: UIImage? = nil
    var screenSize: CGSize = CGSize(width: 393, height: 852)
    var onTogglePlayback: () -> Void = {}
    var onNextTrack: () -> Void = {}

    @State private var notice: SettingsNotice?
    @State private var supportDestination: OneTapeSupportDestination?
    @State private var reportVisible = false
    @State private var aboutVisible = false

    private let accent = Color(red: 0.89, green: 0.57, blue: 0.35)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("设置")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 18)
                .accessibilityAddTraits(.isHeader)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    proCard
                    openingDemo
                    widgets
                    musicAndPlayback
                    supportSection
                    versionFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 42)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color(white: 0.065).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(item: $supportDestination) { destination in
            OneTapeSupportScreen(destination: destination)
        }
        .sheet(isPresented: $reportVisible) {
            OneTapeReportView()
        }
        .sheet(isPresented: $aboutVisible) {
            OneTapeAboutView()
        }
        .alert(item: $notice) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }

    // MARK: - One Cassette Pro Editorial Studio Pass Card

    private var proCard: some View {
        OneTapeProCard(
            isPro: isPro,
            proPrice: proPrice,
            proStatus: proStatus,
            purchaseIssue: purchaseIssue,
            purchasesBusy: purchasesBusy,
            isRestoringPurchases: isRestoringPurchases,
            onStudio: onStudio,
            onRestorePurchases: onRestorePurchases
        )
    }

    // MARK: - Launch Splash & Packaging Unwrap Card

    private var openingDemo: some View {
        VStack(spacing: 0) {
            Button(action: onReplaySplash) {
                HStack(spacing: 14) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 19, weight: .light))
                        .foregroundStyle(accent)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("开屏动画").font(.system(size: 15.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("暖白迷你卡座按键起转，自动进入主页。")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.44))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    Text("演示").font(.system(size: 13, weight: .medium))
                        .foregroundStyle(accent)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("演示开屏小动画")
            .accessibilityIdentifier("settings.splash")

            cardDivider

            Toggle("启动时播放开屏动画", isOn: splashEnabled)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.76))
                .tint(accent)
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .accessibilityIdentifier("settings.splash.enabled")

            cardDivider

            Button(action: onReplayOpening) {
                HStack(spacing: 10) {
                    Text("首次拆包装引导")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.76))
                    Spacer()
                    Text("重新拆封")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(accent)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重新演示首次拆包装引导")
            .accessibilityIdentifier("settings.opening")
        }
        .background(.white.opacity(0.038), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 0.5) }
    }

    // MARK: - Live Home Screen Widgets Showcase

    private var widgets: some View {
        OneTapeWidgetSettingsShowcase(
            snapshot: widgetSnapshot,
            artwork: widgetArtwork,
            screenSize: screenSize,
            onTogglePlayback: onTogglePlayback,
            onNextTrack: onNextTrack
        )
    }

    // MARK: - Music & Playback Grouped Card

    private var musicAndPlayback: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("音乐与播放")

            VStack(spacing: 0) {
                Button(action: onAddMusic) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("本地音乐与 Navidrome")
                                .font(.system(size: 15.5))
                                .foregroundStyle(.white.opacity(0.88))
                            Text(connectionName.map { "已连接：\($0)" } ?? "导入本地音频或连接服务器")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.42))
                                .accessibilityIdentifier("settings.connection")
                        }
                        Spacer()
                        Text("添加")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(accent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.36))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.addMusic")

                cardDivider

                Toggle("保持屏幕常亮", isOn: $keepAwake)
                    .font(.system(size: 15.5))
                    .foregroundStyle(.white.opacity(0.88))
                    .tint(accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier("settings.keepAwake")

                cardDivider

                // Preview toggles with honest explanations
                Toggle("聆听环境", isOn: Binding(get: { false }, set: { _ in
                    show("聆听环境", "环境感应将在后续版本接入，当前不会访问麦克风或录音。")
                }))
                .font(.system(size: 15.5))
                .foregroundStyle(.white.opacity(0.88))
                .tint(accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .accessibilityValue("尚未接入")
                .accessibilityIdentifier("settings.roomListening")

                cardDivider

                cardRow("iPad 遥控器", identifier: "settings.remote") {
                    show("iPad 遥控器", "遥控器将在后续版本接入，当前不会发起配对或连接其他设备。")
                }
            }
            .background(.white.opacity(0.038), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Support & About Grouped Card (HarmonyOS Parity, Concise iOS Style)

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("支持")

            VStack(spacing: 0) {
                cardRow("帮助与反馈", identifier: "settings.feedback") {
                    supportDestination = .feedback
                }
                cardDivider
                cardRow("投诉举报", identifier: "settings.report") {
                    reportVisible = true
                }
                cardDivider
                cardRow("联系我们", identifier: "settings.contact") {
                    supportDestination = .contact
                }
                cardDivider
                cardRow("关于我们", identifier: "settings.about") {
                    aboutVisible = true
                }
            }
            .background(.white.opacity(0.038), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }
        }
    }

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("One Cassette")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.36))
            Text(OneTapeMailURL.version())
                .font(.custom("GeistMono-Regular", fixedSize: 11))
                .foregroundStyle(.white.opacity(0.26))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private var cardDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.07))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(.white.opacity(0.42))
            .padding(.leading, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func cardRow(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15.5))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.36))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func show(_ title: String, _ message: String) {
        notice = SettingsNotice(title: title, message: message)
    }
}

private struct SettingsNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
