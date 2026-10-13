// LiveWarmupSection.swift
// Purpose: Show private warmup requests and individual acknowledgments for the current connection.
import SwiftUI

/// Small persistent actions that invite a conversation without sharing location.
struct LiveWarmupSection: View {
    @Bindable var store: LiveTeamStore
    private var requests: [LiveWarmupRequest] {
        store.snapshot.warmupRequests.filter { $0.assignment_id == store.assignmentID }
    }
    private var acknowledgments: [LiveWarmupAcknowledgment] {
        store.snapshot.warmupAcknowledgments.filter { $0.assignment_id == store.assignmentID }
    }
    var body: some View {
        Section("Find each other at warmups") {
            if requests.contains(where: { $0.requester_id == store.userID }) {
                Label("Your warmup request is sent", systemImage: "person.wave.2")
                ForEach(store.partners) { partner in
                    let acknowledged = acknowledgments.contains {
                        $0.requester_id == store.userID && $0.recipient_id == partner.user_id
                    }
                    Text(
                        partner.display_name
                            + (acknowledged ? " will find you." : " hasn't acknowledged yet."))
                }
            } else {
                Button("Find me at warmups") { Task { await store.requestWarmup() } }
                    .disabled(store.isBusy || !store.isConnectionOpen)
            }
            ForEach(requests.filter { $0.requester_id != store.userID }, id: \.requester_id) {
                request in
                let name =
                    store.partners.first { $0.user_id == request.requester_id }?.display_name
                    ?? "Your teammate"
                let acknowledged = acknowledgments.contains {
                    $0.requester_id == request.requester_id && $0.recipient_id == store.userID
                }
                Text(name + " would like you to find them at warmups.")
                if acknowledged {
                    Label("You said: I'll find you", systemImage: "checkmark.circle")
                } else {
                    Button("I'll find you") {
                        Task { await store.acknowledgeWarmup(requesterID: request.requester_id) }
                    }
                    .accessibilityLabel("Tell \(name): I'll find you at warmups")
                    .disabled(store.isBusy || !store.isConnectionOpen)
                }
            }
            Text("Meet at the warmup area. No location tracking.").font(.footnote).foregroundStyle(
                .secondary)
        }
    }
}
#Preview { Form { LiveWarmupSection(store: LiveTeamStore(service: PreviewLiveService())) } }
