//
//  MemoryOverview.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/4/26.
//

import Foundation

struct MemoryOverview: Codable {
    var status: MemoryStatus?
    var recents: [MemoryDrawer]
    var statusError: String?
    var recentsError: String?
}
