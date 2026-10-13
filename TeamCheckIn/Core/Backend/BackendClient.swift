// BackendClient.swift
// Purpose: Centralize authenticated HTTPS requests and Keychain session renewal.
import Foundation

/// One REST client per app account, with injected network, vault, and clock.
@MainActor
final class BackendClient {
    private let config: BackendConfiguration
    private let network: any BackendTransport
    private let vault: any SessionStoring
    private let now: () -> Date
    private var session: AccountSession?
    private var renewal: Task<AccountSession, Error>?
    var userID: UUID? { session?.user.id }

    init(
        config: BackendConfiguration,
        network: any BackendTransport = SessionTransport(session: .shared),
        vault: any SessionStoring, now: @escaping () -> Date = Date.init
    ) {
        self.config = config
        self.network = network
        self.vault = vault
        self.now = now
    }

    /// Restore then refresh a previous session, preserving it on transient errors.
    func restore() async throws {
        if let data = try vault.read() {
            session = try JSONDecoder().decode(AccountSession.self, from: data)
        }
        if session != nil { _ = try await accessToken() }
    }

    /// Sign in with an email/password or create an account requiring confirmation.
    func authenticate(email: String, password: String, create: Bool) async throws -> Bool {
        let path = create ? "auth/v1/signup" : "auth/v1/token?grant_type=password"
        let data = try await send(
            path: path, method: "POST",
            body: try JSONEncoder().encode(["email": email, "password": password]), token: nil)
        if create, let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            result["access_token"] == nil
        {
            return false
        }
        try accept(JSONDecoder().decode(AccountSession.self, from: data))
        return true
    }

    /// Clear local secrets first; report remote logout failures separately.
    func signOut() async throws {
        let token = session?.accessToken
        try vault.clear()
        session = nil
        renewal?.cancel()
        renewal = nil
        if let token {
            _ = try await send(path: "auth/v1/logout", method: "POST", body: nil, token: token)
        }
    }

    func request(
        _ path: String, method: String = "GET", body: Data? = nil,
        contentType: String = "application/json"
    ) async throws -> Data {
        try await send(
            path: path, method: method, body: body, token: accessToken(), contentType: contentType)
    }

    private func accept(_ value: AccountSession) throws {
        try vault.write(JSONEncoder().encode(value))
        session = value
    }

    private func accessToken() async throws -> String {
        guard let session else { throw BackendError.signedOut }
        if session.expiresAt > now().timeIntervalSince1970 + 60 { return session.accessToken }
        if let renewal { return try await renewal.value.accessToken }
        let task = Task {
            let data = try await self.send(
                path: "auth/v1/token?grant_type=refresh_token", method: "POST",
                body: try JSONEncoder().encode(["refresh_token": session.refreshToken]), token: nil)
            return try JSONDecoder().decode(AccountSession.self, from: data)
        }
        renewal = task
        defer { renewal = nil }
        do {
            let value = try await task.value
            try Task.checkCancellation()
            guard self.session?.user.id == session.user.id else { throw BackendError.signedOut }
            try accept(value)
            return value.accessToken
        } catch BackendError.rejected(400) {
            try vault.clear()
            self.session = nil
            throw BackendError.signedOut
        }
    }

    private func send(
        path: String, method: String, body: Data?, token: String?,
        contentType: String = "application/json"
    ) async throws
        -> Data
    {
        guard let url = URL(string: path, relativeTo: config.url.appendingPathComponent("")) else {
            throw BackendError.configuration
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 20
        request.setValue(config.publicKey, forHTTPHeaderField: "apikey")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        let (data, response) = try await network.send(request)
        guard let response = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw BackendError.rejected(response.statusCode)
        }
        return data
    }
}
