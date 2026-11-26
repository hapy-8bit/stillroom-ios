import SwiftUI
import UIKit

struct OneTapeSettingsView: View {
    let connectionName: String?
    let onStudio: () -> Void
    let onAddMusic: () -> Void
    let onReplayOpening: () -> Void
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("设置")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 27)
                .padding(.top, 26)
                .padding(.bottom, 26)
                .accessibilityAddTraits(.isHeader)

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    openingDemo
                    pro
                    widgets
                    remoteControl
                    screen
                    musicSource
                    roomListening
                    studio
                    about
                }
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color(white: 0.065).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(item: $supportDestination) { destination in
            OneTapeSupportScreen(destination: destination)
        }
        .alert(item: $notice) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("知道了")))
        }
    }

    private var pro: some View {
        settingsSection(OneTapePaymentPlan.productName) {
            HStack {
                Text("Pro 状态")
                Spacer()
                Text(proStatus).foregroundStyle(.white.opacity(0.55))
                    .accessibilityIdentifier("settings.proStatus")
            }
            .font(.system(size: 16))
            .foregroundStyle(.white.opacity(0.85))
            .frame(minHeight: 44)
            HStack(spacing: 10) {
                row(isRestoringPurchases ? "正在恢复购买…" : "恢复购买", identifier: "settings.restorePurchases",
                    action: onRestorePurchases)
                    .disabled(purchasesBusy)
                if isRestoringPurchases { ProgressView().tint(.white) }
            }
            if let purchaseIssue { footnote(purchaseIssue) }
            footnote("使用购买时的 App Store 账户恢复 One Cassette Pro。")
        }
    }

    private var openingDemo: some View {
        Button(action: onReplayOpening) {
            HStack(spacing: 15) {
                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.system(size: 23, weight: .light))
                    .foregroundStyle(Color(red: 0.89, green: 0.57, blue: 0.35))
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 6) {
                    Text("开屏动画").font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("上滑开盒，左滑入仓。")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.44))
                }
                Spacer(minLength: 6)
                Text("重新演示").font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.89, green: 0.57, blue: 0.35))
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.08), lineWidth: 0.5) }
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("重新演示开屏动画")
        .accessibilityIdentifier("settings.opening")
    }

    private var widgetMetrics: OneTapeWidgetMetrics {
        OneTapeWidgetMetrics.forScreen(width: screenSize.width, height: screenSize.height)
    }

    private var widgets: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("小组件")
                .padding(.leading, 7)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    widget(size: .small)
                    widget(size: .medium)
                    widget(size: .large)
                }
                .padding(.horizontal, 7)
            }
            .scrollIndicators(.hidden)
            footnote("在主屏幕上长按，然后轻点“编辑”>“添加小组件”。")
                .padding(.leading, 7)
        }
    }

    private func widget(size: OneTapeWidgetSize) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            OneTapeWidgetPreview(
                size: size,
                snapshot: widgetSnapshot,
                artwork: widgetArtwork,
                metrics: widgetMetrics,
                onTogglePlayback: onTogglePlayback,
                onNextTrack: onNextTrack
            )
            .accessibilityIdentifier("settings.widget.\(size.rawValue)")
            Text(size.title)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
        }
        .accessibilityElement(children: size == .small ? .combine : .contain)
        .accessibilityLabel(widgetSnapshot.previewAccessibilityLabel(size: size))
    }

    private var remoteControl: some View {
        settingsSection("遥控器") {
            row("iPad 遥控器", identifier: "settings.remote") {
                show("iPad 遥控器", "遥控器将在后续版本接入。当前不会发起配对或连接其他设备。")
            }
        }
    }

    private var screen: some View {
        settingsSection("屏幕") {
            Toggle("Keep the screen awake", isOn: $keepAwake)
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.85))
                .tint(Color(red: 0.78, green: 0.48, blue: 0.28))
                .frame(minHeight: 44)
                .accessibilityIdentifier("settings.keepAwake")
        }
    }

    private var musicSource: some View {
        settingsSection("音乐来源") {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("本地音乐与 Navidrome")
                    Text(connectionName.map { "已连接：\($0)" } ?? "本地文件导入 · 连接你的音乐服务器")
                        .font(.caption).foregroundStyle(.white.opacity(0.45))
                        .accessibilityIdentifier("settings.connection")
                }
                Spacer()
            }
            .font(.system(size: 17))
            .foregroundStyle(.white.opacity(0.85))
            .frame(minHeight: 44)
            Button(action: onAddMusic) {
                Label("添加音乐…", systemImage: "plus")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.addMusic")
        }
    }

    private var roomListening: some View {
        settingsSection("声音") {
            previewToggle("聆听环境", identifier: "settings.roomListening") {
                show("聆听环境", "环境感应将在后续版本接入，当前不会访问麦克风或录音。")
            }
            footnote("播放中的本地音乐与 Navidrome 音乐可直接驱动屏幕。聆听环境尚未接入，当前不会访问麦克风。")
        }
    }

    private var studio: some View {
        settingsSection("ONE CASSETTE STUDIO") {
            HStack {
                Text("所有外观")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                smallButton("预览", identifier: "settings.studio", action: onStudio)
            }
            .frame(minHeight: 44)
        }
    }

    private var about: some View {
        settingsSection("关于") {
            row("One Cassette", identifier: "settings.about") {
                show("One Cassette", "把自己的音乐装进一盘磁带。支持本地文件导入与 Navidrome 音乐库，音乐由同一个播放器播放。")
            }
            row("隐私政策", identifier: "settings.privacy") { supportDestination = .privacy }
            row("用户服务协议", identifier: "settings.terms") { supportDestination = .terms }
            row("付费说明", identifier: "settings.payment") { supportDestination = .payment }
            row("联系我们", identifier: "settings.contact") { supportDestination = .contact }
            row("问题反馈", identifier: "settings.feedback") { supportDestination = .feedback }
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(title)
            content()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.42))
            .accessibilityAddTraits(.isHeader)
    }

    private func footnote(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.34))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .font(.system(size: 17))
            .foregroundStyle(.white.opacity(0.85))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func previewToggle(
        _ title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        // This binding deliberately never enables a system feature. A tap
        // explains the pending integration instead of faking permissions/state.
        Toggle(title, isOn: Binding(get: { false }, set: { _ in action() }))
            .font(.system(size: 17))
            .foregroundStyle(.white.opacity(0.85))
            .tint(Color(red: 0.78, green: 0.48, blue: 0.28))
            .frame(minHeight: 44)
            .accessibilityValue("尚未接入")
            .accessibilityIdentifier(identifier)
    }

    private func smallButton(
        _ title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 16)
                .frame(minHeight: 36)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 12))
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
