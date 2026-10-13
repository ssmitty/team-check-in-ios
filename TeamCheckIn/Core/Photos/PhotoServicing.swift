// PhotoServicing.swift
// Purpose: Separate private photo upload and retrieval from presentation state.
import Foundation

/// A retryable photo service whose caller identity comes from its account session.
@MainActor
protocol PhotoServicing {
    func save(assignmentID: UUID, photoID: UUID, data: Data) async throws
    func download(photo: LivePhoto) async throws -> Data
    func remove(photo: LivePhoto) async throws
}
