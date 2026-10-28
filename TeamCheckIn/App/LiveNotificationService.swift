// LiveNotificationService.swift
// Purpose: Connect optional iOS alert permission and registration to protected device RPCs.
import UIKit
import UserNotifications

/// Uses the same account client as team data and never accepts a privileged credential.
@MainActor
struct LiveNotificationService: NotificationServicing {
    let client: BackendClient
    let environment: String
    var userID: UUID? { client.userID }
    func permission() async -> NotificationPermission {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .allowed
        case .denied: .denied
        case .notDetermined: .undecided
        @unknown default: .denied
        }
    }
    func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
    func registerWithSystem() { UIApplication.shared.registerForRemoteNotifications() }
    func unregisterFromSystem() { UIApplication.shared.unregisterForRemoteNotifications() }
    func register(token: String, installationID: UUID) async throws {
        _ = try await client.request(
            "rest/v1/rpc/register_push_device", method: "POST",
            body: JSONEncoder().encode([
                "p_installation": installationID.uuidString,
                "p_token": token, "p_environment": environment,
            ]))
    }
    func revoke(installationID: UUID) async throws {
        _ = try await client.request(
            "rest/v1/rpc/revoke_push_device", method: "POST",
            body: JSONEncoder().encode(["p_installation": installationID.uuidString]))
    }
    /// A UUID preference identifies the installation, not the player or Apple device token.
    static func installationID(defaults: UserDefaults = .standard) -> UUID {
        let key = "notificationInstallationID"
        if let value = defaults.string(forKey: key), let id = UUID(uuidString: value) { return id }
        let id = UUID(); defaults.set(id.uuidString, forKey: key)
        return id
    }
}
