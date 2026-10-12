// SessionVault.swift
// Purpose: Persist account sessions in the system Keychain, isolated by backend.
import Foundation
import Security

/// Secure storage boundary injected into the auth client for tests.
@MainActor
protocol SessionStoring {
    func read() throws -> Data?
    func write(_ data: Data) throws
    func clear() throws
}

/// Device-only Keychain storage that never writes tokens to defaults or files.
@MainActor
struct SessionVault: SessionStoring {
    let account: String
    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.ssmitty.TeamCheckIn.session",
            kSecAttrAccount as String: account,
        ]
    }
    func read() throws -> Data? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw BackendError.secureStorage
        }
        return data
    }
    func write(_ data: Data) throws {
        let status = SecItemUpdate(
            query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var request = query
            request[kSecValueData as String] = data
            request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(request as CFDictionary, nil) == errSecSuccess else {
                throw BackendError.secureStorage
            }
        } else if status != errSecSuccess {
            throw BackendError.secureStorage
        }
    }
    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw BackendError.secureStorage
        }
    }
}
