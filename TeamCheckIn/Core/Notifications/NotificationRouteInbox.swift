// NotificationRouteInbox.swift
// Purpose: Retain an event notification tap until the configured account UI can receive it.
import Foundation
import Observation

/// Contains identifiers only, never private response text or notification credentials.
@MainActor @Observable
final class NotificationRouteInbox {
    private(set) var gameID: UUID?
    /// Rejects missing or malformed event identifiers from external notification payloads.
    func receive(gameID: String?) {
        guard case .game(let id) = AppRoute.notification(gameID: gameID) else { return }
        self.gameID = id
    }
    /// Clears only the consumed event so a newer tap cannot be discarded by an older task.
    func consume(_ id: UUID) {
        if gameID == id { gameID = nil }
    }
}
