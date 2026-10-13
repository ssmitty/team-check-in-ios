// PhotoDraftStoreTests.swift
// Purpose: Verify recoverable uploads, stable retry identifiers, and private draft cleanup.
import Foundation
import Testing
@testable import TeamCheckInCore

@MainActor
private final class ScriptedPhotoService: PhotoServicing {
    var fails = true
    var identifiers: [UUID] = []
    func save(assignmentID: UUID, photoID: UUID, data: Data) async throws {
        identifiers.append(photoID)
        if fails { throw BackendError.rejected(503) }
    }
    func download(photo: LivePhoto) async throws -> Data { Data() }
    func remove(photo: LivePhoto) async throws {}
}
@MainActor
struct PhotoDraftStoreTests {
    @Test func failedUploadPreservesBytesAndRetryUsesSameObjectIdentifier() async {
        let service = ScriptedPhotoService()
        let store = PhotoDraftStore(service: service)
        let bytes = Data([1, 2, 3])
        store.select(bytes)
        let id = store.photoID
        let assignment = UUID()
        await store.save(assignmentID: assignment)
        #expect(store.data == bytes && !store.isSaved && store.errorMessage != nil)
        service.fails = false
        await store.save(assignmentID: assignment)
        #expect(store.isSaved && store.errorMessage == nil && !store.isBusy)
        #expect(service.identifiers == [id, id])
    }
    @Test func oversizedSelectionKeepsExistingDraft() {
        let store = PhotoDraftStore(service: ScriptedPhotoService())
        store.select(Data([1]))
        let id = store.photoID
        store.select(Data(repeating: 0, count: 5_000_001))
        #expect(store.data == Data([1]) && store.photoID == id)
        #expect(store.errorMessage != nil)
    }
    @Test func assignmentCleanupRemovesPrivateBytesAndChangesIdentifier() {
        let store = PhotoDraftStore(service: ScriptedPhotoService())
        store.select(Data([1, 2, 3]))
        let id = store.photoID
        store.clear()
        #expect(store.data == nil && !store.isSaved && store.errorMessage == nil)
        #expect(store.photoID != id)
    }
}
