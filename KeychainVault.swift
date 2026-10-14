import Foundation
import Security
import LocalAuthentication

/// Stores recovery phrases in the iOS Keychain: this-device-only, never in iCloud backups, and gated by
/// user presence (Face ID / Touch ID / passcode) on every read.
/// All Keychain calls run off the main thread so the system authentication prompt never blocks the UI.
final class KeychainVault: @unchecked Sendable {
    private let service = "com.vaulteth.app.wallet"

    func save(_ mnemonic: String, id: UUID) async throws {
        try await Task.detached(priority: .userInitiated) { try self.saveSync(mnemonic, id: id) }.value
    }

    func load(id: UUID, reason: String) async throws -> String {
        var data = try await loadData(id: id, reason: reason)
        defer { data.resetBytes(in: 0..<data.count) }
        guard let phrase = String(data: data, encoding: .utf8) else { throw WalletError.keyNotFound }
        return phrase
    }

    func loadData(id: UUID, reason: String) async throws -> Data {
        try await Task.detached(priority: .userInitiated) { try self.loadDataSync(id: id, reason: reason) }.value
    }

    func delete(id: UUID) {
        SecItemDelete(baseQuery(id) as CFDictionary)
    }

    private func baseQuery(_ id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: id.uuidString]
    }

    private func saveSync(_ mnemonic: String, id: UUID) throws {
        var authError: NSError?
        guard LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            throw WalletError.authenticationUnavailable
        }
        var cfError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .userPresence, &cfError
        ) else { throw WalletError.authenticationUnavailable }

        SecItemDelete(baseQuery(id) as CFDictionary)
        var add = baseQuery(id)
        let mnemonicData = Data(mnemonic.utf8)
        add[kSecValueData as String] = mnemonicData
        add[kSecAttrAccessControl as String] = access
        let status = SecItemAdd(add as CFDictionary, nil)
        var scratch = mnemonicData
        scratch.resetBytes(in: 0..<scratch.count)
        guard status == errSecSuccess else { throw WalletError.keychain(status) }
    }

    private func loadDataSync(id: UUID, reason: String) throws -> Data {
        let context = LAContext()
        context.localizedReason = reason
        var query = baseQuery(id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw WalletError.keyNotFound }
            return data
        case errSecUserCanceled, errSecAuthFailed: throw WalletError.authenticationFailed
        case errSecItemNotFound: throw WalletError.keyNotFound
        default: throw WalletError.keychain(status)
        }
    }
}
