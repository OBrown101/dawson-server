//
//  MemoryWingList.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/4/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

struct MemoryWingList: Codable {
    var wings: [MemoryCount]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let dict = try c.decodeIfPresent([String: Int].self, forKey: .wings) ?? [:]
        wings = Self.sortedCounts(dict)
    }

    enum CodingKeys: String, CodingKey {
        case wings
    }

    static func sortedCounts(_ dict: [String: Int]) -> [MemoryCount] {
        // Count descending, name ascending as tiebreaker
        dict.map { MemoryCount(name: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.name < rhs.name
            }
    }
}
