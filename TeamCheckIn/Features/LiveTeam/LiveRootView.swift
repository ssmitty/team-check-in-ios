// LiveRootView.swift
// Purpose: Route authenticated backend screens and retain invites through sign-in.
import SwiftUI

/// Real account mode, clearly separate from the session-only prototype.
struct LiveRootView: View {
    @Bindable var store: LiveTeamStore
    var body: some View {
        NavigationStack {
            Group {
                if !store.hasRestored {
                    ProgressView("Restoring account")
                } else if store.userID == nil {
                    AccountView(store: store)
                } else if store.team == nil {
                    LiveTeamEntryView(store: store)
                } else {
                    LiveDashboardView(store: store)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if store.isBusy { ProgressView("Updating").padding().background(.regularMaterial) }
            }
            .alert(
                "Couldn't complete that",
                isPresented: Binding(
                    get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }
                )
            ) {
                Button("OK") { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "Please try again.")
            }
            .safeAreaInset(edge: .top) {
                if let message = store.infoMessage {
                    Text(message).font(.footnote).padding().frame(maxWidth: .infinity)
                        .background(.thinMaterial).accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
        .task { await store.restore() }
        .onOpenURL { store.pendingInvite = $0.absoluteString }
    }
}
#Preview { LiveRootView(store: LiveTeamStore(service: PreviewLiveService())) }
