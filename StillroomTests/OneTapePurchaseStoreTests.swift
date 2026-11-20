import XCTest
@testable import Stillroom

@MainActor
final class OneTapePurchaseStoreTests: XCTestCase {
    func testPriceComesFromStoreAndPurchaseWaitsForEntitlementCheck() async {
        let service = PurchaseServiceDouble()
        let store = OneTapePurchaseStore(service: service)
        await store.loadProduct()
        XCTAssertEqual(store.product?.displayPrice, "US$2.49")
        XCTAssertFalse(store.canPurchase)
        await store.refreshEntitlements()
        XCTAssertTrue(store.canPurchase)
        XCTAssertEqual(service.syncCount, 0, "Automatic checks must never request App Store authentication.")
    }

    func testCancelledAndPendingPaymentsNeverGrantPro() async {
        let service = PurchaseServiceDouble()
        let store = await readyStore(service)
        service.purchaseResult = .cancelled
        await store.purchase()
        XCTAssertFalse(store.isPro)
        XCTAssertEqual(store.notice?.title, "已取消购买")
        service.purchaseResult = .pending
        await store.purchase()
        XCTAssertFalse(store.isPro)
        XCTAssertEqual(store.notice?.title, "等待购买批准")
        XCTAssertTrue(service.finished.isEmpty)
        XCTAssertFalse(store.isBusy)
    }

    func testVerifiedPurchaseGrantsProBeforeFinishingAndPreventsRepurchase() async {
        let service = PurchaseServiceDouble()
        let store = await readyStore(service)
        service.onFinish = { _ in XCTAssertTrue(store.isPro, "Deliver before finishing the transaction.") }
        await store.purchase()
        XCTAssertTrue(store.isPro)
        XCTAssertFalse(store.canPurchase)
        XCTAssertEqual(service.finished, [42])
        await store.purchase()
        XCTAssertEqual(service.purchaseCount, 1)
    }

    func testUnverifiedOrWrongProductCannotGrantProOrFinish() async {
        let service = PurchaseServiceDouble()
        let store = await readyStore(service)
        service.purchaseError = OneTapePurchaseError.failedVerification
        await store.purchase()
        XCTAssertFalse(store.isPro)
        XCTAssertEqual(store.notice?.title, "购买未完成")
        service.purchaseError = nil
        service.purchaseResult = .purchased(.init(id: 99, productID: "another-product", isRevoked: false))
        await store.purchase()
        XCTAssertFalse(store.isPro)
        XCTAssertTrue(service.finished.isEmpty)
    }

    func testRestoreRequiresVerifiedEntitlementAndColdLaunchReadsItWithoutSync() async {
        let service = PurchaseServiceDouble()
        let store = OneTapePurchaseStore(service: service)
        service.entitled = true
        await store.restore()
        XCTAssertTrue(store.isPro)
        XCTAssertEqual(store.notice?.title, "已恢复购买")
        XCTAssertEqual(service.syncCount, 1)
        let reopened = OneTapePurchaseStore(service: service)
        await reopened.refreshEntitlements()
        XCTAssertTrue(reopened.isPro)
        XCTAssertEqual(service.syncCount, 1)
    }

    func testEmptyRestoreAndSyncFailureNeverReportSuccess() async {
        let service = PurchaseServiceDouble()
        let store = OneTapePurchaseStore(service: service)
        await store.restore()
        XCTAssertFalse(store.isPro)
        XCTAssertEqual(store.notice?.title, "未找到可恢复的购买")
        service.syncError = URLError(.notConnectedToInternet)
        await store.restore()
        XCTAssertFalse(store.isPro)
        XCTAssertEqual(store.notice?.title, "恢复购买失败")
        XCTAssertFalse(store.isBusy)
    }

