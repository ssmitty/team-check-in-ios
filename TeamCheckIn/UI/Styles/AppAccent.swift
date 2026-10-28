// AppAccent.swift
// Purpose: Keep the working teal action color readable in light and dark appearances.
import SwiftUI

/// Semantic action tint with sufficient contrast against standard system surfaces.
@MainActor
enum AppAccent {
    static let color = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: 0.39, green: 0.85, blue: 0.80, alpha: 1)
            } else {
                UIColor(red: 0, green: 0.43, blue: 0.47, alpha: 1)
            }
        })
}
