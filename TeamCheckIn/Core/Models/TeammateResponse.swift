// TeammateResponse.swift
// Purpose: Hold demo responses and warmup acknowledgments for an assignment.
import Foundation

/// A response visible within the supplied demo assignment.
struct TeammateResponse: Identifiable, Sendable {
    let id: UUID
    let name: String
    var feeling: Feeling?
    var support: SupportPreference?
    var note: String
    var hasAcknowledgedWarmup = false
    var encouragement: String?
}
