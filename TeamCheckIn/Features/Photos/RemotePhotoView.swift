// RemotePhotoView.swift
// Purpose: Retrieve an assignment photo using authenticated access without exposing a public URL.
import SwiftUI

/// Download errors remain visible; changing the photo clears the previous image first.
struct RemotePhotoView: View {
    let photo: LivePhoto
    let service: any PhotoServicing
    @State private var data: Data?
    @State private var failed = false
    @State private var retry = 0
    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                    .accessibilityLabel("Teammate's optional pregame photo")
            } else if failed {
                Button("Retry photo") { retry += 1 }
            } else {
                ProgressView("Loading private photo")
            }
        }
        .task(id: "\(photo.photo_id):\(retry)") {
            data = nil; failed = false
            do {
                let bytes = try await service.download(photo: photo)
                try Task.checkCancellation()
                guard UIImage(data: bytes) != nil else { throw BackendError.invalidResponse }
                data = bytes
            } catch is CancellationError {} catch { failed = true }
        }
    }
}
#Preview { Text("Private photo preview uses only assigned test account data.") }
