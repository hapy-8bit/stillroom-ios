import Foundation

struct OneTapeStoreProduct: Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
}

/// Only the StoreKit service can turn a verified native transaction into this
/// value. A preview preference or a cached Boolean is never purchase evidence.
struct OneTapeVerifiedPurchase: Equatable, Sendable {
    let id: UInt64
    let productID: String
    let isRevoked: Bool

    var grantsPro: Bool { productID == OneTapePaymentPlan.productID && !isRevoked }
}

enum OneTapePurchaseResult: Sendable {
    case purchased(OneTapeVerifiedPurchase)
    case pending
    case cancelled
}

enum OneTapePurchaseUpdate: Sendable {
    case verified(OneTapeVerifiedPurchase)
    case verificationFailed
}

struct OneTapePurchaseNotice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

enum OneTapePurchaseError: LocalizedError {
    case productUnavailable, invalidProductType, failedVerification, cancelled, unexpectedResult

    var errorDescription: String? {
        switch self {
        case .productUnavailable: "暂时无法从 App Store 获取此商品，请稍后重试。"
        case .invalidProductType: "商品信息暂不可用，请稍后重试或联系开发者。"
        case .failedVerification: "App Store 订单未通过验证，尚未确认 Pro 权益。请在设置中恢复购买或联系开发者。"
        case .cancelled: "操作已取消，没有新增购买。"
        case .unexpectedResult: "App Store 暂未返回可确认的购买结果，请稍后在设置中恢复购买。"
        }
    }
}
