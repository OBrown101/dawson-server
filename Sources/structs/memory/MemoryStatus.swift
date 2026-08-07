//
//  MemoryStatus.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/4/26.
//

import Foundation

struct MemoryStatus: Codable {
    var totalDrawers: Int?
    var wings: Int?
    var rooms: Int?
    var memoryProtocol: String?
    var aaakDialect: String?

    enum CodingKeys: String, CodingKey {
        case totalDrawers = "total_drawers"
        case wings
        case rooms
        case memoryProtocol = "protocol"
        case aaakDialect = "aaak_dialect"
    }
}
