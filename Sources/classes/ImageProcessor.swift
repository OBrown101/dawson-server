//
//  ImageProcessor.swift
//  DAWSON
//
//  Created by Ethan Brown on 3/22/26.
//

import Foundation

#if os(macOS)
import AppKit
#endif

enum ImageProcessorError: LocalizedError {
    case fileNotFound(String)
    case invalidImageFormat
    case encodingFailed
    case compressionFailed
    case unsupportedFormat(String)
    case compressionNotSupported
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Image file not found: \(path)"
        case .invalidImageFormat:
            return "Invalid or corrupted image format"
        case .encodingFailed:
            return "Failed to encode image to base64"
        case .compressionFailed:
            return "Failed to compress image"
        case .unsupportedFormat(let format):
            return "Unsupported image format: \(format)"
        case .compressionNotSupported:
            return "Image compression not available on this platform"
        }
    }
}

class ImageProcessor: @unchecked Sendable {
    static let shared = ImageProcessor()
    
    private let supportedMimeTypes = ["image/jpeg", "image/png", "image/webp", "image/gif"]
    private let maxImageBytes = (5 * 1024 * 1024)  // 5MB default max
    
    func loadImageAsAttachment(fromFilePath filePath: String, maxSizeBytes: Int? = nil, attemptCompression: Bool = true) async throws -> ImageAttachment {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath) else {
            throw ImageProcessorError.fileNotFound(filePath)
        }
        
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        let mimeType = detectMimeType(for: filePath)
        
        guard supportedMimeTypes.contains(mimeType) else {
            throw ImageProcessorError.unsupportedFormat(mimeType)
        }
        
        var imageData = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let maxBytes = maxSizeBytes ?? maxImageBytes
        
        // Attempt compression only if flag is true and platform supports it
        if (attemptCompression && (imageData.count > maxBytes)) {
            do {
                imageData = try compressImageData(imageData, mimeType: mimeType, maxBytes: maxBytes)
            } catch ImageProcessorError.compressionNotSupported {
                print("Image compression not available on this platform; using original image")
            }
        }
        
        let base64String = imageData.base64EncodedString()
        
        return ImageAttachment(
            source: .base64(base64String),
            mimeType: mimeType,
            originalFileName: fileName,
            sizeBytes: imageData.count
        )
    }
    
    func validateBase64Attachment(base64String: String, mimeType: String, fileName: String? = nil) throws -> ImageAttachment {
        guard supportedMimeTypes.contains(mimeType) else {
            throw ImageProcessorError.unsupportedFormat(mimeType)
        }
        
        guard let data = Data(base64Encoded: base64String) else {
            throw ImageProcessorError.encodingFailed
        }
        
        return ImageAttachment(
            source: .base64(base64String),
            mimeType: mimeType,
            originalFileName: fileName,
            sizeBytes: data.count
        )
    }
    
    private func detectMimeType(for filePath: String) -> String {
        let pathExtension = (filePath as NSString).pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "webp":
            return "image/webp"
        case "gif":
            return "image/gif"
        default:
            return "image/jpeg"  // Default fallback
        }
    }
    
    private func compressImageData(_ imageData: Data, mimeType: String, maxBytes: Int) throws -> Data {
        if (imageData.count <= maxBytes) {
            return imageData
        }
        
        #if os(macOS)
        guard let image = NSImage(data: imageData) else {
            throw ImageProcessorError.invalidImageFormat
        }

        // Prefer reducing quality over shrinking dimensions first: detail-heavy images
        // (schematics, diagrams, screenshots with text) become unreadable once downscaled,
        // so we only touch dimensions as a last resort.
        let qualitySteps: [CGFloat] = [0.85, 0.7, 0.55, 0.4]
        for quality in qualitySteps {
            if let data = encodeImageMacOS(image, mimeType: mimeType, scale: 1.0, quality: quality),
               data.count <= maxBytes {
                return data
            }
        }

        // Still too large at full resolution even at low quality: downscale gradually,
        // but stop at 40% linear size rather than crushing it down to a sliver.
        var scale: CGFloat = 0.9
        var bestEffort: Data?
        while scale > 0.4 {
            if let data = encodeImageMacOS(image, mimeType: mimeType, scale: scale, quality: 0.6) {
                bestEffort = data
                if data.count <= maxBytes {
                    return data
                }
            }
            scale -= 0.1
        }

        if let bestEffort = bestEffort {
            return bestEffort
        }
        throw ImageProcessorError.compressionFailed

        #else
        // Linux or other platforms without native image libraries
        // Compression not supported; let caller handle gracefully
        throw ImageProcessorError.compressionNotSupported
        #endif
    }
    
    #if os(macOS)
    private func encodeImageMacOS(_ image: NSImage, mimeType: String, scale: CGFloat, quality: CGFloat) -> Data? {
        let currentSize = image.size
        let newSize = NSSize(width: currentSize.width * scale, height: currentSize.height * scale)

        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: currentSize),
                   operation: .copy,
                   fraction: 1.0)
        resizedImage.unlockFocus()

        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        if mimeType == "image/png" {
            return bitmapImage.representation(using: .png, properties: [:])
        }
        return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
    #endif
}
