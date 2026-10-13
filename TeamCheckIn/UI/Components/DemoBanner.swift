// DemoBanner.swift
// Purpose: Clearly distinguish sample interactions from real team sharing.
import SwiftUI

/// A persistent explanation of the prototype's session-only data.
struct DemoBanner: View {
    var body: some View {
        Label("Demo mode: changes stay in this session", systemImage: "info.circle")
            .font(.footnote).foregroundStyle(.primary)
            .padding(12).frame(maxWidth: .infinity)
            .background(.thinMaterial)
    }
}
#Preview { DemoBanner() }
