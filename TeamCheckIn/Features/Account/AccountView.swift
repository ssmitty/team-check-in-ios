// AccountView.swift
// Purpose: Present email account entry with secure password input and confirmation feedback.
import SwiftUI

/// Minimal sign-in and account creation, without retaining passwords after success.
struct AccountView: View {
    @Bindable var store: LiveTeamStore
    @State private var email = ""
    @State private var password = ""
    @State private var createAccount = false
    @FocusState private var focusedField: Field?
    private enum Field { case email, password }
    private var canSubmit: Bool { !store.isBusy && !email.isEmpty && !password.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Go into the game together").font(.title).bold()
                        .accessibilityAddTraits(.isHeader)
                    Text("Sign in to join your team and share a private pregame check-in.")
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email").font(.body).foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            TextField("", text: $email).keyboardType(.emailAddress)
                                .accessibilityLabel("Email")
                                .textContentType(.emailAddress).textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email).submitLabel(.done)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password").font(.body).foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            SecureField("", text: $password)
                                .accessibilityLabel("Password")
                                .textContentType(createAccount ? .newPassword : .password)
                                .focused($focusedField, equals: .password).submitLabel(.done)
                        }
                        HStack(alignment: .top, spacing: 16) {
                            Text("Create a new account")
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Toggle("Create a new account", isOn: $createAccount)
                                .labelsHidden()
                                .accessibilityLabel("Create a new account")
                        }
                        Button {
                            Task {
                                await store.authenticate(
                                    email: email, password: password, create: createAccount)
                                if store.userID != nil { password = "" }
                            }
                        } label: {
                            Text(createAccount ? "Create account" : "Sign in")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(AccountActionStyle())
                        .disabled(!canSubmit)
                        .accessibilityHint(canSubmit ? "" : "Enter your email and password first.")
                    }
                } label: {
                    Text("Your account").font(.headline).accessibilityAddTraits(.isHeader)
                }
            }.textFieldStyle(.roundedBorder).padding()
        }.scrollDismissesKeyboard(.interactively).navigationTitle("Team Check-in")
            .onSubmit { focusedField = nil }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
    }
}
#Preview { NavigationStack { AccountView(store: LiveTeamStore(service: PreviewLiveService())) } }
