// AppRoute.swift
// Purpose: Validate external invitation and game routes before account-scoped navigation.
import Foundation

/// External identifiers are hints only. Backend access must be checked before navigation.
enum AppRoute: Equatable, Sendable {
    case invite(String)
    case game(UUID)

    /// Accepts only the app scheme with an exact route shape and no extra components.
    static func parse(_ url: URL) -> AppRoute? {
        guard url.scheme == "teamcheckin", url.user == nil, url.password == nil,
            url.port == nil, url.query == nil, url.fragment == nil,
            url.pathComponents.count == 2
        else { return nil }
        switch url.host {
        case "join":
            guard let token = try? InviteToken.parse(url.absoluteString) else { return nil }
            return .invite(token)
        case "game":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            return .game(id)
        default: return nil
        }
    }

    /// Ignores all notification content except the validated event identifier.
    static func notification(gameID: String?) -> AppRoute? {
        guard let gameID, let id = UUID(uuidString: gameID) else { return nil }
        return .game(id)
    }
}
