//
//  MemoryDrawerMetadata.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/4/26.
//  Copyright © 2026 Owen Ethan Brown.
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

struct MemoryDrawerMetadata: Codable {
    var sourceFile: String?
    var addedBy: String?
    var agent: String?
    var filedAt: String?
    var chunkIndex: Int?

    enum CodingKeys: String, CodingKey {
        case sourceFile = "source_file"
        case addedBy = "added_by"
        case agent
        case filedAt = "filed_at"
        case chunkIndex = "chunk_index"
    }
}
