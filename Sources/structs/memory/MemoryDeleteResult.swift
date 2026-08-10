//
//  MemoryDeleteResult.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/4/26.
//

import Foundation

struct MemoryDeleteResult: Codable {
    var success: Bool?
    var drawerId: String?
    var error: String?
    
    private enum In: String, CodingKey {
        case success
        case drawerId = "drawer_id"
        case error
    }
    
    private enum Out: String, CodingKey {
        case success
        case drawerId
        case error
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: In.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success)
        drawerId = try c.decodeIfPresent(String.self, forKey: .drawerId)
        error = try c.decodeIfPresent(String.self, forKey: .error)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Out.self)
        try c.encodeIfPresent(success, forKey: .success)
        try c.encodeIfPresent(drawerId, forKey: .drawerId)
        try c.encodeIfPresent(error, forKey: .error)
    }
}
