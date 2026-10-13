// UnavailablePhotoService.swift
// Purpose: Prevent previews or unconfigured modes from reporting a real photo upload.
import Foundation

@MainActor
struct UnavailablePhotoService: PhotoServicing {
    func save(assignmentID: UUID, photoID: UUID, data: Data) async throws {
        throw BackendError.configuration
    }
    func download(photo: LivePhoto) async throws -> Data { throw BackendError.configuration }
    func remove(photo: LivePhoto) async throws { throw BackendError.configuration }
}
