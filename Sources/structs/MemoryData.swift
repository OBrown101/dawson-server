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
        case overview       // → { status..., recents: [entry] } for Knowledge home
        case listWings      // → wings + drawer counts ("View all" screen)
        case listRooms      // → rooms within payload.wing
        case pageEntries    // → drawers in wing/room, newest-first, cursor-paged
        case entry          // → single full drawer by payload.drawerID
        case search         // → semantic search results
        case delete         // → confirmation; also broadcast to all clients
    }
}
