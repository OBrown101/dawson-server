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

    enum CodingKeys: String, CodingKey {
        case success
        case drawerId = "drawer_id"
    }
}
