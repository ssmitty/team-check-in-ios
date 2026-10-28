// LivePhoto.swift
// Purpose: Represent private photo metadata without retaining a shareable URL.
import Foundation

/// The server-owned reservation for one author's assignment photo.
struct LivePhoto: Decodable, Sendable {
    let assignment_id: UUID
    let user_id: UUID
    let photo_id: UUID
    let is_ready: Bool
    var objectPath: String {
        [assignment_id, user_id, photo_id].map { $0.uuidString.lowercased() }.joined(separator: "/")
            + ".jpg"
    }
}
