// SupportPreference.swift
// Purpose: Define small ways a teammate can help before a game.
import Foundation

/// The kind of connection requested by a player.
enum SupportPreference: String, CaseIterable, Codable, Sendable, Identifiable {
    case encouragement = "Encouragement"
    case conversation = "A quick conversation"
    case distraction = "A distraction"
    case presence = "Just knowing you're there"
    var id: String { rawValue }
}
