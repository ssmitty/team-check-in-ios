// LiveConnectionState.swift
// Purpose: Describe private connection availability without exposing other players' participation.

/// The server still authorizes every mutation; this state controls truthful presentation.
enum LiveConnectionState: Sendable {
    case noGame, waiting, skipped, needsPairing, ready, unavailable, closed
}