    func testUnavailableProductDisablesPurchaseAndCanRetry() async {
        let service = PurchaseServiceDouble()
        let store = OneTapePurchaseStore(service: service)
        service.catalogError = OneTapePurchaseError.productUnavailable
        await store.loadProduct()
        await store.refreshEntitlements()
        XCTAssertNil(store.product)
        XCTAssertNotNil(store.productIssue)
        XCTAssertFalse(store.canPurchase)
        service.catalogError = nil
        await store.loadProduct()
        XCTAssertNil(store.productIssue)
        XCTAssertTrue(store.canPurchase)
    }

    func testRevocationUpdateRemovesPro() async {
        let service = PurchaseServiceDouble()
        let store = await readyStore(service)
        store.start()
        await store.purchase()
        service.updates.continuation.yield(.verified(.init(id: 42, productID: "OneVinyl_1", isRevoked: true)))
        await eventually { !store.isPro }
        XCTAssertFalse(store.isPro)
    }

    func testOlderEntitlementReadCannotOverwriteNewTransaction() async {
        let service = PurchaseServiceDouble()
        let store = await readyStore(service)
        store.start()
        var releaseRead: CheckedContinuation<Bool, Never>?
        service.readEntitlement = { await withCheckedContinuation { releaseRead = $0 } }
        let oldRead = Task { await store.refreshEntitlements() }
        await eventually { releaseRead != nil }
        service.updates.continuation.yield(.verified(.init(id: 43, productID: "OneVinyl_1", isRevoked: false)))
        await eventually { store.isPro }
        releaseRead?.resume(returning: false)
        await oldRead.value
        XCTAssertTrue(store.isPro, "A stale empty read must not erase a just-verified transaction.")
    }

    func testConcurrentPurchaseAndRestoreCannotStartTwoOperations() async {
        let service = PurchaseServiceDouble()
        let store = await readyStore(service)
        var release: CheckedContinuation<OneTapePurchaseResult, Never>?
        service.performPurchase = { await withCheckedContinuation { release = $0 } }
        let first = Task { await store.purchase() }
        await eventually { release != nil }
        await store.purchase()
        await store.restore()
        XCTAssertTrue(store.isBusy)
        XCTAssertEqual(service.purchaseCount, 1)
        XCTAssertEqual(service.syncCount, 0)
        release?.resume(returning: .cancelled)
        await first.value
        XCTAssertFalse(store.isBusy)
    }

    func testUnverifiedEntitlementBlocksCheckoutUntilSuccessfulRecheck() async {
        let service = PurchaseServiceDouble()
        let store = await readyStore(service)
        service.entitlementError = OneTapePurchaseError.failedVerification
        await store.refreshEntitlements()
        XCTAssertFalse(store.isPro)
        XCTAssertFalse(store.canPurchase, "An unverified existing order must not invite another payment.")
        service.entitlementError = nil
        await store.refreshEntitlements()
        XCTAssertTrue(store.canPurchase)
    }

    func testLatePurchaseResultCannotUndoAnObservedRefund() async {
        let service = PurchaseServiceDouble()
        let store = await readyStore(service)
        store.start()
        var release: CheckedContinuation<OneTapePurchaseResult, Never>?
        service.performPurchase = { await withCheckedContinuation { release = $0 } }
        let payment = Task { await store.purchase() }
        await eventually { release != nil }
        service.updates.continuation.yield(.verified(.init(id: 42, productID: "OneVinyl_1", isRevoked: true)))
        await eventually { service.finished.contains(42) }
        release?.resume(returning: .purchased(.init(id: 42, productID: "OneVinyl_1", isRevoked: false)))
        await payment.value
        XCTAssertFalse(store.isPro, "A late pre-refund result cannot make the revoked order active again.")
        XCTAssertNotEqual(store.notice?.title, "购买成功")
    }

    func testTransactionObserverDoesNotKeepReleasedStoreAlive() async {
        let service = PurchaseServiceDouble()
        var store: OneTapePurchaseStore? = OneTapePurchaseStore(service: service)
        weak var released = store
        store?.start()
        await Task.yield()
        store = nil
        await eventually { released == nil }
    }

