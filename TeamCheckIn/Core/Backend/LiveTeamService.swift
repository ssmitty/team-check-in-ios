// LiveTeamService.swift
// Purpose: Translate account-scoped team operations to protected backend endpoints.
import Foundation

/// Persistence boundary used by the live presentation state.
@MainActor
protocol LiveTeamServicing {
    var userID: UUID? { get }
    func restore() async throws
    func authenticate(email: String, password: String, create: Bool) async throws -> Bool
    func signOut() async throws
    func load(teamID: UUID?) async throws -> LiveSnapshot
    func teamID(forGame gameID: UUID) async throws -> UUID?
    func create(name: String, displayName: String) async throws
    func join(token: String, displayName: String) async throws
    func invite(teamID: UUID) async throws -> String
    func save(game: LiveGame) async throws
    func generate(gameID: UUID) async throws
    func share(assignmentID: UUID, feeling: Feeling, support: SupportPreference, note: String)
        async throws
    func encourage(assignmentID: UUID, recipientID: UUID) async throws
    func requestWarmup(assignmentID: UUID) async throws
    func acknowledgeWarmup(assignmentID: UUID, requesterID: UUID) async throws
}

/// Uses one shared authenticated client; all authorization remains on the server.
@MainActor
struct LiveTeamService: LiveTeamServicing {
    let client: BackendClient
    var userID: UUID? { client.userID }
    func restore() async throws { try await client.restore() }
    func authenticate(email: String, password: String, create: Bool) async throws -> Bool {
        try await client.authenticate(email: email, password: password, create: create)
    }
    func signOut() async throws { try await client.signOut() }
    func load(teamID: UUID?) async throws -> LiveSnapshot {
        let teams: [LiveTeam] = try await read("teams?select=id,name")
        guard let team = teams.first(where: { $0.id == teamID }) ?? teams.first else {
            return LiveSnapshot()
        }
        var value = LiveSnapshot(teams: teams)
        value.roster = try await read(
            "team_members?select=team_id,user_id,display_name,role&team_id=eq.\(team.id)")
        value.games = try await read(
            "games?select=*&team_id=eq.\(team.id)&order=starts_at.asc&limit=100")
        value.connections = try await read(
            "assignment_members?select=assignment_id,game_id,user_id")
        value.responses = try await read(
            "check_ins?select=assignment_id,user_id,feeling,support,note")
        value.encouragements = try await read(
            "encouragements?select=assignment_id,sender_id,recipient_id,message")
        value.warmupRequests = try await read("warmup_requests?select=assignment_id,requester_id")
        value.warmupAcknowledgments = try await read(
            "warmup_acknowledgments?select=assignment_id,requester_id,recipient_id")
        value.photos = try await read(
            "check_in_photos?select=assignment_id,user_id,photo_id,is_ready")
        return value
    }
    /// Finds a route's team through the caller's RLS-scoped game read.
    func teamID(forGame gameID: UUID) async throws -> UUID? {
        let games: [LiveGame] = try await read("games?select=*&id=eq.\(gameID)&limit=1")
        return games.first?.team_id
    }
    func create(name: String, displayName: String) async throws {
        _ = try await rpc("create_team", ["p_name": name, "p_display_name": displayName])
    }
    func join(token: String, displayName: String) async throws {
        _ = try await rpc("redeem_invite", ["p_token": token, "p_display_name": displayName])
    }
    func invite(teamID: UUID) async throws -> String {
        let data = try await rpc("create_invite", ["p_team": teamID.uuidString])
        let token = try JSONDecoder().decode(String.self, from: data)
        return "teamcheckin://join/" + token
    }
    func save(game: LiveGame) async throws {
        struct Payload: Encodable {
            let p_id: UUID; let p_team: UUID; let p_title: String; let p_starts_at: String
            let p_location: String; let p_time_zone_identifier: String; let p_is_canceled: Bool
        }
        _ = try await rpc(
            "save_game",
            Payload(
                p_id: game.id, p_team: game.team_id, p_title: game.title,
                p_starts_at: game.starts_at, p_location: game.location,
                p_time_zone_identifier: game.time_zone_identifier, p_is_canceled: game.is_canceled))
    }
    func generate(gameID: UUID) async throws {
        _ = try await client.request(
            "functions/v1/generate-pairings", method: "POST",
            body: JSONEncoder().encode(["game_id": gameID.uuidString]))
    }
    func share(assignmentID: UUID, feeling: Feeling, support: SupportPreference, note: String)
        async throws
    {
        _ = try await rpc(
            "submit_check_in",
            [
                "p_assignment": assignmentID.uuidString,
                "p_feeling": feeling.rawValue, "p_support": support.rawValue, "p_note": note,
            ])
    }
    func encourage(assignmentID: UUID, recipientID: UUID) async throws {
        _ = try await rpc(
            "send_encouragement",
            [
                "p_assignment": assignmentID.uuidString,
                "p_recipient": recipientID.uuidString, "p_message": "I've got you",
            ])
    }
    func requestWarmup(assignmentID: UUID) async throws {
        _ = try await rpc("request_warmup", ["p_assignment": assignmentID.uuidString])
    }
    func acknowledgeWarmup(assignmentID: UUID, requesterID: UUID) async throws {
        _ = try await rpc(
            "acknowledge_warmup",
            [
                "p_assignment": assignmentID.uuidString,
                "p_requester": requesterID.uuidString,
            ])
    }
    private func rpc<T: Encodable>(_ name: String, _ payload: T) async throws -> Data {
        try await client.request(
            "rest/v1/rpc/" + name, method: "POST", body: JSONEncoder().encode(payload))
    }
    private func read<T: Decodable>(_ path: String) async throws -> T {
        try JSONDecoder().decode(T.self, from: await client.request("rest/v1/" + path))
    }
}
