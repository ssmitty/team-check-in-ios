// LiveTeamStore+Connection.swift
// Purpose: Derive caller-only connection and participation states from the observable presentation clock.
import Foundation

extension LiveTeamStore {
    var team: LiveTeam? {
        snapshot.teams.first(where: { $0.id == selectedTeamID }) ?? snapshot.teams.first
    }
    var isCaptain: Bool {
        snapshot.roster.contains { $0.user_id == userID && $0.role == "captain" }
    }
    var game: LiveGame? {
        if let selectedGameID {
            return snapshot.games.first { $0.id == selectedGameID && !$0.is_canceled }
        }
        return snapshot.games.first {
            !$0.is_canceled && ($0.start ?? .distantPast) > presentationTime
        }
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

    var isGameUpcoming: Bool {
        guard let game, let start = game.start else { return false }
        return !game.is_canceled && start > presentationTime
    }
    var isGameWindowOpen: Bool {
        guard isGameUpcoming, let start = game?.start else { return false }
        return presentationTime >= start.addingTimeInterval(-3600)
    }
    var isConnectionOpen: Bool {
        guard let start = game?.start, assignmentID != nil else { return false }
        return presentationTime >= start.addingTimeInterval(-3600) && presentationTime < start
    }
    var isOptedOut: Bool {
        snapshot.optOuts.contains { $0.game_id == game?.id && $0.user_id == userID }
    }
    var canChangeParticipation: Bool {
        guard let game, let start = game.start, !game.is_canceled else { return false }
        return game.assignments_generated_at == nil
            && presentationTime < start.addingTimeInterval(-3600)
    }
    var connectionState: LiveConnectionState {
        guard let game else { return .noGame }
        guard isGameUpcoming else { return .closed }
        if isOptedOut { return .skipped }
        if !isGameWindowOpen { return .waiting }
        if assignmentID != nil { return .ready }
        return game.assignments_generated_at == nil ? .needsPairing : .unavailable
    }
}
