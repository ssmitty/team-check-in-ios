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
    var deletionCompletes = false
    var onGameLookup: (() async -> Void)?
    func restore() async throws {}
    func authenticate(email: String, password: String, create: Bool) async throws -> Bool { true }
    func signOut() async throws { userID = nil }
    func deleteAccount(password: String) async throws {
        guard deletionCompletes else { throw BackendError.deletionPending }
        userID = nil
    }
    func transferCaptain(teamID: UUID, recipientID: UUID) async throws {}
    func load(teamID: UUID?) async throws -> LiveSnapshot { snapshot }
    func teamID(forGame gameID: UUID) async throws -> UUID? {
        if let onGameLookup { await onGameLookup() }
        return snapshot.games.first { $0.id == gameID }?.team_id
    }
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
    func requestWarmup(assignmentID: UUID) async throws {}
    func acknowledgeWarmup(assignmentID: UUID, requesterID: UUID) async throws {}
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
    @Test func routeWaitsForSignInThenOpensRequestedGame() async {
        let service = ScriptedLiveService(); service.prepare()
        let userID = service.userID
        let target = service.snapshot.games[0]
        service.userID = nil
        let store = LiveTeamStore(service: service)
        await store.receive(.game(target.id))
        #expect(store.pendingGameID == target.id)
        #expect(!store.showsRoutedGame)
        service.userID = userID
        await store.restore()
        #expect(store.game?.id == target.id)
        #expect(store.pendingGameID == nil)
        #expect(store.showsRoutedGame)
    }
    @Test func outsiderAndCanceledRoutesNeverOpenAnotherEvent() async {
        let service = ScriptedLiveService(); service.prepare()
        let store = LiveTeamStore(service: service); await store.restore()
        await store.receive(.game(UUID()))
        #expect(!store.showsRoutedGame)
        #expect(store.infoMessage?.contains("unavailable") == true)
        service.snapshot.games[0].is_canceled = true
        await store.receive(.game(service.snapshot.games[0].id))
        #expect(!store.showsRoutedGame)
        #expect(store.selectedGameID == nil)
    }
    @Test func routingToAnotherAssignmentClearsPrivateDraft() async {
        let service = ScriptedLiveService(); service.prepare()
        let store = LiveTeamStore(service: service); await store.restore()
        store.note = "Earlier private draft"
        let earlier = service.snapshot.games[0]
        service.prepare()
        let target = service.snapshot.games[0]
        service.snapshot.games.insert(earlier, at: 0)
        await store.receive(.game(target.id))
        #expect(store.game?.id == target.id)
        #expect(store.note.isEmpty)
        await store.signOut()
        #expect(store.selectedGameID == nil)
        #expect(!store.showsRoutedGame)
    }

    @Test func latestTapWinsWhenLookupIsAlreadyInFlight() async {
        let service = ScriptedLiveService(); service.prepare()
        let first = service.snapshot.games[0]
        service.prepare()
        let second = service.snapshot.games[0]
        service.snapshot.games.insert(first, at: 0)
        let store = LiveTeamStore(service: service); await store.restore()
        service.onGameLookup = {
            service.onGameLookup = nil
            await store.receive(.game(second.id))
        }
        await store.receive(.game(first.id))
        #expect(store.game?.id == second.id)
        #expect(store.pendingGameID == nil)
        #expect(store.showsRoutedGame)
    }
    @Test func expiredNotificationDoesNotOpenNextGame() async {
        let service = ScriptedLiveService(); service.prepare()
        let target = service.snapshot.games[0]
        let store = LiveTeamStore(service: service, now: { Date.now.addingTimeInterval(7200) })
        await store.restore()
        await store.receive(.game(target.id))
        #expect(!store.showsRoutedGame)
        #expect(store.selectedGameID == nil)
        #expect(store.infoMessage?.contains("ended") == true)
    }

    @Test func failedDeviceRevokeDoesNotPreventLocalSignOut() async {
        let service = ScriptedLiveService(); service.prepare()
        let deviceService = ScriptedNotificationService(); deviceService.failRevoke = true
        let notifications = NotificationRegistrationStore(
            service: deviceService, installationID: UUID())
        let store = LiveTeamStore(service: service, notifications: notifications)
        await store.restore()
        store.note = "Private draft"
        await store.signOut()
        #expect(store.userID == nil)
        #expect(store.note.isEmpty)
        #expect(store.errorMessage?.contains("Signed out locally") == true)
        #expect(deviceService.systemStops == 1)
    }

    @Test func unfinishedDeletionKeepsAccountAvailableForRetry() async {
        let service = ScriptedLiveService(); service.prepare()
        let store = LiveTeamStore(service: service); await store.restore()
        await store.deleteAccount(password: "fixture")
        #expect(store.userID != nil)
        #expect(store.infoMessage == nil)
        #expect(store.errorMessage?.contains("retry") == true)
    }
    @Test func confirmedDeletionClearsAccountDraftAndSystemAlerts() async {
        let service = ScriptedLiveService(); service.prepare(); service.deletionCompletes = true
        let device = ScriptedNotificationService()
        let notifications = NotificationRegistrationStore(service: device, installationID: UUID())
        let store = LiveTeamStore(service: service, notifications: notifications);
        await store.restore()
        store.note = "Private draft"
        await store.deleteAccount(password: "fixture")
        #expect(store.userID == nil)
        #expect(store.note.isEmpty)
        #expect(store.snapshot.responses.isEmpty)
        #expect(device.systemStops == 1)
        #expect(store.infoMessage == "Your account has been deleted.")
    }

}
