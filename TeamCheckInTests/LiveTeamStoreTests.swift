// LiveTeamStoreTests.swift
// Purpose: Keep private drafts scoped to one assignment and preserve failed submissions.
import Foundation
import Testing
@testable import TeamCheckInCore

@MainActor
private final class ScriptedLiveService: LiveTeamServicing {
    var userID: UUID? = UUID()
    var snapshot = LiveSnapshot()
    var failSave = false
    func restore() async throws {}
    func authenticate(email: String, password: String, create: Bool) async throws -> Bool { true }
    func signOut() async throws { userID = nil }
    func load(teamID: UUID?) async throws -> LiveSnapshot { snapshot }
    func create(name: String, displayName: String) async throws {}
    func join(token: String, displayName: String) async throws {}
    func invite(teamID: UUID) async throws -> String { "" }
    func save(game: LiveGame) async throws {}
    func generate(gameID: UUID) async throws {}
    func share(assignmentID: UUID, feeling: Feeling, support: SupportPreference, note: String)
        async throws
    {
        if failSave { throw BackendError.rejected(503) }
    }
    func encourage(assignmentID: UUID, recipientID: UUID) async throws {}
    func prepare() {
        let team = LiveTeam(id: UUID(), name: "Test team")
        let game = LiveGame(
            id: UUID(), team_id: team.id, title: "Game",
            starts_at: ISO8601DateFormatter().string(from: .now.addingTimeInterval(2400)),
            location: "Warmups", time_zone_identifier: "America/New_York",
            is_canceled: false, assignments_generated_at: "2026-10-12T00:00:00Z")
        snapshot = LiveSnapshot(
            teams: [team], games: [game],
            connections: [
                LiveAssignmentMember(assignment_id: UUID(), game_id: game.id, user_id: userID!)
            ])
    }
}
@MainActor
struct LiveTeamStoreTests {
    @Test func failedSubmissionPreservesDraftWithoutSuccessMessage() async {
        let service = ScriptedLiveService(); service.prepare(); service.failSave = true
        let store = LiveTeamStore(service: service)
        await store.restore()
        store.feeling = .nervous; store.support = .encouragement; store.note = "Draft"
        await store.share()
        #expect(store.note == "Draft")
        #expect(store.errorMessage != nil)
        #expect(store.infoMessage == nil)
        #expect(!store.isBusy)
    }
    @Test func newAssignmentClearsPreviousPrivateDraft() async {
        let service = ScriptedLiveService(); service.prepare()
        let store = LiveTeamStore(service: service); await store.restore()
        store.feeling = .nervous; store.support = .encouragement; store.note = "Old private draft"
        service.prepare()
        await store.refresh()
        #expect(store.note.isEmpty)
        #expect(store.feeling == nil)
        #expect(store.support == nil)
    }
    @Test func signOutClearsPrivateAccountState() async {
        let service = ScriptedLiveService(); service.prepare()
        let store = LiveTeamStore(service: service); await store.restore()
        store.note = "Private draft"
        await store.signOut()
        #expect(store.userID == nil)
        #expect(store.snapshot.responses.isEmpty)
        #expect(store.note.isEmpty)
        #expect(store.draftAssignmentID == nil)
    }
}
