import SwiftUI

struct OneTapeStudioView: View {
    let product: OneTapeStoreProduct?
    let isPro: Bool
    let isPurchasing: Bool
    let isLoadingProduct: Bool
    let canPurchase: Bool
    let productIssue: String?
    let entitlementIssue: String?
    let onPurchase: () -> Void
    let onReload: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var supportDestination: OneTapeSupportDestination?
    private let orange = Color(red: 0.88, green: 0.34, blue: 0.015)

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color(white: 0.065).ignoresSafeArea()
                OneTapeStudioMontage()
                    .frame(height: min(geometry.size.height * 0.54, geometry.size.width * 1.12))

                ScrollView {
                    VStack(spacing: 18) {
                        Color.clear.frame(height: min(geometry.size.height * 0.39, geometry.size.width * 0.74))
                        Text("ONE CASSETTE STUDIO")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(3.4)
                            .foregroundStyle(orange)

                        Text("你的磁带，\n你的风格。")
                            .font(.system(size: 35, weight: .bold))
                            .multilineTextAlignment(.center)
                            .lineSpacing(1)
                            .foregroundStyle(.white.opacity(0.88))
                            .accessibilityAddTraits(.isHeader)

                        Text("为自己的音乐，选择喜欢的外观。")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)

                        Text(product?.displayName ?? OneTapePaymentPlan.productName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .accessibilityIdentifier("studio.productName")

                        Text(priceLabel + " · " + OneTapePaymentPlan.billingLabel)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .accessibilityIdentifier("studio.price")

                        VStack(alignment: .leading, spacing: 14) {
                            feature("磁带、机身与屏幕样式")
                            feature("印花与涂鸦外观")
                            feature("本地文件与 Navidrome 音乐库")
                        }
                        .padding(.vertical, 8)

                        Button(action: onPurchase) {
                            HStack(spacing: 10) {
                                if isPurchasing { ProgressView().tint(.black.opacity(0.88)) }
                                Text(isPro ? "已购买" : isPurchasing ? "正在购买…" : "购买")
                            }
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.black.opacity(0.88))
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(orange, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canPurchase)
                        .opacity(isPro || canPurchase || isPurchasing ? 1 : 0.5)
                        .padding(.horizontal, 38)
                        .accessibilityIdentifier("studio.purchase")

                        if let issue = productIssue ?? entitlementIssue {
                            Text(issue)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.62))
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("studio.purchaseIssue")
                            Button("重新加载", action: onReload)
                                .foregroundStyle(orange)
                                .frame(minHeight: 44)
                                .disabled(isLoadingProduct || isPurchasing)
                                .accessibilityIdentifier("studio.reloadProduct")
                        }

                        Text("一次性买断，不自动续费。\n现有功能继续开放使用，感谢你的支持。\n已购用户可在设置中恢复购买。")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 20) {
                            Button("付费说明") { supportDestination = .payment }
                                .accessibilityIdentifier("studio.preview")
                            Button("隐私政策") { supportDestination = .privacy }
                            Button("用户协议") { supportDestination = .terms }
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.58))
                        .buttonStyle(.plain)

                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 24))
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)

                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Text("稍后")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(minWidth: 54, minHeight: 36)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay { Capsule().stroke(.white.opacity(0.08), lineWidth: 0.7) }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭 Studio")
                    .accessibilityIdentifier("studio.close")
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $supportDestination) { destination in
            OneTapeSupportScreen(destination: destination)
        }
    }

    private var priceLabel: String {
        if isPro { return "已购买" }
        if let product { return product.displayPrice }
        return isLoadingProduct ? "正在获取价格…" : "价格暂不可用"
    }

    private func feature(_ title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 13) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(orange)
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

}
