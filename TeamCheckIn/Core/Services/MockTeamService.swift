// MockTeamService.swift
// Purpose: Validate local demo operations without network or real accounts.
import Foundation

/// A configurable service for previews, prototype flows, and failure tests.
@MainActor
final class MockTeamService: TeamServicing {
    var shouldFail = false

    func join(invite: String) async throws -> String {
        guard invite.trimmingCharacters(in: .whitespacesAndNewlines) == "teamcheckin://join/demo"
        else {
            throw PrototypeError.invalidInvite
        }
        return "Delaware Athletics"
    }

    func save(feeling: Feeling?, support: SupportPreference?, note: String, game: Game, now: Date)
        async throws
    {
        guard game.isOpen(at: now) else { throw PrototypeError.closedWindow }
        guard feeling != nil, support != nil else { throw PrototypeError.missingSelection }
        guard note.count <= 280 else { throw PrototypeError.noteTooLong }
        if shouldFail { throw PrototypeError.unavailable }
    }

    func saveGame(_ game: Game, isCaptain: Bool, now: Date) async throws {
        guard isCaptain else { throw PrototypeError.notCaptain }
        guard !game.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            game.startsAt > now
        else { throw PrototypeError.invalidGame }
        if shouldFail { throw PrototypeError.unavailable }
    }
}
