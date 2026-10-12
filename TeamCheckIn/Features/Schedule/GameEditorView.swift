// GameEditorView.swift
// Purpose: Edit a future demo game with captain authorization and validation.
import SwiftUI

/// Schedule editing with explicit save and recoverable errors.
struct GameEditorView: View {
    @Bindable var store: TeamStore
    @State var game: Game
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                TextField("Opponent or game title", text: $game.title)
                DatePicker("Start time", selection: $game.startsAt)
                TextField("Meeting location (optional)", text: $game.location)
                Text("Time zone: " + game.timeZoneIdentifier).font(.footnote)
                Text("Check-in opens one hour before this game.").foregroundStyle(.secondary)
                if let message = store.errorMessage { Text(message).foregroundStyle(.red) }
            }
            .navigationTitle("Game details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await store.saveGame(game)
                            if store.errorMessage == nil { dismiss() }
                        }
                    }.disabled(store.isBusy)
                }
            }
        }
    }
}
#Preview {
    GameEditorView(
        store: TeamStore(),
        game: Game(
            id: UUID(), title: "vs. Towson",
            startsAt: .now.addingTimeInterval(3600), location: "Warmup area",
            timeZoneIdentifier: "America/New_York"))
}
