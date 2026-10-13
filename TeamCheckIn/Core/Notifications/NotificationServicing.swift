// NotificationServicing.swift
// Purpose: Isolate system permissions and account-scoped device registration for testing.
import Foundation

/// Authorization states relevant to an optional pregame alert.
enum NotificationPermission: Sendable { case undecided, allowed, denied }

/// Boundary implemented with iOS notifications and authenticated backend RPCs.
@MainActor
protocol NotificationServicing {
    var userID: UUID? { get }
    func permission() async -> NotificationPermission
    func requestPermission() async throws -> Bool
    func registerWithSystem()
    func unregisterFromSystem()
    func register(token: String, installationID: UUID) async throws
    func revoke(installationID: UUID) async throws
}
