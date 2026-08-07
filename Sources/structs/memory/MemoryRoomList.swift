//
//  MemoryRoomList.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/4/26.
//

import Foundation

struct MemoryRoomList: Codable {
    var wing: String?
    var rooms: [MemoryCount]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wing = try c.decodeIfPresent(String.self, forKey: .wing)
        let dict = try c.decodeIfPresent([String: Int].self, forKey: .rooms) ?? [:]
        rooms = MemoryWingList.sortedCounts(dict)
    }

    enum CodingKeys: String, CodingKey { case wing, rooms }
}
