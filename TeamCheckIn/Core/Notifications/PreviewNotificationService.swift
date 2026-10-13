// PreviewNotificationService.swift
// Purpose: Show the optional notification section without system permission or backend effects.
import Foundation

@MainActor
struct PreviewNotificationService: NotificationServicing {
    var userID: UUID? { nil }
    func permission() async -> NotificationPermission { .undecided }
    func requestPermission() async throws -> Bool { false }
    func registerWithSystem() {}
    func unregisterFromSystem() {}
    func register(token: String, installationID: UUID) async throws {
        throw BackendError.configuration
    }
    func revoke(installationID: UUID) async throws {}
}
