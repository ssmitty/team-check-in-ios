// PrototypeError.swift
// Purpose: Describe recoverable prototype validation and service failures.
import Foundation

/// Errors that can be shown without exposing internal service details.
enum PrototypeError: LocalizedError {
    case invalidInvite, missingSelection, noteTooLong, closedWindow, notCaptain, invalidGame,
        unavailable

    var errorDescription: String? {
        switch self {
        case .invalidInvite: "This invite is no longer available. Ask your captain for a new link."
        case .missingSelection: "Choose a feeling and the kind of support you'd like."
        case .noteTooLong: "Keep your note to 280 characters or fewer."
        case .closedWindow: "This game's check-in window has closed."
        case .notCaptain: "Only your captain can change the schedule."
        case .invalidGame: "Add an opponent and a future start time."
        case .unavailable:
            "The demo service couldn't save. Your draft is still here. Try another demo scenario."
        }
    }
}
