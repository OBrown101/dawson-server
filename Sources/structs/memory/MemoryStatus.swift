//
//  MemoryStatus.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/4/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

struct MemoryStatus: Codable {
    var totalDrawers: Int?
    var wings: Int?
    var rooms: Int?
    var diaryEntries: Int?
    var healthy: Bool?

    // Outbound wire keys (synthesized encode uses these)
    private enum Out: String, CodingKey {
        case totalDrawers
        case wings
        case rooms
        case diaryEntries
        case healthy
    }

    // Inbound from Mempalace MCP
    private enum In: String, CodingKey {
        case totalDrawers = "total_drawers"
        case wings
        case rooms
        case sqliteIntegrity = "sqlite_integrity"
    }
    
    private enum IntegrityKeys: String, CodingKey {
        case ok
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: In.self)
        totalDrawers = try c.decodeIfPresent(Int.self, forKey: .totalDrawers)

        if let dict = try? c.decode([String: Int].self, forKey: .wings) {
            wings = dict.count
        } else {
            wings = try? c.decode(Int.self, forKey: .wings)
        }
        if let dict = try? c.decode([String: Int].self, forKey: .rooms) {
            rooms = dict.count
            diaryEntries = dict["diary"]
        } else {
            rooms = try? c.decode(Int.self, forKey: .rooms)
        }
        if let integrity = try? c.nestedContainer(keyedBy: IntegrityKeys.self, forKey: .sqliteIntegrity) {
            healthy = try? integrity.decodeIfPresent(Bool.self, forKey: .ok)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Out.self)
        try c.encodeIfPresent(totalDrawers, forKey: .totalDrawers)
        try c.encodeIfPresent(wings, forKey: .wings)
        try c.encodeIfPresent(rooms, forKey: .rooms)
        try c.encodeIfPresent(diaryEntries, forKey: .diaryEntries)
        try c.encodeIfPresent(healthy, forKey: .healthy)
    }
}
