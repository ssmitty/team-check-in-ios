// AppEntryView.swift
// Purpose: Choose configured account mode or the clearly labeled local demo.
import SwiftUI

/// Configuration failures remain visible instead of silently joining a demo team.
struct AppEntryView: View {
    @State private var live: LiveTeamStore?
    @State private var demo = TeamStore()
    @State private var configurationError: String?
    init() {
        do {
            if let config = try BackendConfiguration.load() {
                let client = BackendClient(
                    config: config, vault: SessionVault(account: config.url.absoluteString))
                _live = State(
                    initialValue: LiveTeamStore(
                        service: LiveTeamService(client: client),
                        photos: PrivatePhotoService(client: client)))
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
        } else {
            RootView(store: demo)
                .onOpenURL { url in Task { await demo.join(invite: url.absoluteString) } }
        }
    }
}
#Preview { AppEntryView() }
