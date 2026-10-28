// PhotoDraftStore.swift
// Purpose: Preserve an optional photo draft across failed uploads and clear it on assignment changes.
import Foundation
import Observation

/// Photo progress belongs to one assignment and never replaces a failed draft with success.
@MainActor @Observable
final class PhotoDraftStore {
    private let service: any PhotoServicing
    private(set) var data: Data?
    private(set) var photoID = UUID()
    private(set) var isBusy = false
    private(set) var isSaved = false
    var errorMessage: String?
    init(service: any PhotoServicing) { self.service = service }
    func select(_ data: Data) {
        guard !data.isEmpty, data.count <= 5_000_000 else {
            errorMessage = "Choose a photo smaller than 5 MB."
            return
        }
        self.data = data
        photoID = UUID()
        isSaved = false
        errorMessage = nil
    }
    func save(assignmentID: UUID) async {
        guard let data, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        let id = photoID
        do {
            try await service.save(assignmentID: assignmentID, photoID: id, data: data)
            if photoID == id { isSaved = true }
        } catch {
            errorMessage =
                "Couldn't upload your photo. Keep your draft and try again, or share without it."
        }
    }
    func clear() {
        data = nil
        photoID = UUID()
        isSaved = false
        errorMessage = nil
    }
}