    func testClosingAndReopeningStudioSharesOutstandingProductLoad() async {
        let service = PurchaseServiceDouble()
        let store = OneTapePurchaseStore(service: service)
        var release: CheckedContinuation<OneTapeStoreProduct, Never>?
        service.readProduct = { await withCheckedContinuation { release = $0 } }
        let closingSheet = Task { await store.loadProduct() }
        await eventually { release != nil }
        closingSheet.cancel()
        let reopenedSheet = Task { await store.loadProduct() }
        await Task.yield()
        release?.resume(returning: .init(id: "OneVinyl_1", displayName: "One Vinyl Pro", displayPrice: "¥9.90"))
        await closingSheet.value
        await reopenedSheet.value
        XCTAssertNotNil(store.product, "Closing Studio must not silently lose a shared catalog result.")
        XCTAssertFalse(store.isLoadingProduct)
        XCTAssertNil(store.productIssue)
    }

    func testForegroundCheckCannotMakeSuccessfulRestoreReportVerificationFailure() async {
        let service = PurchaseServiceDouble()
        let store = OneTapePurchaseStore(service: service)
        var reads: [CheckedContinuation<Bool, Never>] = []
        service.readEntitlement = { await withCheckedContinuation { reads.append($0) } }
        let restore = Task { await store.restore() }
        await eventually { !reads.isEmpty }
        var foregroundEntered = false
        let foreground = Task { foregroundEntered = true; await store.refreshEntitlements() }
        await eventually { foregroundEntered }
        reads.removeFirst().resume(returning: true)
        await eventually { store.notice != nil }
        for read in reads { read.resume(returning: true) }
        await foreground.value
        await restore.value
        XCTAssertTrue(store.isPro)
        XCTAssertEqual(store.notice?.title, "已恢复购买")
    }

    private func readyStore(_ service: PurchaseServiceDouble) async -> OneTapePurchaseStore {
        let store = OneTapePurchaseStore(service: service)
        await store.loadProduct()
        await store.refreshEntitlements()
        return store
    }

    private func eventually(_ predicate: () -> Bool) async {
        for _ in 0..<200 where !predicate() { try? await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(predicate())
    }
}

/// Only the external StoreKit boundary is replaced; the state and race handling are real.
@MainActor
private final class PurchaseServiceDouble: OneTapePurchasing {
    var entitled = false
    var purchaseResult: OneTapePurchaseResult = .purchased(.init(id: 42, productID: "OneVinyl_1", isRevoked: false))
    var catalogError: Error?
    var purchaseError: Error?
    var syncError: Error?
    var entitlementError: Error?
    var purchaseCount = 0
    var syncCount = 0
    var finished: [UInt64] = []
    var onFinish: ((UInt64) -> Void)?
    var readEntitlement: (() async -> Bool)?
    var performPurchase: (() async -> OneTapePurchaseResult)?
    var readProduct: (() async -> OneTapeStoreProduct)?
    let updates = AsyncStream<OneTapePurchaseUpdate>.makeStream()

    func loadProduct() async throws -> OneTapeStoreProduct {
        if let catalogError { throw catalogError }
        if let readProduct { return await readProduct() }
        return .init(id: "OneVinyl_1", displayName: "One Vinyl Pro", displayPrice: "US$2.49")
    }

    func purchase() async throws -> OneTapePurchaseResult {
        purchaseCount += 1
        if let purchaseError { throw purchaseError }
        if let performPurchase { return await performPurchase() }
        return purchaseResult
    }

    func currentEntitlement() async throws -> Bool {
        if let entitlementError { throw entitlementError }
        if let readEntitlement { return await readEntitlement() }
        return entitled
    }

    func sync() async throws {
        syncCount += 1
        if let syncError { throw syncError }
    }

    func finish(_ transactionID: UInt64) async {
        onFinish?(transactionID)
        finished.append(transactionID)
    }

    func observeTransactions(_ receive: @escaping @MainActor (OneTapePurchaseUpdate) async -> Void) async {
        for await update in updates.stream {
            guard !Task.isCancelled else { return }
            await receive(update)
        }
    }
}
