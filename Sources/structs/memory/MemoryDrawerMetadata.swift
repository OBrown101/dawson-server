//
//  MemoryDrawerMetadata.swift
//  DAWSON
//
//  Created by Ethan Brown on 8/4/26.
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
