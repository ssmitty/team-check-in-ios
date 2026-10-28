// LiveRoutedGameView.swift
// Purpose: Open the validated notification event without substituting a different game.
import SwiftUI

/// Shows unavailable, waiting, or assigned states after a caller-scoped route lookup.
struct LiveRoutedGameView: View {
    @Bindable var store: LiveTeamStore
    var body: some View {
        if store.isGameUpcoming, let game = store.game, let start = game.start {
            if store.assignmentID != nil {
                LiveCheckInView(store: store)
            } else {
                List {
                    Text(game.title).font(.headline)
                    Text(start, format: .dateTime.month().day().hour().minute())
                    Text(
                        "Connections open one hour before the game. You can check in without notifications."
                    )
                    Button("Refresh my connection") { Task { await store.prepareConnection() } }
                        .disabled(store.isBusy || !store.isGameWindowOpen)
                }
                .navigationTitle("Your game")
                .refreshable { await store.refresh() }
            }
        } else {
            ContentUnavailableView(
                "Game unavailable", systemImage: "calendar.badge.exclamationmark",
                description: Text(
                    "This game has ended or was canceled. Return to your team's schedule."))
        }
    }
}
#Preview { LiveRoutedGameView(store: LiveTeamStore(service: PreviewLiveService())) }
