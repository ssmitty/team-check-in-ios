// PartnerView.swift
// Purpose: Display supplied teammate responses and demonstrate warmup requests.
import SwiftUI

/// Private assignment content backed only by the session's mock state.
struct PartnerView: View {
    @Bindable var store: TeamStore
    var body: some View {
        List {
            ForEach(store.teammates) { teammate in
                TitledSection(teammate.name) {
                    if let feeling = teammate.feeling, let support = teammate.support {
                        Label(feeling.rawValue, systemImage: feeling.symbol).font(.headline)
                        Text("Would appreciate: " + support.rawValue)
                        Text(teammate.note)
                        Button("I've got you") {
                            store.encourage(id: teammate.id, text: "I've got you")
                        }
                        .disabled(!store.canCheckIn)
                        if let encouragement = teammate.encouragement {
                            Label(encouragement + " sent in demo", systemImage: "checkmark")
                        }
                    } else {
                        Text(teammate.name + " hasn't checked in yet.").foregroundStyle(.secondary)
                    }
                }
            }
            TitledSection("Connect in person") {
                if store.warmupRequested {
                    Label("Warmup request sent in demo", systemImage: "person.wave.2")
                    ForEach(store.teammates) { teammate in
                        Text(
                            teammate.name
                                + (teammate.hasAcknowledgedWarmup
                                    ? " will find you." : " hasn't acknowledged yet.")
                        )
                    }
                } else {
                    Button("Find me at warmups") { store.requestWarmup() }
                        .disabled(!store.canCheckIn)
                }
                Text("Meet at the warmup area. No location tracking.").font(.footnote)
                    .foregroundStyle(
                        .secondary)
            }
            if store.warmupRequested {
                TitledSection("Prototype controls") {
                    ForEach(store.teammates) { teammate in
                        Button("Simulate \(teammate.name): I'll find you") {
                            store.simulateAcknowledgment(id: teammate.id)
                        }
                        .disabled(teammate.hasAcknowledgedWarmup)
                    }
                }
            }
        }.navigationTitle("Your connection")
    }
}
#Preview { PartnerView(store: TeamStore()) }
