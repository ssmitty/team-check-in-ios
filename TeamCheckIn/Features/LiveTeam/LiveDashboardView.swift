// LiveDashboardView.swift
// Purpose: Show the shared schedule, current connection, and server-owned captain actions.
import SwiftUI

/// A simple live team home with explicit refresh and no private roster reporting.
struct LiveDashboardView: View {
    @Bindable var store: LiveTeamStore
    @State private var editing: LiveGame?
    var body: some View {
        List {
            TitledSection("Your next game") {
                if let game = store.game {
                    Text(game.title).font(.headline)
                    if let start = game.start {
                        Text(start, format: .dateTime.weekday().hour().minute())
                    }
                    Text(game.location)

                } else {
                    Text("No upcoming game scheduled.")
                }
            }
            LiveConnectionSection(store: store)
            if store.game != nil, let notifications = store.notifications {
                LiveNotificationSection(notifications: notifications)
            }
            TitledSection("Schedule") {
                ForEach(store.snapshot.games) { game in
                    VStack(alignment: .leading) {
                        Text(game.title)
                        if let start = game.start {
                            Text(start, format: .dateTime.month().day().hour().minute())
                        }
                        if game.is_canceled {
                            Text("Canceled").foregroundStyle(.secondary)
                        } else if store.isCaptain {
                            Button("Edit game") { editing = game }
                        }
                    }
                }
                if store.isCaptain, let team = store.team {
                    Button("Add game") {
                        editing = LiveGame(
                            id: UUID(), team_id: team.id, title: "",
                            starts_at: ISO8601DateFormatter().string(
                                from: .now.addingTimeInterval(7200)),
                            location: "", time_zone_identifier: TimeZone.current.identifier,
                            is_canceled: false, assignments_generated_at: nil)
                    }
                    Button("Create invite link") { Task { await store.createInvite() } }
                    if let invite = store.inviteLink {
                        ShareLink("Share team invite", item: invite)
                    }
                }
            }
            TitledSection("Roster") {
                ForEach(store.snapshot.roster) { member in
                    Text(member.display_name + (member.role == "captain" ? " (captain)" : ""))
                }
                Text("Captain access covers the schedule. Check-ins stay within each connection.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button("Sign out", role: .destructive) { Task { await store.signOut() } }
        }
        .disabled(store.isBusy)
        .navigationTitle(store.team?.name ?? "Team")
        .refreshable { await store.refresh() }
        .toolbar {
            Button("Refresh", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
        }
        .sheet(item: $editing) { LiveGameEditorView(store: store, game: $0) }
    }
}
#Preview {
    NavigationStack { LiveDashboardView(store: LiveTeamStore(service: PreviewLiveService())) }
}
