//
//  ImageAttachment.swift
//  DAWSON
//
//  Created by Ethan Brown on 3/22/26.
//

import Foundation

struct ImageAttachment: Codable, Sendable {
    let uuid: String
    let source: ImageSource
    let mimeType: String              // "image/jpeg", "image/png", "image/webp", "image/gif"
    let originalFileName: String?
    let sizeBytes: Int?               // Size post-compression
    
    init(
        uuid: String = UUID().uuidString,
        source: ImageSource,
        mimeType: String,
        originalFileName: String? = nil,
        sizeBytes: Int? = nil
    ) {
        self.uuid = uuid
        self.source = source
        self.mimeType = mimeType
        self.originalFileName = originalFileName
        self.sizeBytes = sizeBytes
    }
    
    func toBase64() throws -> String {
        switch self.source {
        case .filePath(let path):
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return data.base64EncodedString()
        case .base64(let encoded):
            return encoded
        }
    }
}
