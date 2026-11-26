import Foundation

/// Product identity is stable across later marketing-name changes. Prices and
/// purchased state come exclusively from StoreKit, never from these labels.
enum OneTapePaymentPlan {
    static let productID = "OneVinyl_1"
    static let productName = "One Cassette Pro"
    static let billingLabel = "一次性买断"
    static let summary = "One Cassette Pro 为一次性买断商品，不自动续费。实际价格以 App Store 返回及系统购买确认页为准。当前版本接入购买和 Pro 状态，现有功能的使用方式保持不变；购买不承诺包含所有未来功能。"
}
