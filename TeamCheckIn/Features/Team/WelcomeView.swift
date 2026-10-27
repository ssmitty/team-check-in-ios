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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "person.2.circle.fill").font(.system(size: 52))
                            .foregroundStyle(.teal)
                            .accessibilityHidden(true)
                        Text("Go into the game together").font(.title).bold()
                            .accessibilityAddTraits(.isHeader)
                        Text("A small check-in with a teammate before you play.").foregroundStyle(
                            .primary)
                    }
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Invitation link", text: $invite, axis: .vertical)
                                .lineLimit(1...4)
                                .textInputAutocapitalization(
                                    .never
                                )
                                .autocorrectionDisabled()
                            Text("Demo team: Delaware Athletics").font(.body)
                                .foregroundStyle(Color(uiColor: .label))
                            Button {
                                Task { await store.join(invite: invite) }
                            } label: {
                                Text("Join demo team").frame(
                                    maxWidth: .infinity, minHeight: 44, alignment: .leading
                                )
                                .contentShape(Rectangle())
                            }
                            .disabled(store.isBusy)
                            .buttonStyle(.plain)
                            .foregroundStyle(Color(uiColor: .label))
                        }
                    } label: {
                        Text("Join a sample team").font(.headline).accessibilityAddTraits(.isHeader)
                    }
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Team name", text: $name, axis: .vertical).lineLimit(1...3)
                            Button {
                                store.createTeam(name: name)
                            } label: {
                                Text("Create demo team").frame(
                                    maxWidth: .infinity, minHeight: 44, alignment: .leading
                                ).contentShape(Rectangle())
                            }.buttonStyle(.plain).foregroundStyle(Color(uiColor: .label))
                        }
                    } label: {
                        Text("Create a team as captain").font(.headline).accessibilityAddTraits(
                            .isHeader)
                    }
                    if store.isBusy { ProgressView("Joining team") }
                }.textFieldStyle(.roundedBorder).padding()
            }
            .navigationTitle("Team Check-in")
        }
    }
}
#Preview { WelcomeView(store: TeamStore()) }
