// LiveModels.swift
// Purpose: Decode only the team and assignment records the current account may read.
import Foundation

/// Membership and its server-owned captain role.
struct LiveMembership: Decodable, Identifiable, Sendable {
    let team_id: UUID
    let user_id: UUID
    let display_name: String
    let role: String
    var id: UUID { user_id }
}
struct LiveTeam: Decodable, Identifiable, Sendable { let id: UUID; let name: String }
struct LiveGame: Codable, Identifiable, Sendable {
    let id: UUID
    let team_id: UUID
    var title: String
    var starts_at: String
    var location: String
    var time_zone_identifier: String
    var is_canceled: Bool
    let assignments_generated_at: String?
    var start: Date? {
        ISO8601DateFormatter().date(from: starts_at)
            ?? ISO8601DateFormatter.fractional.date(from: starts_at)
    }
}
struct LiveAssignmentMember: Decodable, Sendable {
    let assignment_id: UUID
    let game_id: UUID
    let user_id: UUID
}
struct LiveCheckIn: Decodable, Sendable {
    let assignment_id: UUID
    let user_id: UUID
    let feeling: Feeling
    let support: SupportPreference
    let note: String
}
struct LiveEncouragement: Decodable, Sendable {
    let assignment_id: UUID
    let sender_id: UUID
    let recipient_id: UUID
    let message: String
}
/// Records obtained through caller-scoped RLS, never a captain-wide response feed.
struct LiveSnapshot: Sendable {
    var teams: [LiveTeam] = []
    var roster: [LiveMembership] = []
    var games: [LiveGame] = []
    var connections: [LiveAssignmentMember] = []
    var responses: [LiveCheckIn] = []
    var encouragements: [LiveEncouragement] = []
}
private extension ISO8601DateFormatter {
    static var fractional: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
