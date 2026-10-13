// PhotoProcessorTests.swift
// Purpose: Verify native image bounds and removal of source location/camera metadata with synthetic pixels.
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import TeamCheckIn

final class PhotoProcessorTests: XCTestCase {
    @MainActor
    func testPreparedPhotoIsBoundedJPEGWithoutSourceMetadata() throws {
        let input = try taggedFixture()
        let original = try XCTUnwrap(CGImageSourceCreateWithData(input as CFData, nil))
        let originalProperties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(original, 0, nil) as? [String: Any])
        XCTAssertNotNil(originalProperties[kCGImagePropertyGPSDictionary as String])
        let image = try XCTUnwrap(UIImage(data: input))
        let prepared = try PhotoProcessor.prepare(image)
        XCTAssertLessThanOrEqual(prepared.count, 5_000_000)
        let result = try XCTUnwrap(CGImageSourceCreateWithData(prepared as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(result) as String?, UTType.jpeg.identifier)
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(result, 0, nil) as? [String: Any])
        let width = try XCTUnwrap(properties[kCGImagePropertyPixelWidth as String] as? Int)
        let height = try XCTUnwrap(properties[kCGImagePropertyPixelHeight as String] as? Int)
        XCTAssertEqual(max(width, height), 1600)
        XCTAssertEqual(CGImageSourceGetCount(result), 1)
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary as String])
        let camera = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        XCTAssertNil(camera?[kCGImagePropertyTIFFMake as String])
    }

    @MainActor
    private func taggedFixture() throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 3200, height: 2400), format: format
        ).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3200, height: 2400))
        }
        let data = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        let properties: [String: Any] = [
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSLatitude as String: 1.0,
                kCGImagePropertyGPSLatitudeRef as String: "N",
                kCGImagePropertyGPSLongitude as String: 1.0,
                kCGImagePropertyGPSLongitudeRef as String: "E",
            ],
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFMake as String: "Synthetic test camera"
            ],
        ]
        CGImageDestinationAddImage(
            destination, try XCTUnwrap(image.cgImage), properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
