import XCTest
import StoreKit
import StoreKitTest
@testable import Stillroom

#if targetEnvironment(simulator)
/// Local Apple StoreKit transactions only, on this task's isolated simulator.
/// The configuration is a test-bundle resource, never a production checkout source.
@MainActor
final class OneTapeStoreKitTests: XCTestCase {
    func testNativePurchaseRestoresAfterRecreatingStore() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let store = OneTapePurchaseStore(service: StoreKitOneTapePurchaseService())
        store.start()
        await store.refreshEntitlements()
        await store.loadProduct()
        XCTAssertEqual(store.product?.id, "OneVinyl_1")
        XCTAssertFalse(try XCTUnwrap(store.product?.displayPrice).isEmpty)
        XCTAssertFalse(store.isPro)
        XCTAssertTrue(store.canPurchase)
        await store.purchase()
        XCTAssertTrue(store.isPro, store.notice?.message ?? "No purchase result")
        let reopened = OneTapePurchaseStore(service: StoreKitOneTapePurchaseService())
        await reopened.refreshEntitlements()
        XCTAssertTrue(reopened.isPro)
        await reopened.restore()
        XCTAssertTrue(reopened.isPro)
        XCTAssertEqual(reopened.notice?.title, "已恢复购买")
    }

    func testExternalPurchaseAndRefundUpdateSharedProState() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let store = OneTapePurchaseStore(service: StoreKitOneTapePurchaseService())
        store.start()
        await store.refreshEntitlements()
        _ = try await session.buyProduct(identifier: "OneVinyl_1", options: [])
        await eventually { store.isPro }
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == "OneVinyl_1" })
        try session.refundTransaction(identifier: transaction.identifier)
        await eventually { !store.isPro }
        await store.refreshEntitlements()
        XCTAssertFalse(store.isPro, "Refunded products must disappear from active entitlements.")
    }

    func testPendingAskToBuyGrantsProOnlyAfterApproval() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        session.askToBuyEnabled = true
        let store = OneTapePurchaseStore(service: StoreKitOneTapePurchaseService())
        store.start()
        await store.refreshEntitlements()
        await store.loadProduct()
        await store.purchase()
        XCTAssertFalse(store.isPro)
        XCTAssertEqual(store.notice?.title, "等待购买批准")
        let pending = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == "OneVinyl_1" })
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        await eventually { store.isPro }
    }

    func testAnotherProductCannotRestorePro() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        _ = try await session.buyProduct(identifier: "test.unrelated", options: [])
        let store = OneTapePurchaseStore(service: StoreKitOneTapePurchaseService())
        await store.restore()
        XCTAssertFalse(store.isPro)
        XCTAssertEqual(store.notice?.title, "未找到可恢复的购买")
    }

    private func makeSession() throws -> SKTestSession {
        guard ProcessInfo.processInfo.environment["STILLROOM_LOCAL_STOREKIT_TESTS"] == "1" else {
            throw XCTSkip("Use the StillroomStoreKitTests scheme for local StoreKit transactions.")
        }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "OneVinyl", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.storefront = "CHN"
        session.locale = Locale(identifier: "zh_CN")
        session.clearTransactions()
        return session
    }

    private func eventually(_ predicate: () -> Bool) async {
        for _ in 0..<500 where !predicate() { try? await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(predicate())
    }
}
#endif
