// TeamCheckInApp.swift
// Purpose: Wire the configured live account or local demo state into SwiftUI.
import SwiftUI

/// Entry point for the native teammate app.
@main
struct TeamCheckInApp: App {
    var body: some Scene {
        WindowGroup {
            AppEntryView()
                .tint(.teal)
        }
    }
}
