// AccountSettingsView.swift
// Purpose: Offer explicit captain transfer and password-confirmed account deletion.
import SwiftUI

/// Account cleanup remains accessible even after an interrupted deletion removes team membership.
struct AccountSettingsView: View {
    @Bindable var store: LiveTeamStore
    @State private var recipientID: UUID?
    @State private var password = ""
    @State private var confirmsDeletion = false
    var body: some View {
        NavigationStack {
            Form {
                if store.isCaptain {
                    Section("Captain duties") {
                        Picker("Next captain", selection: $recipientID) {
                            Text("Choose a teammate").tag(Optional<UUID>.none)
                            ForEach(store.snapshot.roster.filter { $0.user_id != store.userID }) {
                                teammate in
                                Text(teammate.display_name).tag(Optional(teammate.user_id))
                            }
                        }
                        Button("Transfer captain duties") {
                            if let recipientID {
                                Task { await store.transferCaptain(recipientID: recipientID) }
                            }
                        }.disabled(recipientID == nil || store.isBusy)
                        Text(
                            "Transfer your role before deleting an account that manages a team with other players."
                        )
                        .font(.footnote)
                    }
                }
                Section("Delete account") {
                    Text(
                        "This permanently removes your account, responses, photos, and device registrations. Your teammates keep their own responses. Cleanup may need a retry if the connection fails."
                    )
                    .font(.footnote)
                    SecureField("Current password", text: $password).textContentType(.password)
                    Button("Delete my account", role: .destructive) { confirmsDeletion = true }
                        .disabled(password.isEmpty || store.isBusy || store.userID == nil)
                }
            }
            .navigationTitle("Account settings")
            .confirmationDialog(
                "Permanently delete your account?", isPresented: $confirmsDeletion,
                titleVisibility: .visible
            ) {
                Button("Delete account", role: .destructive) {
                    let confirmationPassword = password; password = ""
                    Task { await store.deleteAccount(password: confirmationPassword) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onDisappear { password = "" }
        }
    }
}
#Preview { AccountSettingsView(store: LiveTeamStore(service: PreviewLiveService())) }
