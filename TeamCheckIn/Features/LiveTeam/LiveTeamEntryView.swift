// LiveTeamEntryView.swift
// Purpose: Create a captain-owned team or redeem a real invitation after sign-in.
import SwiftUI

/// Team entry uses protected operations with retryable invitation redemption.
struct LiveTeamEntryView: View {
    @Bindable var store: LiveTeamStore
    @State private var displayName = ""
    @State private var teamName = ""
    var body: some View {
        Form {
            Section("What should teammates call you?") {
                TextField("Your name", text: $displayName)
            }
            Section("Join your team") {
                TextField("Invitation link", text: $store.pendingInvite)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Join team") { Task { await store.join(displayName: displayName) } }
                    .disabled(store.isBusy || displayName.isEmpty)
            }
            Section("Create a team as captain") {
                TextField("Team name", text: $teamName)
                Button("Create team") {
                    Task { await store.create(name: teamName, displayName: displayName) }
                }
                .disabled(store.isBusy || displayName.isEmpty || teamName.isEmpty)
            }
            Button("Sign out", role: .destructive) { Task { await store.signOut() } }
        }.navigationTitle("Your team")
    }
}
#Preview { LiveTeamEntryView(store: LiveTeamStore(service: PreviewLiveService())) }
