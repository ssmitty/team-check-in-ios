// TeamView.swift
// Purpose: Present the sample roster and captain-only schedule controls.
import SwiftUI

/// Team details without private mood or completion reporting.
struct TeamView: View {
    @Bindable var store: TeamStore
    @State private var editingGame: Game?
    @State private var cancelingGame: Game?
    var body: some View {
        List {
            TitledSection("Roster") {
                Text("You" + (store.isCaptain ? " (captain demo)" : ""))
                Text("Jordan")
                Text("Alex")
            }
            TitledSection("Schedule") {
                ForEach(store.games) { game in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(game.title).font(.headline)
                        Text(game.startsAt, format: .dateTime.weekday().hour().minute().timeZone())
                        if game.isCanceled {
                            Text("Canceled").foregroundStyle(.secondary)
                        } else if store.isCaptain {
                            HStack {
                                Button {
                                    editingGame = game
                                } label: {
                                    Text("Edit").frame(minHeight: 44).contentShape(Rectangle())
                                }
                                Button(role: .destructive) {
                                    cancelingGame = game
                                } label: {
                                    Text("Cancel").frame(minHeight: 44).contentShape(Rectangle())
                                }
                            }.buttonStyle(.bordered)
                        }
                    }
                }
                if store.isCaptain {
                    Button("Add game") {
                        editingGame = Game(
                            id: UUID(), title: "", startsAt: .now.addingTimeInterval(7200),
                            location: "", timeZoneIdentifier: TimeZone.current.identifier)
                    }
                    ShareLink(item: "teamcheckin://join/demo") {
                        Label("Share sample invite", systemImage: "square.and.arrow.up")
                    }
                }
            }
            TitledSection("Prototype controls") {
                Toggle("Captain demo", isOn: $store.isCaptain)
                Button("Leave demo team", role: .destructive) { store.leave() }
                Text("Captain controls manage the schedule, not private teammate responses.").font(
                    .footnote)
            }
        }
        .navigationTitle("Team")
        .sheet(item: $editingGame) { GameEditorView(store: store, game: $0) }
        .confirmationDialog(
            "Cancel this game?",
            isPresented: Binding(
                get: { cancelingGame != nil }, set: { if !$0 { cancelingGame = nil } }
            ), presenting: cancelingGame
        ) { game in
            Button("Cancel game", role: .destructive) {
                store.cancelGame(id: game.id)
                cancelingGame = nil
            }
        }
    }
}
#Preview { TeamView(store: TeamStore()) }
