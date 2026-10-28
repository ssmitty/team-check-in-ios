// TeamServicing.swift
// Purpose: Define the boundary between screen state and team operations.
import Foundation

/// Service operations for the session-only prototype.
@MainActor
protocol TeamServicing {
    /// Validates an invitation and returns the team's name, or throws.
    func join(invite: String) async throws -> String
    /// Saves a response if it is valid and the game's window is open.
    func save(feeling: Feeling?, support: SupportPreference?, note: String, game: Game, now: Date)
        async throws
    /// Validates a captain's future game before schedule persistence.
    func saveGame(_ game: Game, isCaptain: Bool, now: Date) async throws
}
