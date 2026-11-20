import Foundation
import Security

actor NavidromeCredentials {
    private let service = "com.liuhang.stillroom.navidrome.credentials.v1"
    private let defaults: UserDefaults
    private let deleteItem: (@Sendable (String) -> OSStatus)?
    private let pendingRemovalKey = "navidrome.credentials.pendingRemoval.v1"

    init(defaults: UserDefaults = .standard, deleteItem: (@Sendable (String) -> OSStatus)? = nil) {
        self.defaults = defaults
        self.deleteItem = deleteItem
    }

    func read(_ identifier: String) throws -> String? {
        retryPendingRemovals(keeping: identifier)
        var query = key(identifier)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data,
              let password = String(data: data, encoding: .utf8) else { throw NavidromeError.credentials }
        return password
    }

    func save(_ password: String, as identifier: String) throws {
        guard !password.isEmpty else { throw NavidromeError.missingPassword }
        retryPendingRemovals(keeping: identifier)
        var query = key(identifier)
        query[kSecValueData as String] = Data(password.utf8)
        // Next-track playback from the lock screen must remain able to resolve
        // credentials after the first unlock; nothing is synchronized to iCloud.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query[kSecAttrSynchronizable as String] = false
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update = [kSecValueData as String: Data(password.utf8)]
            guard SecItemUpdate(key(identifier) as CFDictionary, update as CFDictionary) == errSecSuccess else {
                throw NavidromeError.credentials
            }
        } else if status != errSecSuccess { throw NavidromeError.credentials }
        // An identifier that became active again must never be deleted by a
        // deferred cleanup from an earlier disconnected session.
        forgetPendingRemoval(identifier)
    }

    func remove(_ identifier: String) throws {
        let status = deletionStatus(identifier)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            var pending = pendingRemovals
            if !pending.contains(identifier) { pending.append(identifier) }
            defaults.set(pending, forKey: pendingRemovalKey)
            throw NavidromeError.credentials
        }
        forgetPendingRemoval(identifier)
    }

    /// Only app-owned Keychain identifiers are persisted here. Failed cleanup
    /// must not roll back an already committed account/catalog replacement.
    /// A cold restore passes its active credential before attempting old IDs.
    func retryPendingRemovals(keeping activeIdentifier: String? = nil) {
        var remaining: [String] = []
        for identifier in pendingRemovals {
            guard identifier != activeIdentifier else { remaining.append(identifier); continue }
            let status = deletionStatus(identifier)
            if status != errSecSuccess && status != errSecItemNotFound { remaining.append(identifier) }
        }
        defaults.set(remaining, forKey: pendingRemovalKey)
    }

    private var pendingRemovals: [String] {
        var seen = Set<String>()
        return (defaults.stringArray(forKey: pendingRemovalKey) ?? [])
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private func forgetPendingRemoval(_ identifier: String) {
        defaults.set(pendingRemovals.filter { $0 != identifier }, forKey: pendingRemovalKey)
    }

    private func deletionStatus(_ identifier: String) -> OSStatus {
        deleteItem?(identifier) ?? SecItemDelete(key(identifier) as CFDictionary)
    }

    private func key(_ identifier: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: identifier]
    }
}
