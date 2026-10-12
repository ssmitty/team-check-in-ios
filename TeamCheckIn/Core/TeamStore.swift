// TeamStore.swift
// Purpose: Coordinate the prototype's session state through injected services.
// Depends on: TeamServicing, Game, DemoScenario
import Foundation
import Observation

/// Main-actor presentation state for local team and check-in flows.
@MainActor @Observable
final class TeamStore {
    private(set) var teamName: String?
    private(set) var games: [Game] = []
    private(set) var teammates: [TeammateResponse] = []
    private(set) var isBusy = false
    private(set) var isShared = false
    private(set) var isSkipped = false
    private(set) var warmupRequested = false
    var isCaptain = false
    var feeling: Feeling?
    var support: SupportPreference?
    var note = ""
    var photoData: Data?
    var errorMessage: String?
    private(set) var scenario: DemoScenario = .ready
    private var draftGameID: UUID?
    private let service: any TeamServicing
    private let now: () -> Date

    /// Creates state with a replaceable service and clock for verification.
    init(service: any TeamServicing = MockTeamService(), now: @escaping () -> Date = Date.init) {
        self.service = service
        self.now = now
    }

    /// Selects the next active event; the closed demo deliberately retains its sample event.
    var game: Game? {
        games.first { !$0.isCanceled && $0.startsAt > now() }
            ?? (scenario == .closed ? games.first { !$0.isCanceled } : nil)
    }
    var canCheckIn: Bool {
        game?.id == draftGameID && game?.isOpen(at: now()) == true
            && !teammates.isEmpty && !isSkipped
    }

    /// Joins a validated demo invitation without discarding a failed draft.
    func join(invite: String) async {
        await perform {
            self.teamName = try await self.service.join(invite: invite)
            self.loadScenario(.ready)
        }
    }

    /// Creates a session-only team with captain controls.
    func createTeam(name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Enter a team name."
            return
        }
        teamName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        isCaptain = true
        loadScenario(.ready)
    }

    /// Replaces sample content with a reproducible scenario and clears private drafts.
    func loadScenario(_ value: DemoScenario) {
        scenario = value
        clearPrivateDraft()
        errorMessage = nil
        if let mock = service as? MockTeamService { mock.shouldFail = value == .failure }
        games =
            value == .empty
            ? []
            : [
                Game(
                    id: UUID(), title: "vs. Towson",
                    startsAt: now().addingTimeInterval(value == .closed ? -600 : 2400),
                    location: "Meet by the warmup area",
                    timeZoneIdentifier: TimeZone.current.identifier
                )
            ]
        teammates =
            value == .insufficient
            ? []
            : [
                TeammateResponse(
                    id: UUID(), name: "Jordan", feeling: value == .waiting ? nil : .nervous,
                    support: value == .waiting ? nil : .encouragement,
                    note: value == .waiting ? "" : "A little nervous, but excited to play together."
                )
            ]
        draftGameID = game?.id
        if value == .trio {
            teammates.append(
                TeammateResponse(
                    id: UUID(), name: "Alex", feeling: .energized,
                    support: .conversation, note: "Let's catch up before warmups."))
        }
    }

    /// Clears content when a schedule or clock change selects a different event.
    func refreshCurrentGame() {
        guard draftGameID != game?.id else { return }
        clearPrivateDraft()
        draftGameID = game?.id
    }

    /// Shares the draft only after the injected service confirms success.
    func share() async {
        guard let game, !isSkipped, !teammates.isEmpty else {
            errorMessage = "There isn't an available teammate check-in today."
            return
        }
        guard draftGameID == game.id else {
            refreshCurrentGame()
            errorMessage = "The next game changed. Start a fresh check-in for this game."
            return
        }
        await perform {
            try await self.service.save(
                feeling: self.feeling, support: self.support,
                note: self.note, game: game, now: self.now())
            self.isShared = true
        }
    }

    /// Marks this session's check-in as skipped without changing the assignment.
    func skip() {
        isSkipped = true
        isShared = false
        photoData = nil
    }

    /// Saves or replaces a validated game and maintains chronological ordering.
    func saveGame(_ game: Game) async {
        await perform {
            try await self.service.saveGame(game, isCaptain: self.isCaptain, now: self.now())
            if let index = self.games.firstIndex(where: { $0.id == game.id }) {
                self.games[index] = game
            } else {
                self.games.append(game)
            }
            self.games.sort { $0.startsAt < $1.startsAt }
            self.refreshCurrentGame()
        }
    }

    /// Cancels a captain's event while retaining its schedule entry.
    func cancelGame(id: UUID) {
        guard isCaptain, let index = games.firstIndex(where: { $0.id == id }) else { return }
        games[index].isCanceled = true
        refreshCurrentGame()
    }

    /// Adds encouragement to the selected sample teammate's response.
    func encourage(id: UUID, text: String) {
        guard canCheckIn, let index = teammates.firstIndex(where: { $0.id == id }) else { return }
        teammates[index].encouragement = text
    }

    /// Sends a session-only warmup request to the assignment.
    func requestWarmup() { if canCheckIn { warmupRequested = true } }

    /// Demonstrates each sample teammate's acknowledgment independently.
    func simulateAcknowledgment(id: UUID) {
        guard warmupRequested, let index = teammates.firstIndex(where: { $0.id == id }) else {
            return
        }
        teammates[index].hasAcknowledgedWarmup = true
    }

    /// Clears private session state on leaving the demo.
    func leave() {
        teamName = nil
        games = []
        teammates = []
        clearPrivateDraft()
        draftGameID = nil
        isCaptain = false
        errorMessage = nil
    }

    private func clearPrivateDraft() {
        feeling = nil
        support = nil
        note = ""
        photoData = nil
        isShared = false
        isSkipped = false
        warmupRequested = false
        for index in teammates.indices {
            teammates[index].encouragement = nil
            teammates[index].hasAcknowledgedWarmup = false
        }
    }

    private func perform(_ action: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do { try await action() } catch { errorMessage = error.localizedDescription }
    }
}
