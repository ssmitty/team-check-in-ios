// NotificationRegistrationTests.swift
// Purpose: Verify optional permission, retry, sign-out races, and device-token lifetime with injected services.
import Foundation
import Testing
@testable import TeamCheckInCore

@MainActor
final class ScriptedNotificationService: NotificationServicing {
    var userID: UUID? = UUID()
    var authorization: NotificationPermission = .undecided
    var allowsPermission = true
    var failRegistration = false
    var failRevoke = false
    var permissionRequests = 0
    var systemRegistrations = 0
    var systemStops = 0
    var registeredTokens: [String] = []
    var onPermission: (() async -> Void)?
    func permission() async -> NotificationPermission { authorization }
    func requestPermission() async throws -> Bool {
        permissionRequests += 1
        if let onPermission { await onPermission() }
        return allowsPermission
    }
    func registerWithSystem() { systemRegistrations += 1 }
    func unregisterFromSystem() { systemStops += 1 }
    func register(token: String, installationID: UUID) async throws {
        if failRegistration { throw BackendError.rejected(503) }
        registeredTokens.append(token)
    }
    func revoke(installationID: UUID) async throws {
        if failRevoke { throw BackendError.rejected(503) }
    }
}

@MainActor
struct NotificationRegistrationTests {
    @Test func restorationNeverPromptsForPermission() async {
        let service = ScriptedNotificationService()
        let store = NotificationRegistrationStore(service: service, installationID: UUID())
        await store.synchronizeAccount()
        #expect(service.permissionRequests == 0)
        #expect(service.systemRegistrations == 0)
    }
    @Test func deniedPermissionPreservesInAppParticipation() async {
        let service = ScriptedNotificationService(); service.allowsPermission = false
        let store = NotificationRegistrationStore(service: service, installationID: UUID())
        await store.enable()
        await store.receive(token: Data(repeating: 1, count: 32))
        #expect(store.permission == .denied)
        #expect(service.registeredTokens.isEmpty)
        #expect(service.systemRegistrations == 0)
        #expect(store.message.contains("still check in"))
    }
    @Test func failedRegistrationCanRetryWithTheSameToken() async {
        let service = ScriptedNotificationService(); service.failRegistration = true
        let store = NotificationRegistrationStore(service: service, installationID: UUID())
        await store.enable()
        await store.receive(token: Data(repeating: 1, count: 32))
        #expect(store.message.contains("retry"))
        service.failRegistration = false
        await store.enable()
        #expect(service.registeredTokens == [String(repeating: "01", count: 32)])
    }
    @Test func offlineDisconnectStopsSystemAndClearsCachedToken() async {
        let service = ScriptedNotificationService(); service.authorization = .allowed
        let store = NotificationRegistrationStore(service: service, installationID: UUID())
        await store.synchronizeAccount()
        await store.receive(token: Data(repeating: 1, count: 32))
        service.failRevoke = true
        #expect(await store.disconnect() == false)
        #expect(service.systemStops == 1)
        await store.synchronizeAccount()
        #expect(
            service.registeredTokens.count == 1,
            "Old bytes were cleared; a fresh callback is required")
    }
    @Test func signOutDuringPermissionRequestCannotRestartRegistration() async {
        let service = ScriptedNotificationService()
        let store = NotificationRegistrationStore(service: service, installationID: UUID())
        service.onPermission = {
            _ = await store.disconnect()
            service.userID = nil
        }
        await store.enable()
        #expect(service.systemRegistrations == 0)
        #expect(service.registeredTokens.isEmpty)
        #expect(!store.isBusy)
    }
    @Test func malformedAndSignedOutCallbacksCannotRegister() async {
        let service = ScriptedNotificationService(); service.authorization = .allowed
        let store = NotificationRegistrationStore(service: service, installationID: UUID())
        await store.synchronizeAccount()
        await store.receive(token: Data())
        #expect(service.registeredTokens.isEmpty)
        _ = await store.disconnect(); service.userID = nil
        await store.receive(token: Data(repeating: 1, count: 32))
        #expect(service.registeredTokens.isEmpty)
    }
    @Test func changedSettingsStopFutureRegistrationWithoutNewPrompt() async {
        let service = ScriptedNotificationService(); service.authorization = .allowed
        let store = NotificationRegistrationStore(service: service, installationID: UUID())
        await store.synchronizeAccount()
        await store.receive(token: Data(repeating: 1, count: 32))
        service.authorization = .denied
        await store.synchronizeAccount()
        await store.receive(token: Data(repeating: 1, count: 32))
        #expect(service.systemStops == 1)
        #expect(service.registeredTokens.count == 1)
        #expect(service.permissionRequests == 0)
    }

}
