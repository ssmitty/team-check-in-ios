// RootView.swift
// Purpose: Route between team entry and the prototype's two main tabs.
import SwiftUI

/// Root navigation with shared state and recoverable error presentation.
struct RootView: View {
    @Bindable var store: TeamStore
    var body: some View {
        VStack(spacing: 0) {
            DemoBanner()
            if store.teamName == nil {
                WelcomeView(store: store)
            } else {
                TabView {
                    NavigationStack { TodayView(store: store) }
                        .tabItem { Label("Today", systemImage: "heart.text.square") }
                    NavigationStack { TeamView(store: store) }
                        .tabItem { Label("Team", systemImage: "person.2") }
                }
            }
        }
        .alert(
            "Couldn't complete that",
            isPresented: Binding(
                get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "Try again.")
        }
    }
}
#Preview { RootView(store: TeamStore()) }
