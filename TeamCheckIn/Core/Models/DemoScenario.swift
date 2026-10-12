// DemoScenario.swift
// Purpose: Expose reproducible demo states without changing real team data.
import Foundation

/// States a reviewer can exercise without accounts or remote services.
enum DemoScenario: String, CaseIterable, Identifiable, Sendable {
    case ready = "Paired check-in"
    case waiting = "Waiting for teammate"
    case trio = "Group of three"
    case empty = "No upcoming game"
    case closed = "Window closed"
    case insufficient = "Not enough players"
    case failure = "Save failure"
    var id: String { rawValue }
}
