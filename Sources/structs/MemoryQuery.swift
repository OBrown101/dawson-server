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
    var query: String?      // search
    var drawerID: String?   // entry / delete
    var nResults: Int?      // search (default 8)
    var since: String?      // ISO-8601 lower bound (overview recents / pages)
    var before: String?     // ISO-8601 upper bound — the pagination cursor
    var limit: Int?         // page size (default 25)
}
