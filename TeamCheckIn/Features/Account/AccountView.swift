// AccountView.swift
// Purpose: Present email account entry with secure password input and confirmation feedback.
import SwiftUI

/// Minimal sign-in and account creation, without storing credentials in view state after success.
struct AccountView: View {
    @Bindable var store: LiveTeamStore
    @State private var email = ""
    @State private var password = ""
    @State private var createAccount = false
    var body: some View {
        Form {
            Section {
                Text("Go into the game together").font(.title).bold()
                Text("Sign in to join your team and share a private pregame check-in.")
            }
            TitledSection("Your account") {
                TextField("Email", text: $email).keyboardType(.emailAddress)
                    .textContentType(.emailAddress).textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(createAccount ? .newPassword : .password)
                Toggle("Create a new account", isOn: $createAccount)
                Button(createAccount ? "Create account" : "Sign in") {
                    Task {
                        await store.authenticate(
                            email: email, password: password, create: createAccount)
                        if store.userID != nil { password = "" }
                    }
                }.disabled(store.isBusy || email.isEmpty || password.isEmpty)
            }
        }.navigationTitle("Team Check-in")
    }
}
#Preview { NavigationStack { AccountView(store: LiveTeamStore(service: PreviewLiveService())) } }
