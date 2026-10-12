// TodayView.swift
// Purpose: Show the next game and the available private check-in action.
import SwiftUI

/// Main destination for pregame connection and reproducible demo states.
struct TodayView: View {
    @Bindable var store: TeamStore
    var body: some View {
        List {
            Section {
                Text("A little connection before the game.").font(.title2).bold()
                Text("You don't have to go into it alone.").foregroundStyle(.secondary)
            }
            if let game = store.game {
                Section("Next game") {
                    Text(game.title).font(.headline)
                    Text(game.startsAt, format: .dateTime.weekday().hour().minute().timeZone())
                    Label(game.location, systemImage: "mappin.and.ellipse")
                }
                Section("Your teammate connection") { checkInContent(game: game) }
            } else {
                ContentUnavailableView(
                    "No game scheduled yet", systemImage: "calendar",
                    description: Text("Your captain can add the next game from Team."))
            }
            Section("Prototype controls") {
                Picker(
                    "Demo scenario",
                    selection: Binding(get: { store.scenario }, set: { store.loadScenario($0) })
                ) {
                    ForEach(DemoScenario.allCases) { Text($0.rawValue).tag($0) }
                }
                Text("These controls change sample data only.").font(.footnote).foregroundStyle(
                    .secondary)
            }
        }
        .navigationTitle(store.teamName ?? "Today")
        .onAppear { store.refreshCurrentGame() }
    }

    @ViewBuilder private func checkInContent(game: Game) -> some View {
        if store.isSkipped {
            Text("You skipped this check-in.")
        } else if store.teammates.isEmpty {
            Text("There aren't enough teammates for a check-in today.")
        } else {
            Text("You, " + store.teammates.map(\.name).joined(separator: " and "))
            if store.canCheckIn {
                NavigationLink(store.isShared ? "Edit your check-in" : "Start check-in") {
                    CheckInView(store: store)
                }
            } else {
                Text("Check-in is closed or hasn't opened yet.").foregroundStyle(.secondary)
            }
            NavigationLink("View teammate responses") { PartnerView(store: store) }
        }
    }
}
#Preview { TodayView(store: TeamStore()) }
