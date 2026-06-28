//
//  ImageSource.swift
//  DAWSON
//
//  Created by Ethan Brown on 6/28/26.
//

import Foundation

enum ImageSource: Codable, Sendable {
    case filePath(String)
    case base64(String)
    
    enum CodingKeys: String, CodingKey {
        case filePath
        case base64
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .filePath(let path):
            try container.encode(path, forKey: .filePath)
        case .base64(let data):
            try container.encode(data, forKey: .base64)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let path = try container.decodeIfPresent(String.self, forKey: .filePath) {
            self = .filePath(path)
        } else if let data = try container.decodeIfPresent(String.self, forKey: .base64) {
            self = .base64(data)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Invalid ImageSource")
            )
        }
    }
}
