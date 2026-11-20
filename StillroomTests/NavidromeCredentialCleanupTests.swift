import XCTest
import Security
@testable import Stillroom

final class NavidromeCredentialCleanupTests: XCTestCase {
    private let pendingKey = "navidrome.credentials.pendingRemoval.v1"

    func testFailedRemovalPersistsOnlyIdentifierAndNewActorRetriesIt() async throws {
        let defaults = try isolatedDefaults()
        let identifier = "test-only-unreferenced-id"
        let unavailable = CredentialDeletionProbe(statuses: [identifier: errSecInteractionNotAllowed])
        let credentials = NavidromeCredentials(defaults: defaults, deleteItem: { unavailable.delete($0) })

        do { try await credentials.remove(identifier); XCTFail("Failed deletion must remain retryable") }
        catch NavidromeError.credentials {}

        XCTAssertEqual(defaults.stringArray(forKey: pendingKey), [identifier])
        let available = CredentialDeletionProbe(statuses: [:])
        let reopened = NavidromeCredentials(defaults: defaults, deleteItem: { available.delete($0) })
        await reopened.retryPendingRemovals()
        XCTAssertEqual(available.attempts, [identifier])
        XCTAssertEqual(defaults.stringArray(forKey: pendingKey), [])
    }

    func testRetryProtectsActiveCredentialAndRetainsOnlyFailedIdentifiers() async throws {
        let defaults = try isolatedDefaults()
        defaults.set(["active", "unavailable", "gone", "gone"], forKey: pendingKey)
        let deletion = CredentialDeletionProbe(statuses: ["unavailable": errSecNotAvailable, "gone": errSecItemNotFound])
        let credentials = NavidromeCredentials(defaults: defaults, deleteItem: { deletion.delete($0) })

        await credentials.retryPendingRemovals(keeping: "active")

        XCTAssertEqual(deletion.attempts, ["unavailable", "gone"])
        XCTAssertEqual(defaults.stringArray(forKey: pendingKey), ["active", "unavailable"])
    }

    func testReadRetriesOtherPendingItemsWithoutDeletingRequestedIdentifier() async throws {
        let defaults = try isolatedDefaults()
        let protected = UUID().uuidString
        defaults.set([protected, "old-unreferenced-id"], forKey: pendingKey)
        let deletion = CredentialDeletionProbe(statuses: [:])
        let credentials = NavidromeCredentials(defaults: defaults, deleteItem: { deletion.delete($0) })

        let password = try await credentials.read(protected)

        XCTAssertNil(password)
        XCTAssertEqual(deletion.attempts, ["old-unreferenced-id"])
        XCTAssertEqual(defaults.stringArray(forKey: pendingKey), [protected])
    }

    func testSuccessfulSaveCancelsStalePendingDeletionForSameIdentifier() async throws {
        let defaults = try isolatedDefaults()
        let identifier = "OneTape.cleanup-test." + UUID().uuidString
        defaults.set([identifier], forKey: pendingKey)
        let deletion = CredentialDeletionProbe(statuses: [identifier: errSecNotAvailable])
        let credentials = NavidromeCredentials(defaults: defaults, deleteItem: { deletion.delete($0) })
        // This synthetic item belongs to the test, and is removed through the
        // actual Keychain adapter even though failure injection handles retries.
        addTeardownBlock { try? await NavidromeCredentials(defaults: defaults).remove(identifier) }

        try await credentials.save("test-only", as: identifier)

        XCTAssertEqual(defaults.stringArray(forKey: pendingKey), [])
        await credentials.retryPendingRemovals()
        XCTAssertTrue(deletion.attempts.isEmpty)
        let restored = try await credentials.read(identifier)
        XCTAssertEqual(restored, "test-only")
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suite = "OneTape.credential-cleanup." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }
}

private final class CredentialDeletionProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let statuses: [String: OSStatus]
    private var attempted: [String] = []

    init(statuses: [String: OSStatus]) { self.statuses = statuses }

    var attempts: [String] {
        lock.lock()
        defer { lock.unlock() }
        return attempted
    }

    func delete(_ identifier: String) -> OSStatus {
        lock.lock()
        defer { lock.unlock() }
        attempted.append(identifier)
        return statuses[identifier] ?? errSecSuccess
    }
}
