// LiveRootView.swift
// Purpose: Route authenticated backend screens and retain invites through sign-in.
import SwiftUI

/// Real account mode, clearly separate from the session-only prototype.
struct LiveRootView: View {
    @State private var showsAccountSettings = false
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
            .toolbar {
                if store.userID != nil {
                    Button("Account settings", systemImage: "person.crop.circle") {
                        showsAccountSettings = true
                    }
                }
            }
            .navigationDestination(isPresented: $store.showsRoutedGame) {
                LiveRoutedGameView(store: store)
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
        .sheet(isPresented: $showsAccountSettings) { AccountSettingsView(store: store) }
        .onChange(of: store.userID) { _, id in if id == nil { showsAccountSettings = false } }
        .task { await store.restore() }
        .onOpenURL { url in
            guard let route = AppRoute.parse(url) else { return }
            Task { await store.receive(route) }
        }
        .onChange(of: store.showsRoutedGame) { _, isShowing in
            if !isShowing { Task { await store.finishGameRoute() } }
        }
    }
}
#Preview { LiveRootView(store: LiveTeamStore(service: PreviewLiveService())) }
