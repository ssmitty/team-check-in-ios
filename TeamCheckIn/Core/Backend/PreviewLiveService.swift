// PreviewLiveService.swift
// Purpose: Provide side-effect-free account service behavior for SwiftUI previews.
import Foundation

/// Preview-only dependency that never authenticates or writes real data.
@MainActor
struct PreviewLiveService: LiveTeamServicing {
    var userID: UUID? { nil }
    func restore() async throws {}
    func authenticate(email: String, password: String, create: Bool) async throws -> Bool { false }
    func signOut() async throws {}
    func load(teamID: UUID?) async throws -> LiveSnapshot { LiveSnapshot() }
    func create(name: String, displayName: String) async throws {}
    func join(token: String, displayName: String) async throws {}
    func invite(teamID: UUID) async throws -> String { "" }
    func save(game: LiveGame) async throws {}
    func generate(gameID: UUID) async throws {}
    func share(assignmentID: UUID, feeling: Feeling, support: SupportPreference, note: String)
        async throws
    {}
    func encourage(assignmentID: UUID, recipientID: UUID) async throws {}
}
