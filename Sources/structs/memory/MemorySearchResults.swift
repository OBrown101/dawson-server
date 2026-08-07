//
//  MemorySearchResults.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/4/26.
//

import Foundation

// NOTE: documented search results carry NO drawer id — client must route
// delete/detail through list or duplicate-check flows, not off a search hit.

struct MemorySearchResults: Codable {
    var query: String?
    var results: [MemoryDrawer]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        query = try c.decodeIfPresent(String.self, forKey: .query)
        results = try c.decodeIfPresent([MemoryDrawer].self, forKey: .results) ?? []
    }

    enum CodingKeys: String, CodingKey { case query, results }
}
