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
        // macOS with AppKit support for native image handling
        guard let image = NSImage(data: imageData) else {
            throw ImageProcessorError.invalidImageFormat
        }
        
        // Resize image to reduce file size
        let resizedImage = resizeImageMacOS(image, maxBytes: maxBytes)
        
        // Re-encode with compression
        guard let tiffData = resizedImage.tiffRepresentation else {
            throw ImageProcessorError.compressionFailed
        }
        
        if (mimeType == "image/jpeg") {
            guard let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
                throw ImageProcessorError.compressionFailed
            }
            return jpegData
        } else if (mimeType == "image/png") {
            guard let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                throw ImageProcessorError.compressionFailed
            }
            return pngData
        }
        
        return imageData
        
        #else
        // Linux or other platforms without native image libraries
        // Compression not supported; let caller handle gracefully
        throw ImageProcessorError.compressionNotSupported
        #endif
    }
    
    #if os(macOS)
    private func resizeImageMacOS(_ image: NSImage, maxBytes: Int) -> NSImage {
        var scale: CGFloat = 1.0
        let currentSize = image.size
        
        // Progressive scaling: reduce dimensions until estimated size is below threshold
        while currentSize.width * currentSize.height * scale > CGFloat(maxBytes / 1000) && scale > 0.1 {
            scale *= 0.8
        }
        
        let newSize = NSSize(width: currentSize.width * scale, height: currentSize.height * scale)
        let resizedImage = NSImage(size: newSize)
        
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        resizedImage.unlockFocus()
        
        return resizedImage
    }
    #endif
}
