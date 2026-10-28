// TeamCheckInApp.swift
// Purpose: Wire the configured live account or local demo state into SwiftUI.
import SwiftUI

/// Entry point for the native teammate app.
@main
struct TeamCheckInApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup {
            entryView.tint(AppAccent.color)
                #if DEBUG
                    .preferredColorScheme(
                        ProcessInfo.processInfo.arguments.contains("--dark-ui-test")
                            ? .dark
                            : (ProcessInfo.processInfo.arguments.contains("--light-ui-test")
                                ? .light : nil))
                #endif
        }
    }

    @ViewBuilder private var entryView: some View {
        let entry = AppEntryView(routes: delegate.routes, registration: delegate.registration)
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--large-text-ui-test") {
                entry.dynamicTypeSize(.accessibility5)
            } else {
                entry
            }
        #else
            entry
        #endif
    }
}
