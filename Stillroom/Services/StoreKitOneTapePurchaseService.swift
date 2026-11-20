import Foundation
import StoreKit

@MainActor
protocol OneTapePurchasing: AnyObject {
    func loadProduct() async throws -> OneTapeStoreProduct
    func purchase() async throws -> OneTapePurchaseResult
    func currentEntitlement() async throws -> Bool
    func sync() async throws
    func finish(_ transactionID: UInt64) async
    func observeTransactions(_ receive: @escaping @MainActor (OneTapePurchaseUpdate) async -> Void) async
}

@MainActor
final class StoreKitOneTapePurchaseService: OneTapePurchasing {
    private var product: Product?
    private var deliveredTransactions: [UInt64: Transaction] = [:]

    func loadProduct() async throws -> OneTapeStoreProduct {
        let products = try await Product.products(for: [OneTapePaymentPlan.productID])
        guard let found = products.first(where: { $0.id == OneTapePaymentPlan.productID }) else {
            product = nil
            throw OneTapePurchaseError.productUnavailable
        }
        // This SKU is a lifetime purchase. A catalog mistake must never silently
        // sell a subscription or consumable under the one-time-buyout wording.
        guard found.type == .nonConsumable else {
            product = nil
            throw OneTapePurchaseError.invalidProductType
        }
        product = found
        return .init(id: found.id, displayName: found.displayName, displayPrice: found.displayPrice)
    }

    func purchase() async throws -> OneTapePurchaseResult {
        guard let product else { throw OneTapePurchaseError.productUnavailable }
        switch try await product.purchase() {
        case .success(let result):
            let transaction = try verified(result)
            deliveredTransactions[transaction.id] = transaction
            return .purchased(purchaseValue(transaction))
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw OneTapePurchaseError.unexpectedResult
        }
    }

    func currentEntitlement() async throws -> Bool {
        for await result in Transaction.currentEntitlements {
            // unsafePayloadValue is used only to ignore unrelated SKUs; it can
            // never grant an entitlement or cause an unverified order to finish.
            guard result.unsafePayloadValue.productID == OneTapePaymentPlan.productID else { continue }
            let transaction = try verified(result)
            if transaction.revocationDate == nil { return true }
        }
        return false
    }

    func sync() async throws {
        do { try await AppStore.sync() }
        catch StoreKitError.userCancelled { throw OneTapePurchaseError.cancelled }
    }

    func finish(_ transactionID: UInt64) async {
        guard let transaction = deliveredTransactions.removeValue(forKey: transactionID) else { return }
        await transaction.finish()
    }

    func observeTransactions(_ receive: @escaping @MainActor (OneTapePurchaseUpdate) async -> Void) async {
        // The store owns this loop's Task, starts it once at app startup, and
        // cancels it on release. It stays alive while the paywall is dismissed.
        for await result in Transaction.updates {
            guard !Task.isCancelled else { return }
            guard result.unsafePayloadValue.productID == OneTapePaymentPlan.productID else { continue }
            do {
                let transaction = try verified(result)
                deliveredTransactions[transaction.id] = transaction
                await receive(.verified(purchaseValue(transaction)))
            } catch {
                await receive(.verificationFailed)
            }
        }
    }

    private func verified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        guard case .verified(let transaction) = result,
              transaction.productID == OneTapePaymentPlan.productID,
              transaction.productType == .nonConsumable else {
            throw OneTapePurchaseError.failedVerification
        }
        return transaction
    }

    private func purchaseValue(_ transaction: Transaction) -> OneTapeVerifiedPurchase {
        .init(id: transaction.id, productID: transaction.productID, isRevoked: transaction.revocationDate != nil)
    }
}
