// TeamStoreTests.swift
// Purpose: Verify draft preservation, authorization, timing, and private session cleanup.
import Foundation
import Testing

@testable import TeamCheckInCore

/// Behavior tests for the injected service and clock.
@MainActor
struct TeamStoreTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func failedSavePreservesDraftAndDoesNotConfirmSharing() async {
        let store = TeamStore(now: { date })
        await store.join(invite: "teamcheckin://join/demo")
        store.loadScenario(.failure)
        store.feeling = .nervous
        store.support = .encouragement
        store.note = "Let's talk."
        await store.share()
        #expect(!store.isShared)
        #expect(store.note == "Let's talk.")
        #expect(store.errorMessage != nil)
        #expect(!store.isBusy)
    }

    @Test func memberCannotSaveCaptainSchedule() async {
        let store = TeamStore(now: { date })
        await store.join(invite: "teamcheckin://join/demo")
        let count = store.games.count
        await store.saveGame(
            Game(
                id: UUID(), title: "New game", startsAt: date.addingTimeInterval(7200),
                location: "", timeZoneIdentifier: "America/New_York"))
        #expect(store.games.count == count)
        #expect(store.errorMessage != nil)
    }

    @Test func invalidInvitationDoesNotJoinTeam() async {
        let store = TeamStore(now: { date })
        await store.join(invite: "teamcheckin://join/revoked")
        #expect(store.teamName == nil)
        #expect(store.errorMessage != nil)
    }

    @Test func submissionWindowExcludesStartTimeAndCanceledGames() {
        var game = Game(
            id: UUID(), title: "Game", startsAt: date, location: "", timeZoneIdentifier: "UTC")
        #expect(game.isOpen(at: date.addingTimeInterval(-3600)))
        #expect(!game.isOpen(at: date.addingTimeInterval(-3601)))
        #expect(!game.isOpen(at: date))
        game.isCanceled = true
        #expect(!game.isOpen(at: date.addingTimeInterval(-1800)))
    }

    @Test func trioAcknowledgmentDoesNotAcknowledgeBothPartners() async throws {
        let store = TeamStore(now: { date })
        await store.join(invite: "teamcheckin://join/demo")
        store.loadScenario(.trio)
        store.requestWarmup()
        let first = try #require(store.teammates.first)
        store.simulateAcknowledgment(id: first.id)
        #expect(store.teammates.filter(\.hasAcknowledgedWarmup).count == 1)
    }

    @Test func leavingClearsPrivateDraftAndPhoto() async {
        let store = TeamStore(now: { date })
        await store.join(invite: "teamcheckin://join/demo")
        store.note = "Private note"
        store.photoData = Data([1, 2, 3])
        store.leave()
        #expect(store.teamName == nil && store.note.isEmpty && store.photoData == nil)
        #expect(store.teammates.isEmpty)
    }
}
