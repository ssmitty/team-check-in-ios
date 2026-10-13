// LiveCheckInView.swift
// Purpose: Share a persisted private response and read only assigned teammate responses.
import SwiftUI

/// A pair/trio connection screen backed by caller-scoped database access.
struct LiveCheckInView: View {
    @Bindable var store: LiveTeamStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section("How are you feeling?") {
                Picker("Feeling", selection: $store.feeling) {
                    Text("Choose a feeling").tag(Optional<Feeling>.none)
                    ForEach(Feeling.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }
                Picker("What would help?", selection: $store.support) {
                    Text("Choose support").tag(Optional<SupportPreference>.none)
                    ForEach(SupportPreference.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }
                TextField("Brief note (optional)", text: $store.note, axis: .vertical).lineLimit(
                    3...6)
                Text("\(store.note.count) / 280 characters").font(.footnote)
                Button("Share check-in") { Task { await store.share() } }
                    .disabled(
                        store.isBusy || store.feeling == nil || store.support == nil
                            || store.note.count > 280)
                Button("Not now") { dismiss() }
                Text("Only your assigned connection can read this. Sharing is optional.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            LivePhotoSection(store: store)
            ForEach(store.partners) { partner in
                Section(partner.display_name) {
                    if let response = store.snapshot.responses.first(where: {
                        $0.assignment_id == store.assignmentID && $0.user_id == partner.user_id
                    }) {
                        Label(response.feeling.rawValue, systemImage: response.feeling.symbol)
                        Text("Would appreciate: " + response.support.rawValue)
                        if !response.note.isEmpty { Text(response.note) }
                        if let photo = store.snapshot.photos.first(where: {
                            $0.assignment_id == store.assignmentID && $0.user_id == partner.user_id
                                && $0.is_ready
                        }) {
                            RemotePhotoView(photo: photo, service: store.photos)
                        }
                    } else {
                        Text("Hasn't checked in yet.").foregroundStyle(.secondary)
                    }
                    Button("I've got you") {
                        Task { await store.encourage(recipientID: partner.user_id) }
                    }
                    .disabled(store.isBusy)
                }
            }
            Section("Encouragement") {
                ForEach(
                    Array(
                        store.snapshot.encouragements.filter {
                            $0.assignment_id == store.assignmentID
                        }.enumerated()), id: \.offset
                ) {
                    _, message in
                    Text(message.message)
                }
            }
            LiveWarmupSection(store: store)
        }.navigationTitle("Your connection")
            .refreshable { await store.refresh() }
    }
}
#Preview { LiveCheckInView(store: LiveTeamStore(service: PreviewLiveService())) }
