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
    @Test func earlierGameClearsDraftPhotoAndConnectionActions() async throws {
        let store = TeamStore(now: { date })
        store.createTeam(name: "Test team")
        store.feeling = .nervous
        store.support = .encouragement
        store.note = "Private draft for first game"
        store.photoData = Data([1, 2, 3])
        await store.share()
        store.requestWarmup()
        let partner = try #require(store.teammates.first)
        store.encourage(id: partner.id, text: "I've got you")
        store.simulateAcknowledgment(id: partner.id)
        let earlier = Game(
            id: UUID(), title: "Earlier game", startsAt: date.addingTimeInterval(600),
            location: "Warmups", timeZoneIdentifier: "UTC")
        await store.saveGame(earlier)
        #expect(store.game?.id == earlier.id)
        #expect(store.feeling == nil && store.support == nil && store.note.isEmpty)
        #expect(store.photoData == nil && !store.isShared && !store.warmupRequested)
        #expect(store.teammates.allSatisfy { $0.encouragement == nil && !$0.hasAcknowledgedWarmup })
    }

    @Test func cancellationDoesNotCarrySkippedStateIntoNextGame() async throws {
        let store = TeamStore(now: { date })
        store.createTeam(name: "Test team")
        let first = try #require(store.game)
        let later = Game(
            id: UUID(), title: "Later game", startsAt: date.addingTimeInterval(3000),
            location: "Warmups", timeZoneIdentifier: "UTC")
        await store.saveGame(later)
        store.skip()
        store.cancelGame(id: first.id)
        #expect(store.game?.id == later.id)
        #expect(!store.isSkipped)
        #expect(store.canCheckIn)
    }

    @Test func clockChangeCannotSubmitPreviousGamesDraft() async throws {
        var clock = date
        let store = TeamStore(now: { clock })
        store.createTeam(name: "Test team")
        let later = Game(
            id: UUID(), title: "Later game", startsAt: date.addingTimeInterval(5000),
            location: "Warmups", timeZoneIdentifier: "UTC")
        await store.saveGame(later)
        store.feeling = .calm
        store.support = .conversation
        store.note = "Old draft"
        clock = date.addingTimeInterval(2400)
        #expect(store.game?.id == later.id)
        #expect(!store.canCheckIn)
        await store.share()
        #expect(!store.isShared && store.note.isEmpty)
        #expect(store.errorMessage != nil)
        #expect(store.canCheckIn)
    }

}
