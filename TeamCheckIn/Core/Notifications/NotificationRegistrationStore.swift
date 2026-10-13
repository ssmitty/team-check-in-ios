// NotificationRegistrationStore.swift
// Purpose: Make alerts optional and preserve registration retry without blocking check-ins.
import Foundation
import Observation

/// Device tokens stay in memory; only a non-sensitive installation identifier is persisted.
@MainActor @Observable
final class NotificationRegistrationStore {
    private let service: any NotificationServicing
    private let installationID: UUID
    private var token: String?
    private var accountID: UUID?
    private(set) var permission: NotificationPermission = .undecided
    private(set) var isBusy = false
    private(set) var message = "Optional alerts can remind you when a connection opens."

    init(service: any NotificationServicing, installationID: UUID) {
        self.service = service
        self.installationID = installationID
    }

    /// Checks existing permission without prompting during account restoration.
    func synchronizeAccount() async {
        accountID = service.userID
        guard let userID = accountID else {
            service.unregisterFromSystem()
            token = nil
            return
        }
        let currentPermission = await service.permission()
        guard accountID == userID, service.userID == userID else { return }
        permission = currentPermission
        if permission == .allowed { service.registerWithSystem(); await saveToken() }
        if permission == .denied {
            service.unregisterFromSystem()
            token = nil
            do { try await service.revoke(installationID: installationID) } catch {
                message = "Alerts are off. Server registration removal could not be confirmed."
            }
        }
    }

    /// Called explicitly from the schedule screen, never from initial sign-in.
    func enable() async {
        guard !isBusy, service.userID != nil else { return }
        accountID = service.userID
        let userID = accountID
        isBusy = true
        defer { isBusy = false }
        do {
            let allowed = try await service.requestPermission()
            guard accountID == userID, service.userID == userID else { return }
            permission = allowed ? .allowed : .denied
            guard allowed else {
                service.unregisterFromSystem()
                token = nil
                message = "Alerts are off. You can still check in from your team's schedule."
                return
            }
            accountID = service.userID
            service.registerWithSystem()
            message = "Waiting for device registration."
            await saveToken()
        } catch { message = "Couldn't request alerts. You can still check in from the schedule." }
    }

    /// Apple token bytes are formatted without assuming a fixed token size.
    func receive(token data: Data) async {
        guard let accountID, accountID == service.userID else { return }
        guard (16...256).contains(data.count) else {
            registrationFailed()
            return
        }
        token = data.map { String(format: "%02x", $0) }.joined()
        await saveToken()
    }

    func registrationFailed() {
        message =
            "Couldn't set up alerts. Retry or check in from your team's schedule."
    }

    /// Stops system registration even if the backend revoke request fails offline.
    func disconnect() async -> Bool {
        service.unregisterFromSystem()
        token = nil
        accountID = nil
        message = "Alerts are off for this account."
        do { try await service.revoke(installationID: installationID); return true } catch {
            return false
        }
    }

    private func saveToken() async {
        guard permission == .allowed, let token, let userID = accountID,
            userID == service.userID
        else { return }
        do {
            try await service.register(token: token, installationID: installationID)
            guard accountID == userID, service.userID == userID else { return }
            message =
                "Device registered. Alert delivery is being prepared; check in from the schedule for now."
        } catch {
            guard accountID == userID, service.userID == userID else { return }
            message = "Couldn't save device registration. Tap Enable alerts to retry."
        }
    }
}
