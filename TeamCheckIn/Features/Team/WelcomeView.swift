// WelcomeView.swift
// Purpose: Let reviewers create or join a clearly labeled sample team.
import SwiftUI

/// Entry form for the mock invitation and team creation flows.
struct WelcomeView: View {
    @Bindable var store: TeamStore
    @State private var invite = "teamcheckin://join/demo"
    @State private var name = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Image(systemName: "person.2.circle.fill").font(.system(size: 52))
                        .foregroundStyle(.teal)
                        .accessibilityHidden(true)
                    Text("Go into the game together").font(.title).bold()
                    Text("A small check-in with a teammate before you play.").foregroundStyle(
                        .primary)
                }
                TitledSection("Join a sample team") {
                    TextField("Invitation link", text: $invite).textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Demo team: Delaware Athletics").font(.footnote)
                    Button {
                        Task { await store.join(invite: invite) }
                    } label: {
                        Text("Join demo team").frame(
                            maxWidth: .infinity, minHeight: 44, alignment: .leading
                        )
                        .contentShape(Rectangle())
                    }
                    .disabled(store.isBusy)
                }
                TitledSection("Create a team as captain") {
                    TextField("Team name", text: $name)
                    Button("Create demo team") { store.createTeam(name: name) }
                }
                if store.isBusy { ProgressView("Joining team") }
            }
            .navigationTitle("Team Check-in")
        }
    }
}
#Preview { WelcomeView(store: TeamStore()) }
