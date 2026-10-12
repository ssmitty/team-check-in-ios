// LiveTeamStore.swift
// Purpose: Coordinate account and persisted team state while preserving failed drafts.
import Foundation
import Observation

/// Live mode state with server-owned roles and assignment-scoped responses.
@MainActor @Observable
final class LiveTeamStore {
    private let service: any LiveTeamServicing
    private(set) var snapshot = LiveSnapshot()
    private(set) var userID: UUID?
    private(set) var isBusy = false
    private(set) var hasRestored = false
    var errorMessage: String?
    var infoMessage: String?
    var selectedTeamID: UUID?
    var inviteLink: String?
    var pendingInvite = ""
    var feeling: Feeling?
    var support: SupportPreference?
    var note = ""
    var draftAssignmentID: UUID?
    var team: LiveTeam? {
        snapshot.teams.first(where: { $0.id == selectedTeamID }) ?? snapshot.teams.first
    }
    var isCaptain: Bool {
        snapshot.roster.contains { $0.user_id == userID && $0.role == "captain" }
    }
    var game: LiveGame? {
        snapshot.games.first { !$0.is_canceled && ($0.start ?? .distantPast) > .now }
    }
    var assignmentID: UUID? {
        snapshot.connections.first { $0.game_id == game?.id && $0.user_id == userID }?.assignment_id
    }
    var partners: [LiveMembership] {
        let ids = snapshot.connections.filter {
            $0.assignment_id == assignmentID && $0.user_id != userID
        }.map(\.user_id)
        return snapshot.roster.filter { ids.contains($0.user_id) }
    }

    init(service: any LiveTeamServicing) { self.service = service }
    func restore() async {
        await perform {
            try await self.service.restore()
            self.userID = self.service.userID
            if self.userID != nil { try await self.reload() }
        }
        hasRestored = true
    }
    func authenticate(email: String, password: String, create: Bool) async {
        await perform {
            let signedIn = try await self.service.authenticate(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password,
                create: create)
            self.userID = self.service.userID
            if signedIn {
                try await self.reload()
            } else {
                self.infoMessage = "Check your email to confirm your account, then sign in."
            }
        }
    }
    func refresh() async { await perform { try await self.reload() } }
    func create(name: String, displayName: String) async {
        await perform {
            try await self.service.create(name: name, displayName: displayName);
            try await self.reload()
        }
    }
    func join(displayName: String) async {
        await perform {
            let token = try InviteToken.parse(self.pendingInvite)
            try await self.service.join(token: token, displayName: displayName)
            self.pendingInvite = ""
            try await self.reload()
        }
    }
    func createInvite() async {
        guard let team else { return }
        await perform { self.inviteLink = try await self.service.invite(teamID: team.id) }
    }
    func save(game: LiveGame) async {
        await perform {
            try await self.service.save(game: game); try await self.reload()
        }
    }
    func prepareConnection() async {
        guard let game else { return }
        await perform {
            try await self.service.generate(gameID: game.id); try await self.reload()
        }
    }
    func share() async {
        guard let assignmentID, assignmentID == draftAssignmentID, let feeling, let support,
            note.count <= 280
        else {
            errorMessage =
                "Choose your feeling and support, with a note under 281 characters. Refresh if the game changed."
            return
        }
        await perform {
            try await self.service.share(
                assignmentID: assignmentID, feeling: feeling, support: support, note: self.note)
            self.infoMessage = "Your check-in is shared with this connection."
            try await self.reload()
        }
    }
    func encourage(recipientID: UUID) async {
        guard let assignmentID else { return }
        await perform {
            try await self.service.encourage(assignmentID: assignmentID, recipientID: recipientID);
            try await self.reload()
        }
    }
    func signOut() async {
        await perform {
            defer { self.clear() }
            try await self.service.signOut()
        }
    }
    private func reload() async throws {
        snapshot = try await service.load(teamID: selectedTeamID)
        selectedTeamID = team?.id
        if draftAssignmentID != assignmentID {
            draftAssignmentID = assignmentID
            let own = snapshot.responses.first {
                $0.assignment_id == assignmentID && $0.user_id == userID
            }
            feeling = own?.feeling; support = own?.support; note = own?.note ?? ""
        }
    }
    private func clear() {
        userID = nil; snapshot = LiveSnapshot(); selectedTeamID = nil; inviteLink = nil
        feeling = nil; support = nil; note = ""; draftAssignmentID = nil; infoMessage = nil
    }
    private func perform(_ action: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true; errorMessage = nil; infoMessage = nil
        defer { isBusy = false }
        do { try await action() } catch { errorMessage = error.localizedDescription }
    }
}
