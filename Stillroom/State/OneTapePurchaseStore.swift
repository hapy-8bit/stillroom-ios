import Foundation
import Combine

@MainActor
final class OneTapePurchaseStore: ObservableObject {
    enum Operation { case purchase, restore }

    @Published private(set) var product: OneTapeStoreProduct?
    @Published private(set) var isPro = false
    @Published private(set) var hasCheckedEntitlements = false
    @Published private(set) var isCheckingEntitlements = false
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var operation: Operation?
    @Published private(set) var productIssue: String?
    @Published private(set) var entitlementIssue: String?
    @Published var notice: OneTapePurchaseNotice?

    private let service: any OneTapePurchasing
    private var observer: Task<Void, Never>?
    private var userOperation: Task<Void, Never>?
    private var productLoad: Task<Void, Never>?
    private var entitlementRead: Task<Bool?, Never>?
    private var entitlementRevision = 0

    var isBusy: Bool { operation != nil }
    var canPurchase: Bool {
        product != nil && hasCheckedEntitlements && entitlementIssue == nil && !isCheckingEntitlements && !isLoadingProduct && !isPro && !isBusy
    }
    var statusLabel: String {
        if isPro { return "已购买" }
        if entitlementIssue != nil { return "购买状态待确认" }
        if isCheckingEntitlements || !hasCheckedEntitlements { return "正在检查购买状态" }
        return "未购买"
    }

    init(service: (any OneTapePurchasing)? = nil) {
        self.service = service ?? StoreKitOneTapePurchaseService()
    }

    deinit {
        observer?.cancel()
        userOperation?.cancel()
        productLoad?.cancel()
        entitlementRead?.cancel()
    }

    func start() {
        guard observer == nil else { return }
        observer = Task { [weak self, service] in
            await service.observeTransactions { [weak self] update in await self?.receive(update) }
        }
    }

    func loadProduct() async {
        if let productLoad { await productLoad.value; return }
        isLoadingProduct = true
        productIssue = nil
        // The app owns the shared request. Cancelling a sheet's waiter must not
        // discard the result needed by a newly opened Studio sheet.
        let task = Task { [weak self, service] in
            defer { self?.isLoadingProduct = false; self?.productLoad = nil }
            do {
                let loaded = try await service.loadProduct()
                try Task.checkCancellation()
                guard loaded.id == OneTapePaymentPlan.productID else { throw OneTapePurchaseError.productUnavailable }
                self?.product = loaded
            } catch is CancellationError {
            } catch {
                self?.product = nil
                self?.productIssue = error.localizedDescription
            }
        }
        productLoad = task
        await task.value
    }

    @discardableResult
    func refreshEntitlements(force: Bool = false) async -> Bool? {
        if let entitlementRead {
            let result = await entitlementRead.value
            if !force { return result }
        }
        // A forced check after AppStore.sync must start after any pre-sync read;
        // foreground callers share it instead of invalidating one another.
        if let entitlementRead { return await entitlementRead.value }
        let revision = entitlementRevision
        isCheckingEntitlements = true
        let task = Task { [weak self, service] () -> Bool? in
            defer { self?.isCheckingEntitlements = false; self?.entitlementRead = nil }
            do {
                let purchased = try await service.currentEntitlement()
                try Task.checkCancellation()
                guard let self else { return nil }
                // A verified update may overtake this snapshot. Its newer state
                // wins even when the old read is empty or fails verification.
                guard revision == self.entitlementRevision else { return self.settledEntitlement }
                self.entitlementRevision += 1
                self.isPro = purchased
                self.hasCheckedEntitlements = true
                self.entitlementIssue = nil
                return purchased
            } catch is CancellationError {
                return nil
            } catch {
                guard let self else { return nil }
                guard revision == self.entitlementRevision else { return self.settledEntitlement }
                self.isPro = false
                self.hasCheckedEntitlements = true
                self.entitlementIssue = error.localizedDescription
                return nil
            }
        }
        entitlementRead = task
        return await task.value
    }

    private var settledEntitlement: Bool? {
        hasCheckedEntitlements && entitlementIssue == nil ? isPro : nil
    }

    func buy() { begin(.purchase) }
    func restorePurchases() { begin(.restore) }

    private func begin(_ action: Operation) {
        guard userOperation == nil, !isBusy else { return }
        // A payment belongs to the app, not the sheet's lifetime: dismissing
        // Studio must not abandon delivery while Apple's checkout is on screen.
        userOperation = Task { [weak self] in
            if action == .purchase { await self?.purchase() } else { await self?.restore() }
            self?.userOperation = nil
        }
    }

    func purchase() async {
        guard canPurchase else { return }
        operation = .purchase
        notice = nil
        let revisionAtStart = entitlementRevision
        defer { operation = nil }
        do {
            switch try await service.purchase() {
            case .purchased(let transaction):
                guard transaction.productID == OneTapePaymentPlan.productID else {
                    throw OneTapePurchaseError.failedVerification
                }
                if revisionAtStart == entitlementRevision {
                    apply(transaction)
                } else {
                    // A refund or foreground refresh can overtake checkout.
                    // Recount current orders before using its older result.
                    guard await refreshEntitlements(force: true) != nil else {
                        throw OneTapePurchaseError.failedVerification
                    }
                }
                await service.finish(transaction.id)
                notice = .init(title: isPro ? "购买成功" : "购买权益不可用",
                    message: isPro ? "已购买 One Vinyl Pro，感谢支持。" : "此订单已退款或撤销，请在设置中恢复购买或联系开发者。")
            case .pending:
                notice = .init(title: "等待购买批准", message: "此购买正在等待 App Store 批准。批准后会自动更新 Pro 状态，也可在设置中恢复购买。")
            case .cancelled:
                notice = .init(title: "已取消购买", message: "没有新增购买，可随时返回。")
            }
        } catch is CancellationError {
        } catch {
            notice = .init(title: "购买未完成", message: error.localizedDescription)
        }
    }

    func restore() async {
        guard !isBusy else { return }
        operation = .restore
        notice = nil
        defer { operation = nil }
        do {
            // Authentication is requested only from the explicit settings action.
            try await service.sync()
            guard let restored = await refreshEntitlements(force: true) else {
                throw OneTapePurchaseError.failedVerification
            }
            notice = .init(title: restored ? "已恢复购买" : "未找到可恢复的购买",
                message: restored ? "已恢复 One Vinyl Pro。" : "当前 App Store 账户没有有效的 One Vinyl Pro 购买。请确认使用购买时的账户。")
        } catch OneTapePurchaseError.cancelled {
            notice = .init(title: "已取消恢复购买", message: "可在设置中再次恢复购买。")
        } catch is CancellationError {
        } catch {
            notice = .init(title: "恢复购买失败", message: error.localizedDescription)
        }
    }

    private func receive(_ update: OneTapePurchaseUpdate) async {
        switch update {
        case .verified(let transaction):
            guard transaction.productID == OneTapePaymentPlan.productID else { return }
            apply(transaction)
            await service.finish(transaction.id)
        case .verificationFailed:
            entitlementRevision += 1
            isPro = false
            isCheckingEntitlements = false
            hasCheckedEntitlements = true
            entitlementIssue = OneTapePurchaseError.failedVerification.localizedDescription
            notice = .init(title: "购买状态未能验证", message: entitlementIssue ?? "请在设置中恢复购买。")
        }
    }

    private func apply(_ transaction: OneTapeVerifiedPurchase) {
        entitlementRevision += 1
        isPro = transaction.grantsPro
        hasCheckedEntitlements = true
        isCheckingEntitlements = false
        entitlementIssue = nil
    }
}
