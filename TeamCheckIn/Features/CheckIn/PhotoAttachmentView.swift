// PhotoAttachmentView.swift
// Purpose: Preview a local demo image and allow optional selection or removal.
import PhotosUI
import SwiftUI

/// Photo selection for the prototype; no image is uploaded or persisted.
struct PhotoAttachmentView: View {
    @Bindable var store: TeamStore
    @Binding var selection: PhotosPickerItem?
    var body: some View {
        if let data = store.photoData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                .accessibilityLabel("Your optional pregame photo")
            Button("Remove photo", role: .destructive) {
                store.photoData = nil
                selection = nil
            }
        }
        PhotosPicker(selection: $selection, matching: .images) {
            Label("Choose photo", systemImage: "photo")
        }
        Text("Demo photos stay in memory. Camera capture and private upload will be added later.")
            .font(.footnote).foregroundStyle(.secondary)
    }
}
#Preview { PhotoAttachmentView(store: TeamStore(), selection: .constant(nil)) }
