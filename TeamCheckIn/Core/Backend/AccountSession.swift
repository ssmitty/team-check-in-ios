// AccountSession.swift
// Purpose: Decode Auth sessions and track expiry for secure token renewal.
import Foundation

/// Sensitive session data, persisted only by SessionStoring and never logged.
struct AccountSession: Codable, Sendable {
    struct User: Codable, Sendable { let id: UUID }
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval
    let user: User
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token", refreshToken = "refresh_token"
        case expiresAt = "expires_at", user
    }
}
