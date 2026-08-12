//
//  MemoryOverview.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/4/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

struct MemoryOverview: Codable {
    var status: MemoryStatus?
    var recents: [MemoryDrawer]
    var storageBytes: Int64?
    var statusError: String?
    var recentsError: String?
}
