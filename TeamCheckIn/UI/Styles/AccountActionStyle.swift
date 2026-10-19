// AccountActionStyle.swift
// Purpose: Keep disabled account action text readable while preserving disabled interaction semantics.
import SwiftUI

/// Avoids the default disabled-label fade that failed the account contrast audit.
struct AccountActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? AppAccent.color : Color(uiColor: .label))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
