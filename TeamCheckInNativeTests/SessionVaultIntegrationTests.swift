// SessionVaultIntegrationTests.swift
// Purpose: Verify shipped secure-session storage using the simulator app's real Keychain.
import Security
import XCTest
@testable import TeamCheckIn

final class SessionVaultIntegrationTests: XCTestCase {
    /// Synthetic data only, isolated by a new account identifier and deleted before returning.
    @MainActor
    func testVaultRestoresUpdatesIsolatesAndClearsSessions() async throws {
        let account = "native-keychain-test." + UUID().uuidString
        let vault = SessionVault(account: account)
        let other = SessionVault(account: account + ".other")
        let userID = UUID()
        let session = AccountSession(
            accessToken: "synthetic-access", refreshToken: "synthetic-refresh",
            expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970,
            user: .init(id: userID))
        do {
            XCTAssertNil(try vault.read())
            try vault.write(JSONEncoder().encode(session))
            let reopened = SessionVault(account: account)
            XCTAssertEqual(try reopened.read(), try vault.read())
            XCTAssertNil(try other.read())
            try assertDeviceOnlyProtection(account: account)
            let config = try BackendConfiguration(
                url: try XCTUnwrap(URL(string: "https://keychain-test.example")),
                publicKey: "sb_publishable_synthetic-keychain-test")
            let client = BackendClient(config: config, network: UnusedTransport(), vault: reopened)
            try await client.restore()
            XCTAssertEqual(client.userID, userID)
            let replacement = Data("updated-synthetic-session".utf8)
            try reopened.write(replacement)
            XCTAssertEqual(try vault.read(), replacement)
            try client.clearLocalSession()
            XCTAssertNil(client.userID)
            XCTAssertNil(try vault.read())
            try vault.clear()
            try other.clear()
        } catch {
            try vault.clear()
            try other.clear()
            throw error
        }
    }

    @MainActor
    private func assertDeviceOnlyProtection(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.ssmitty.TeamCheckIn.session",
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &item), errSecSuccess)
        let attributes = try XCTUnwrap(item as? [String: Any])
        XCTAssertEqual(
            attributes[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }
}

/// An unexpired restored session must never need a network call in this test.
private struct UnusedTransport: BackendTransport {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        throw BackendError.invalidResponse
    }
}
