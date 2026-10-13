// AppEntryView.swift
// Purpose: Choose configured account mode or the clearly labeled local demo.
import SwiftUI

/// Configuration failures remain visible instead of silently joining a demo team.
struct AppEntryView: View {
    @Environment(\.scenePhase) private var scenePhase
    let routes: NotificationRouteInbox
    let registration: NotificationRegistrationInbox
    @State private var live: LiveTeamStore?
    @State private var demo = TeamStore()
    @State private var configurationError: String?
    init(
        routes: NotificationRouteInbox = NotificationRouteInbox(),
        registration: NotificationRegistrationInbox = NotificationRegistrationInbox()
    ) {
        self.routes = routes
        self.registration = registration
        do {
            if let config = try BackendConfiguration.load() {
                let client = BackendClient(
                    config: config, vault: SessionVault(account: config.url.absoluteString))
                let environment =
                    Bundle.main.object(forInfoDictionaryKey: "APNS_ENVIRONMENT") as? String
                let notifications: NotificationRegistrationStore?
                if let environment, ["sandbox", "production"].contains(environment) {
                    notifications = NotificationRegistrationStore(
                        service: LiveNotificationService(client: client, environment: environment),
                        installationID: LiveNotificationService.installationID())
                } else {
                    notifications = nil
                }
                _live = State(
                    initialValue: LiveTeamStore(
                        service: LiveTeamService(client: client),
                        photos: PrivatePhotoService(client: client), notifications: notifications))
            }
        } catch { _configurationError = State(initialValue: error.localizedDescription) }
    }
    var body: some View {
        if let configurationError {
            ContentUnavailableView(
                "Configuration needed", systemImage: "gearshape",
                description: Text(configurationError))
        } else if let live {
            LiveRootView(store: live)
                .task(id: live.userID) {
                    await live.notifications?.synchronizeAccount()
                    if let token = registration.token {
                        await live.notifications?.receive(token: token)
                    }
                    if live.userID == nil { registration.clear() }
                }
                .task(id: registration.token) {
                    if let token = registration.token {
                        await live.notifications?.receive(token: token)
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await live.notifications?.synchronizeAccount() } }
                }
                .onChange(of: registration.failureID) { _, failureID in
                    if failureID != nil { live.notifications?.registrationFailed() }
                }
                .task(id: routes.gameID) {
                    guard let id = routes.gameID else { return }
                    await live.receive(.game(id))
                    routes.consume(id)
                }
        } else {
            RootView(store: demo)
                .onOpenURL { url in Task { await demo.join(invite: url.absoluteString) } }
        }
    }
}
#Preview { AppEntryView() }
