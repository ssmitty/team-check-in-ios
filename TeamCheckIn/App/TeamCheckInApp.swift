// TeamCheckInApp.swift
// Purpose: Wire the session-only prototype's injected state into SwiftUI.
import SwiftUI

/// Entry point for the native demo app.
@main
struct TeamCheckInApp: App {
    @State private var store = TeamStore()
    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .tint(.teal)
                .onOpenURL { url in Task { await store.join(invite: url.absoluteString) } }
        }
    }
}
