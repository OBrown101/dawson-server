//
//  MemoryDrawerPage.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/4/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

struct MemoryDrawerPage: Codable {
    var drawers: [MemoryDrawer]
    var total: Int?
    var limit: Int?
    var offset: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        drawers = try c.decodeIfPresent([MemoryDrawer].self, forKey: .drawers) ?? []
        total = try c.decodeIfPresent(Int.self, forKey: .total)
        limit = try c.decodeIfPresent(Int.self, forKey: .limit)
        offset = try c.decodeIfPresent(Int.self, forKey: .offset)
    }

    enum CodingKeys: String, CodingKey {
        case drawers
        case total
        case limit
        case offset
    }
}
