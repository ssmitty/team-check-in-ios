// HighContrastActionStyle.swift
// Purpose: Give welcome actions an opaque, high-contrast surface in both appearances.
import SwiftUI

/// Preserves readable text and a full-width touch target without inherited tint or materials.
struct HighContrastActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white, lineWidth: configuration.isPressed ? 2 : 0)
            }
    }
}
