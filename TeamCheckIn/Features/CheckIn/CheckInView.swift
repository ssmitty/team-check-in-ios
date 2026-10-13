// CheckInView.swift
// Purpose: Collect a feeling, support preference, optional note, and local photo.
import PhotosUI
import SwiftUI

/// A short private check-in form with recoverable service failures.
struct CheckInView: View {
    @Bindable var store: TeamStore
    @State private var photo: PhotosPickerItem?
    var body: some View {
        Form {
            TitledSection("How are you heading into today's game?") {
                ForEach(Feeling.allCases) { value in
                    Button {
                        store.feeling = value
                    } label: {
                        HStack {
                            Label(value.rawValue, systemImage: value.symbol)
                            Spacer()
                            if store.feeling == value { Image(systemName: "checkmark") }
                        }
                    }
                    .accessibilityLabel(value.rawValue)
                    .accessibilityIdentifier("feeling." + value.rawValue)
                    .accessibilityAddTraits(store.feeling == value ? .isSelected : [])
                }
            }
            TitledSection("What would help from your teammate?") {
                Picker("Support preference", selection: $store.support) {
                    Text("Choose support").tag(Optional<SupportPreference>.none)
                    ForEach(SupportPreference.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }.pickerStyle(.inline)
            }
            TitledSection("Anything you want them to know? (optional)") {
                TextField("A brief note", text: $store.note, axis: .vertical).lineLimit(3...6)
                Text("\(store.note.count) / 280 characters").font(.footnote)
                    .foregroundStyle(store.note.count > 280 ? .red : .secondary)
            }
            TitledSection("Pregame photo (optional)") {
                PhotoAttachmentView(store: store, selection: $photo)
            }
            Section {
                Text("Shared only with your teammate connection for this game.").font(.footnote)
                Button("Share check-in") { Task { await store.share() } }
                    .disabled(store.isBusy || !store.canCheckIn)
                if store.isBusy { ProgressView("Sharing") }
                if store.isShared {
                    Label("Check-in shared in demo", systemImage: "checkmark.circle")
                }
                NavigationLink("View teammate responses") { PartnerView(store: store) }
                Button("Skip check-in", role: .destructive) { store.skip() }
            }
        }
        .navigationTitle("Check-in")
        .task(id: photo) {
            guard let photo else { return }
            do {
                let data = try await photo.loadTransferable(type: Data.self)
                guard let data, data.count <= 5_000_000 else {
                    store.errorMessage = "Choose a photo smaller than 5 MB."
                    return
                }
                store.photoData = data
            } catch { store.errorMessage = "Couldn't load that photo. Your note is still here." }
        }
    }
}
#Preview { CheckInView(store: TeamStore()) }
