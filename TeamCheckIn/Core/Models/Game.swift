// Game.swift
// Purpose: Represent a scheduled game and its pregame submission window.
import Foundation

/// A team event with an absolute start time and scheduling time zone.
struct Game: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var startsAt: Date
    var location: String
    var timeZoneIdentifier: String
    var isCanceled = false

    var opensAt: Date { startsAt.addingTimeInterval(-3600) }

    /// Returns whether a submission can be received at the supplied time.
    func isOpen(at date: Date) -> Bool {
        !isCanceled && date >= opensAt && date < startsAt
    }
}
