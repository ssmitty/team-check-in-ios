// BackendClientTests.swift
// Purpose: Verify secure session restoration, renewal, failure handling, deletion responses, and invite parsing.
import Foundation
import Testing
@testable import TeamCheckInCore

@MainActor
private final class MemoryVault: SessionStoring {
    var data: Data?
    func read() throws -> Data? { data }
    func write(_ data: Data) throws { self.data = data }
    func clear() throws { data = nil }
}
@MainActor
private final class ScriptedTransport: BackendTransport {
    var results: [(Int, Data)] = []
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let result = results.removeFirst()
        return (
            result.1,
            HTTPURLResponse(
                url: request.url!, statusCode: result.0,
                httpVersion: nil, headerFields: nil)!
        )
    }
}
@MainActor
struct BackendClientTests {
    private func config() throws -> BackendConfiguration {
        try BackendConfiguration(
            url: URL(string: "https://test.example")!, publicKey: "sb_publishable_fixture")
    }
    private func session(expiry: TimeInterval = 1000, token: String = "fixture-access") throws
        -> Data
    {
        try JSONEncoder().encode(
            AccountSession(
                accessToken: token, refreshToken: "fixture-refresh",
                expiresAt: expiry,
                user: .init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)))
    }
    @Test func restoreRefreshesExpiredSessionBeforeReadingPrivateData() async throws {
        let vault = MemoryVault(); vault.data = try session()
        let transport = ScriptedTransport()
        transport.results = [
            (200, try session(expiry: 10000, token: "renewed")), (200, Data("[]".utf8)),
        ]
        let client = BackendClient(
            config: try config(), network: transport, vault: vault,
            now: { Date(timeIntervalSince1970: 2000) })
        try await client.restore()
        _ = try await client.request("rest/v1/check_ins?select=*")
        #expect(transport.requests[0].url?.path == "/auth/v1/token")
        #expect(
            transport.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer renewed")
        #expect(
            try JSONDecoder().decode(AccountSession.self, from: #require(vault.data)).accessToken
                == "renewed")
    }
    @Test func rejectedRefreshClearsStoredSession() async throws {
        let vault = MemoryVault(); vault.data = try session()
        let transport = ScriptedTransport(); transport.results = [(400, Data())]
        let client = BackendClient(
            config: try config(), network: transport, vault: vault,
            now: { Date(timeIntervalSince1970: 2000) })
        await #expect(throws: BackendError.self) { try await client.restore() }
        #expect(vault.data == nil)
        #expect(client.userID == nil)
    }
    @Test func transientRefreshDoesNotDiscardSession() async throws {
        let vault = MemoryVault(); vault.data = try session()
        let transport = ScriptedTransport(); transport.results = [(503, Data())]
        let client = BackendClient(
            config: try config(), network: transport, vault: vault,
            now: { Date(timeIntervalSince1970: 2000) })
        await #expect(throws: BackendError.self) { try await client.restore() }
        #expect(vault.data != nil)
    }
    @Test func signOutClearsLocalSecretsEvenWhenRemoteLogoutFails() async throws {
        let vault = MemoryVault(); vault.data = try session(expiry: 10000)
        let transport = ScriptedTransport(); transport.results = [(503, Data())]
        let client = BackendClient(
            config: try config(), network: transport, vault: vault,
            now: { Date(timeIntervalSince1970: 2000) })
        try await client.restore()
        await #expect(throws: BackendError.self) { try await client.signOut() }
        #expect(client.userID == nil)
        #expect(vault.data == nil)
    }
    @Test func inviteParserRejectsUnexpectedHostsQueriesAndTokens() throws {
        let token = String(repeating: "a", count: 48)
        #expect(try InviteToken.parse("teamcheckin://join/" + token) == token)
        #expect(throws: PrototypeError.self) { try InviteToken.parse("https://join/" + token) }
        #expect(throws: PrototypeError.self) {
            try InviteToken.parse("teamcheckin://join/" + token + "?role=captain")
        }
        #expect(throws: PrototypeError.self) { try InviteToken.parse("demo") }
    }
    @Test func configurationRejectsServiceKeysAndInsecureURLs() {
        #expect(throws: BackendError.self) {
            try BackendConfiguration(
                url: URL(string: "https://test.example")!, publicKey: "sb_secret_fixture")
        }
        #expect(throws: BackendError.self) {
            try BackendConfiguration(
                url: URL(string: "http://test.example")!, publicKey: "sb_publishable_fixture")
        }
    }
    @Test func pendingDeletionDoesNotDiscardRetryCredentials() async throws {
        let vault = MemoryVault(); vault.data = try session(expiry: 10000)
        let transport = ScriptedTransport();
        transport.results = [(202, Data("{\"deleted\":false,\"needs_retry\":true}".utf8))]
        let client = BackendClient(
            config: try config(), network: transport, vault: vault,
            now: { Date(timeIntervalSince1970: 2000) })
        try await client.restore()
        do {
            try await LiveTeamService(client: client).deleteAccount(password: "fixture");
            Issue.record("Partial cleanup was reported as complete")
        } catch BackendError.deletionPending {}
        #expect(client.userID != nil)
        #expect(vault.data != nil)
    }
    @Test func completedDeletionClearsVaultWithoutLoggingOutDeletedUser() async throws {
        let vault = MemoryVault(); vault.data = try session(expiry: 10000)
        let transport = ScriptedTransport();
        transport.results = [(200, Data("{\"deleted\":true}".utf8))]
        let client = BackendClient(
            config: try config(), network: transport, vault: vault,
            now: { Date(timeIntervalSince1970: 2000) })
        try await client.restore()
        try await LiveTeamService(client: client).deleteAccount(password: "fixture")
        #expect(client.userID == nil)
        #expect(vault.data == nil)
        #expect(transport.requests.count == 1)
        #expect(transport.requests[0].url?.path == "/functions/v1/delete-account")
    }
    @Test func captainDeletionConflictHasAnActionableMessage() async throws {
        let vault = MemoryVault(); vault.data = try session(expiry: 10000)
        let transport = ScriptedTransport(); transport.results = [(409, Data())]
        let client = BackendClient(
            config: try config(), network: transport, vault: vault,
            now: { Date(timeIntervalSince1970: 2000) })
        try await client.restore()
        do {
            try await LiveTeamService(client: client).deleteAccount(password: "fixture");
            Issue.record("Captain deletion should be blocked")
        } catch BackendError.captainTransferRequired {}
        #expect(client.userID != nil)
    }

}
