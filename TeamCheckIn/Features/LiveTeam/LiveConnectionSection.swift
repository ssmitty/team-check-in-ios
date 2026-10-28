// LiveConnectionSection.swift
// Purpose: Present optional participation and clear waiting, ready, and unavailable states.
import SwiftUI

struct LiveConnectionSection: View {
    @Bindable var store: LiveTeamStore
    var body: some View {
        TitledSection("Your teammate connection") {
            switch store.connectionState {
            case .noGame: Text("Your captain can schedule the next game.")
            case .closed: Text("This game's check-in has closed.")
            case .waiting:
                if let start = store.game?.start {
                    Text(
                        "Opens \(start.addingTimeInterval(-3600), format: .dateTime.month().day().hour().minute())."
                    )
                }
                participationButton
            case .skipped:
                Text("You chose to sit out this connection. Sharing is always optional.")
                if store.canChangeParticipation { participationButton }
            case .needsPairing:
                Button("Open my check-in") { Task { await store.prepareConnection() } }
                    .disabled(store.isBusy)
                Text("Your connection is opening. Refresh if it isn't ready yet.").font(.footnote)
            case .ready:
                NavigationLink("Check in with your connection") { LiveCheckInView(store: store) }
            case .unavailable:
                Text("There aren't enough available teammates for a connection this game.")
            }
        }
    }
    private var participationButton: some View {
        Button(store.isOptedOut ? "Join this connection" : "Sit out this connection") {
            Task { await store.setParticipation(isOptedOut: !store.isOptedOut) }
        }
        .disabled(store.isBusy || !store.canChangeParticipation)
        .accessibilityHint(
            "Change your participation before connections open. Your choice is private.")
    }
}
#Preview { List { LiveConnectionSection(store: LiveTeamStore(service: PreviewLiveService())) } }
