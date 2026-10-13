// PhotoDraftPreview.swift
// Purpose: Preview and upload the selected draft while retaining it on network failure.
import PhotosUI
import SwiftUI

/// Explicit optional upload actions independent of the feeling/support submission.
struct PhotoDraftPreview: View {
    @Bindable var store: LiveTeamStore
    @Bindable var draft: PhotoDraftStore
    @Binding var selection: PhotosPickerItem?
    var body: some View {
        if let data = draft.data, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                .accessibilityLabel("Your selected pregame photo")
            if draft.isSaved {
                Label("Photo uploaded privately", systemImage: "checkmark.circle")
            } else {
                Button("Upload photo") {
                    Task {
                        if let id = store.assignmentID { await draft.save(assignmentID: id) }
                        if draft.isSaved { await store.refresh() }
                    }
                }.disabled(draft.isBusy || !store.isConnectionOpen)
            }
            Button("Discard selected photo") {
                draft.clear(); selection = nil
            }
            .disabled(draft.isBusy)
        }
    }
}
#Preview {
    PhotoDraftPreview(
        store: LiveTeamStore(service: PreviewLiveService()),
        draft: PhotoDraftStore(service: UnavailablePhotoService()), selection: .constant(nil))
}
