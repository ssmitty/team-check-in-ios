// BackendTransport.swift
// Purpose: Inject HTTP delivery so account renewal can be verified without real credentials.
import Foundation

/// Authenticated networking boundary with no persistent token storage.
@MainActor
protocol BackendTransport {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}
@MainActor
struct SessionTransport: BackendTransport {
    let session: URLSession
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
