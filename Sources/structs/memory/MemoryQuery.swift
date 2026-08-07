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
    var limit: Int?         // page size / search result cap
    var offset: Int?        // pagination cursor: previous offset + returned count
}
