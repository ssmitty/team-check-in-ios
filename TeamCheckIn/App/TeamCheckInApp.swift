// TeamCheckInApp.swift
// Purpose: Wire the configured live account or local demo state into SwiftUI.
import SwiftUI

/// Entry point for the native teammate app.
@main
struct TeamCheckInApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup {
            AppEntryView(routes: delegate.routes, registration: delegate.registration)
                .tint(.teal)
        }
    }
}
