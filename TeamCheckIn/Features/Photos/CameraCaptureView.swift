// CameraCaptureView.swift
// Purpose: Bridge the system still-photo camera into SwiftUI after permission approval.
import SwiftUI
import UIKit

/// Presented only after camera availability and permission checks at the point of use.
struct CameraCaptureView: UIViewControllerRepresentable {
    let captured: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(captured: captured) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        let captured: (UIImage?) -> Void
        init(captured: @escaping (UIImage?) -> Void) { self.captured = captured }
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            captured(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { captured(nil) }
    }
}
#Preview { Text("Camera capture requires a physical iPhone and permission.") }
