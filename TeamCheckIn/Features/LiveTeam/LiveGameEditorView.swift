// LiveGameEditorView.swift
// Purpose: Edit persisted games while respecting the server's assignment freeze.
import SwiftUI

/// Server checks captain authority independently of this editor's visibility.
struct LiveGameEditorView: View {
    @Bindable var store: LiveTeamStore
    let game: LiveGame
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var location = ""
    @State private var start = Date.now
    @State private var confirmingCancel = false
    var body: some View {
        NavigationStack {
            Form {
                TextField("Opponent or game title", text: $title)
                TextField("Meetup area", text: $location)
                DatePicker("Game starts", selection: $start, in: Date.now...)
                if game.assignments_generated_at != nil {
                    Text(
                        "This game's connections are already assigned. You can cancel it; create a new game to reschedule."
                    )
                } else {
                    Button("Save game") { Task { await save(canceled: false) } }
                        .disabled(
                            store.isBusy || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Button("Cancel game", role: .destructive) { confirmingCancel = true }
                    .disabled(store.isBusy)
            }
            .navigationTitle("Game")
            .toolbar { Button("Close") { dismiss() } }
            .onAppear {
                title = game.title; location = game.location; start = game.start ?? .now
            }
            .confirmationDialog("Cancel this game?", isPresented: $confirmingCancel) {
                Button("Cancel game", role: .destructive) { Task { await save(canceled: true) } }
            }
        }
    }
    private func save(canceled: Bool) async {
        var changed = game
        changed.title = title; changed.location = location
        changed.starts_at = ISO8601DateFormatter().string(from: start)
        changed.is_canceled = canceled
        await store.save(game: changed)
        if store.errorMessage == nil { dismiss() }
    }
}
#Preview {
    LiveGameEditorView(
        store: LiveTeamStore(service: PreviewLiveService()),
        game: LiveGame(
            id: UUID(), team_id: UUID(), title: "vs. Towson", starts_at: "2026-10-20T19:00:00Z",
            location: "Warmups", time_zone_identifier: "America/New_York", is_canceled: false,
            assignments_generated_at: nil))
}
