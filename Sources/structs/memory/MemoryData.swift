//
//  MemoryData.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/3/26.
//

import Foundation
import AnyCodable

struct MemoryData: Codable {
    let userUUID: String
    let dataUUID: String
    let dataType: DataType
    let payload: AnyCodable
    
    enum DataType: String, Codable {
        case overview = "OVERVIEW"          // { status..., recents: [entry] } for Knowledge home
        case listWings = "LIST_WINGS"       // wings + drawer counts ("View all" screen)
        case listRooms = "LIST_ROOMS"       // rooms within payload.wing
        case pageEntries = "PAGE_ENTRIES"   // drawers in wing/room, newest-first, cursor-paged
        case entry = "ENTRY"                // single full drawer by payload.drawerID
        case search = "SEARCH"              // semantic search results
        case delete = "DELETE"              // confirmation; also broadcast to all clients
    }
}
