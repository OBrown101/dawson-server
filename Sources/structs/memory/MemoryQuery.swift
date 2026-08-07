//
//  MemoryQuery.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/3/26.
//

import Foundation
import AnyCodable

struct MemoryQuery: Codable {
    var wing: String?
    var room: String?
    var drawerID: String?   // entry / delete
    
    // Pagination (list_drawers)
    var limit: Int?             // ≤ 100 server-side (search default 5, lists 20)
    var offset: Int?            // next page = offset + returned count
    var since: String?          // ISO date(-time), inclusive, filed_at filter
    var before: String?         // ISO date(-time), exclusive, filed_at filter

    // Search (mempalace_search)
    var query: String?          // keywords ONLY, ≤ 250 chars per schema
    var context: String?        // background text; reserved for re-ranking, not embedded
    var maxDistance: Double?    // cosine distance cutoff, 0 disables (server default 1.5)
    var sourceFile: String?     // exact source_path match (from a result's sourcePath)
}
