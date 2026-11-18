// AccountActionStyle.swift
// Purpose: Keep account actions readable and their full labeled frame tappable.
import SwiftUI

/// Avoids the default disabled-label fade that failed the account contrast audit.
struct AccountActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        // Custom styling must keep empty space inside the expanded label interactive.
        configuration.label
            .contentShape(Rectangle())
            .foregroundStyle(isEnabled ? AppAccent.color : Color(uiColor: .label))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
