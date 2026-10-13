// LiveNotificationSection.swift
// Purpose: Offer optional pregame permission beside the schedule without blocking participation.
import SwiftUI

struct LiveNotificationSection: View {
    @Bindable var notifications: NotificationRegistrationStore
    var body: some View {
        TitledSection("Pregame alerts") {
            Text(notifications.message).font(.footnote)
            Button("Enable alerts") { Task { await notifications.enable() } }
                .disabled(notifications.isBusy)
            if notifications.permission == .denied {
                Text("You can change alert permission in iPhone Settings.").font(.footnote)
            }
        }
    }
}
#Preview {
    List {
        LiveNotificationSection(
            notifications: NotificationRegistrationStore(
                service: PreviewNotificationService(), installationID: UUID()))
    }
}
