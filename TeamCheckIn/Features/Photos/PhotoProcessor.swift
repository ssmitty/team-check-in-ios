// PhotoProcessor.swift
// Purpose: Normalize orientation, resize, and encode photos without the source image metadata.
import UIKit

/// Bounds upload size and creates fresh JPEG bytes instead of sharing source EXIF metadata.
@MainActor
enum PhotoProcessor {
    static func prepare(_ image: UIImage) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else {
            throw BackendError.invalidResponse
        }
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let result = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = result.jpegData(compressionQuality: 0.8), data.count <= 5_000_000 else {
            throw BackendError.invalidResponse
        }
        return data
    }
}
