// PrivatePhotoService.swift
// Purpose: Reserve, upload, and publish private images through account-scoped APIs.
import Foundation

/// Uploads immutable object paths and checks existing bytes before confirming a retried upload.
@MainActor
struct PrivatePhotoService: PhotoServicing {
    let client: BackendClient
    func save(assignmentID: UUID, photoID: UUID, data: Data) async throws {
        guard !data.isEmpty, data.count <= 5_000_000 else { throw BackendError.invalidResponse }
        let payload = ["p_assignment": assignmentID.uuidString, "p_photo": photoID.uuidString]
        let response = try await rpc("prepare_photo", payload)
        let path = try JSONDecoder().decode(String.self, from: response)
        do {
            _ = try await client.request(
                "storage/v1/object/check-in-photos/" + path,
                method: "POST", body: data, contentType: "image/jpeg")
        } catch BackendError.rejected(let status) where status == 400 || status == 409 {
            let existing = try await client.request(
                "storage/v1/object/authenticated/check-in-photos/" + path)
            guard existing == data else { throw BackendError.invalidResponse }
        }
        _ = try await rpc("publish_photo", payload)
    }
    func download(photo: LivePhoto) async throws -> Data {
        try await client.request(
            "storage/v1/object/authenticated/check-in-photos/" + photo.objectPath)
    }
    func remove(photo: LivePhoto) async throws {
        // Delete the object while its metadata still permits the author's read access.
        _ = try await client.request(
            "storage/v1/object/check-in-photos", method: "DELETE",
            body: JSONEncoder().encode(["prefixes": [photo.objectPath]]))
        _ = try await rpc("remove_photo", ["p_assignment": photo.assignment_id.uuidString])
    }
    private func rpc(_ name: String, _ body: [String: String]) async throws -> Data {
        try await client.request(
            "rest/v1/rpc/" + name, method: "POST", body: JSONEncoder().encode(body))
    }
}
