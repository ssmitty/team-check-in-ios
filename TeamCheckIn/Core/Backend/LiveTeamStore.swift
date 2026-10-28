// LiveTeamStore.swift
// Purpose: Coordinate account and persisted team state while preserving failed drafts.
import Foundation
import Observation

/// Live mode state with server-owned roles and assignment-scoped responses.
@MainActor @Observable
final class LiveTeamStore {
    private let service: any LiveTeamServicing
    private let now: () -> Date
    let photos: any PhotoServicing
    let notifications: NotificationRegistrationStore?
    private(set) var snapshot = LiveSnapshot()
    private(set) var userID: UUID?
    private(set) var isBusy = false
    private(set) var hasRestored = false
    var errorMessage: String?
    var infoMessage: String?
    private(set) var selectedGameID: UUID?
    private(set) var pendingGameID: UUID?
    var showsRoutedGame = false
    var selectedTeamID: UUID?
    var inviteLink: String?
    var pendingInvite = ""
    var feeling: Feeling?
    var support: SupportPreference?
    var note = ""
    var draftAssignmentID: UUID?
    private(set) var presentationTime: Date
    init(
        service: any LiveTeamServicing, photos: any PhotoServicing = UnavailablePhotoService(),
        notifications: NotificationRegistrationStore? = nil, now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.photos = photos
        self.notifications = notifications
        self.now = now
        self.presentationTime = now()
    }
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
    /// Keeps a game route through sign-in and validates membership during the next load.
    func receive(_ route: AppRoute) async {
        switch route {
        case .invite(let token): pendingInvite = token
        case .game(let id):
            pendingGameID = id
            if userID != nil { await refresh() }
        }
    }
    /// Returns the home screen to the next event without retaining another event's draft.
    func finishGameRoute() async {
        selectedGameID = nil
        await refresh()
    }
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
    func setParticipation(isOptedOut: Bool) async {
        refreshPresentation()
        guard canChangeParticipation, let game else {
            errorMessage = "Connections are already opening. You can still choose not to share."
            return
        }
        await perform {
            try await self.service.setParticipation(gameID: game.id, isOptedOut: isOptedOut)
            try await self.reload()
        }
    }
    func prepareConnection() async {
        guard let game else { return }
        await perform {
            try await self.service.generate(gameID: game.id); try await self.reload()
        }
    }
    func share() async {
        guard let writable = currentWritableAssignment() else { return }
        guard let assignmentID, assignmentID == writable, assignmentID == draftAssignmentID,
            let feeling, let support,
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
        guard let assignmentID = currentWritableAssignment() else { return }
        await perform {
            try await self.service.encourage(assignmentID: assignmentID, recipientID: recipientID);
            try await self.reload()
        }
    }
    func requestWarmup() async {
        guard let assignmentID = currentWritableAssignment() else { return }
        await perform {
            try await self.service.requestWarmup(assignmentID: assignmentID)
            try await self.reload()
        }
    }
    func acknowledgeWarmup(requesterID: UUID) async {
        guard let assignmentID = currentWritableAssignment() else { return }
        await perform {
            try await self.service.acknowledgeWarmup(
                assignmentID: assignmentID, requesterID: requesterID)
            try await self.reload()
        }
    }
    func transferCaptain(recipientID: UUID) async {
        guard let team else { return }
        await perform {
            try await self.service.transferCaptain(teamID: team.id, recipientID: recipientID)
            try await self.reload()
        }
    }
    /// Keeps retry available after partial cleanup and clears all local account state only on completion.
    func deleteAccount(password: String) async {
        await perform {
            do { try await self.service.deleteAccount(password: password) } catch {
                if self.service.userID == nil {
                    self.notifications?.clearDeletedAccount(); self.clear()
                } else {
                    try await self.reload()
                }
                throw error
            }
            self.notifications?.clearDeletedAccount()
            self.clear()
            self.infoMessage = "Your account has been deleted."
        }
    }
    func signOut() async {
        await perform {
            defer { self.clear() }
            let revoked = await self.notifications?.disconnect() ?? true
            try await self.service.signOut()
            if !revoked { throw BackendError.notificationRevoke }
        }
    }
    private func reload() async throws {
        snapshot = try await service.load(teamID: selectedTeamID)
        selectedTeamID = team?.id
        while pendingGameID != nil { try await resolveGameRoute() }
        refreshPresentation()
    }
    /// Advances visible time and clears drafts when the next connection changes, without networking.
    func refreshPresentation() {
        presentationTime = now()
        synchronizeDraft()
    }
    private func currentWritableAssignment() -> UUID? {
        let expected = assignmentID
        refreshPresentation()
        guard let expected, expected == assignmentID, isConnectionOpen else {
            errorMessage =
                "This connection has changed or closed. Return to the schedule and refresh."
            return nil
        }
        return expected
    }
    private func synchronizeDraft() {
        if draftAssignmentID != assignmentID {
            draftAssignmentID = assignmentID
            let own = snapshot.responses.first {
                $0.assignment_id == assignmentID && $0.user_id == userID
            }
            feeling = own?.feeling; support = own?.support; note = own?.note ?? ""
        }
    }
    private func resolveGameRoute() async throws {
        guard let id = pendingGameID else { return }
        let routedTeamID = try await service.teamID(forGame: id)
        guard pendingGameID == id else { return }
        guard let teamID = routedTeamID else {
            pendingGameID = nil
            infoMessage = "This game is unavailable for your account."
            return
        }
        let routed = try await service.load(teamID: teamID)
        guard pendingGameID == id else { return }
        guard let game = routed.games.first(where: { $0.id == id }), !game.is_canceled,
            let start = game.start, start > now()
        else {
            pendingGameID = nil
            infoMessage = "This game has ended or was canceled. Check your team's schedule."
            return
        }
        snapshot = routed
        selectedTeamID = teamID
        selectedGameID = id
        pendingGameID = nil
        showsRoutedGame = true
    }
    private func clear() {
        selectedGameID = nil; pendingGameID = nil; showsRoutedGame = false
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
