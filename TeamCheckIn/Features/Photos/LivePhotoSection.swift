// LivePhotoSection.swift
// Purpose: Offer optional library/camera photos with explicit upload, retry, and removal states.
import AVFoundation
import PhotosUI
import SwiftUI

/// Sharing a feeling never depends on photo upload or camera permission.
struct LivePhotoSection: View {
    @Bindable var store: LiveTeamStore
    @State private var draft: PhotoDraftStore
    @State private var selection: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var isRemoving = false
    init(store: LiveTeamStore) {
        self.store = store
        _draft = State(initialValue: PhotoDraftStore(service: store.photos))
    }
    private var existing: LivePhoto? {
        store.snapshot.photos.first {
            $0.assignment_id == store.assignmentID && $0.user_id == store.userID
        }
    }
    var body: some View {
        Section("Photo (optional)") {
            if draft.data != nil {
                PhotoDraftPreview(store: store, draft: draft, selection: $selection)
            } else if let existing, existing.is_ready {
                RemotePhotoView(photo: existing, service: store.photos)
            }
            PhotosPicker("Choose photo", selection: $selection, matching: .images)
                .disabled(draft.isBusy || isRemoving || !store.isConnectionOpen)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take photo") { Task { await openCamera() } }
                    .disabled(draft.isBusy || isRemoving || !store.isConnectionOpen)
            }
            if let existing {
                Button("Remove uploaded photo", role: .destructive) {
                    Task {
                        isRemoving = true
                        defer { isRemoving = false }
                        do {
                            try await store.photos.remove(photo: existing)
                            draft.clear(); selection = nil
                            await store.refresh()
                        } catch { draft.errorMessage = "Couldn't remove the photo. Try again." }
                    }
                }.disabled(draft.isBusy || isRemoving)
            }
            if draft.isBusy || isRemoving { ProgressView("Updating photo") }
            if let error = draft.errorMessage { Text(error).foregroundStyle(.red) }
            Text(
                "Your connection sees the photo after you share your check-in. You can check in without a photo."
            )
            .font(.footnote).foregroundStyle(.secondary)
        }
        .task(id: selection) {
            guard let selection, let assignmentID = store.assignmentID else { return }
            do {
                guard let bytes = try await selection.loadTransferable(type: Data.self),
                    bytes.count <= 20_000_000, let image = UIImage(data: bytes)
                else {
                    throw BackendError.invalidResponse
                }
                try Task.checkCancellation()
                guard store.assignmentID == assignmentID, store.isConnectionOpen else { return }
                draft.select(try PhotoProcessor.prepare(image))
            } catch is CancellationError { return } catch {
                draft.errorMessage =
                    "Couldn't prepare that photo. Choose another or continue without it."
            }
        }
        .onChange(of: store.assignmentID) {
            draft.clear(); selection = nil; showsCamera = false
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraCaptureView { image in
                showsCamera = false
                if let image {
                    do { draft.select(try PhotoProcessor.prepare(image)) } catch {
                        draft.errorMessage = "Couldn't prepare the photo. Try again."
                    }
                }
            }.ignoresSafeArea()
        }
    }
    private func openCamera() async {
        let assignmentID = store.assignmentID
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        guard assignmentID == store.assignmentID, store.isConnectionOpen else { return }
        if allowed {
            showsCamera = true
        } else {
            draft.errorMessage =
                "Camera access is off. Choose a library photo or continue without one."
        }
    }
}
#Preview { Form { LivePhotoSection(store: LiveTeamStore(service: PreviewLiveService())) } }
