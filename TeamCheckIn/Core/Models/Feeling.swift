// Feeling.swift
// Purpose: Define the choices a player can share before a game.
import Foundation

/// A player's self-reported feeling, with no score or diagnosis.
enum Feeling: String, CaseIterable, Codable, Sendable, Identifiable {
    case calm = "Calm"
    case energized = "Energized"
    case nervous = "Nervous"
    case lowEnergy = "Low energy"
    case toughDay = "Having a tough day"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .calm: "leaf"
        case .energized: "bolt"
        case .nervous: "waveform.path"
        case .lowEnergy: "moon"
        case .toughDay: "cloud"
        }
    }
}
